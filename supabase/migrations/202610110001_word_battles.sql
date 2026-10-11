-- Asynchronous 1v1 Word Battles.
-- Vocabify stores vocabulary in public.cards; the public API keeps the
-- word_id name used by the battle domain.

create extension if not exists pgcrypto;

create table public.duels (
  id uuid primary key default gen_random_uuid(),
  deck_id uuid not null references public.decks(id) on delete restrict,
  player_a_id uuid not null references auth.users(id) on delete cascade,
  player_b_id uuid references auth.users(id) on delete set null,
  question_ids uuid[] not null,
  status text not null default 'waiting_b'
    check (status in ('waiting_b', 'completed', 'expired', 'cancelled')),
  player_a_score integer not null default 0
    check (player_a_score between 0 and 10000),
  player_b_score integer not null default 0
    check (player_b_score between 0 and 10000),
  winner_id uuid references auth.users(id) on delete set null,
  player_a_submitted_at timestamptz,
  player_b_submitted_at timestamptz,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours'),
  constraint duels_exactly_ten_questions check (cardinality(question_ids) = 10),
  constraint duels_different_players check (
    player_b_id is null or player_b_id <> player_a_id
  ),
  constraint duels_winner_is_player check (
    winner_id is null or winner_id = player_a_id or winner_id = player_b_id
  )
);

create index duels_player_a_created_idx
  on public.duels (player_a_id, created_at desc);
create index duels_player_b_created_idx
  on public.duels (player_b_id, created_at desc);
create index duels_open_idx
  on public.duels (created_at desc)
  where status = 'waiting_b' and player_b_id is null;
create index duels_open_expiry_idx
  on public.duels (expires_at, created_at desc)
  where status = 'waiting_b' and player_b_id is null;

create table public.duel_answers (
  id uuid primary key default gen_random_uuid(),
  duel_id uuid not null references public.duels(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  word_id uuid not null references public.cards(id) on delete restrict,
  selected_option text not null,
  is_correct boolean not null,
  time_spent_ms integer not null check (time_spent_ms between 0 and 10000),
  points_earned integer not null check (points_earned between 0 and 1000),
  created_at timestamptz not null default now(),
  unique (duel_id, user_id, word_id)
);

create index duel_answers_duel_user_idx
  on public.duel_answers (duel_id, user_id);

alter table public.duels enable row level security;
alter table public.duel_answers enable row level security;

create policy "participants and open challengers can read duels"
on public.duels for select to authenticated
using (
  auth.uid() = player_a_id
  or auth.uid() = player_b_id
  or (status = 'waiting_b' and player_b_id is null)
);

-- Answers only become visible to both participants when the battle is over.
-- Correctness is therefore never leaked while the opponent can still play.
create policy "participants can read completed duel answers"
on public.duel_answers for select to authenticated
using (
  exists (
    select 1
    from public.duels d
    where d.id = duel_answers.duel_id
      and d.status = 'completed'
      and auth.uid() in (d.player_a_id, d.player_b_id)
  )
);

-- There are intentionally no INSERT/UPDATE/DELETE policies. All battle writes
-- go through SECURITY DEFINER RPCs, preventing client-side score mutation.
revoke all on public.duels from anon, authenticated;
revoke all on public.duel_answers from anon, authenticated;
grant select on public.duels to authenticated;
grant select on public.duel_answers to authenticated;

create or replace function public.create_duel(
  p_deck_id uuid,
  p_opponent_id uuid default null
) returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_duel_id uuid;
  v_question_ids uuid[];
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_opponent_id = v_user_id then
    raise exception 'You cannot challenge yourself' using errcode = '22023';
  end if;

  if not exists (
    select 1 from public.decks d
    where d.id = p_deck_id and d.user_id = v_user_id
  ) then
    raise exception 'Deck not found or not owned by current user'
      using errcode = '42501';
  end if;

  if p_opponent_id is not null
     and not exists (select 1 from auth.users u where u.id = p_opponent_id) then
    raise exception 'Opponent not found' using errcode = '22023';
  end if;

  select array_agg(picked.id order by picked.position)
  into v_question_ids
  from (
    select c.id, row_number() over () as position
    from public.cards c
    where c.deck_id = p_deck_id
      and nullif(btrim(c.translation), '') is not null
    order by random()
    limit 10
  ) picked;

  if coalesce(cardinality(v_question_ids), 0) <> 10 then
    raise exception 'A battle deck must contain at least 10 translated cards'
      using errcode = '22023';
  end if;

  if (
    select count(distinct c.translation)
    from public.cards c
    where c.deck_id = p_deck_id
      and nullif(btrim(c.translation), '') is not null
  ) < 4 then
    raise exception 'A battle deck needs at least four distinct translations'
      using errcode = '22023';
  end if;

  insert into public.duels (
    deck_id, player_a_id, player_b_id, question_ids
  ) values (
    p_deck_id, v_user_id, p_opponent_id, v_question_ids
  ) returning id into v_duel_id;

  return v_duel_id;
end;
$$;

create or replace function public.get_duel_questions(p_duel_id uuid)
returns json
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_duel public.duels%rowtype;
  v_questions json;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select * into v_duel
  from public.duels
  where id = p_duel_id
  for update;

  if not found then
    raise exception 'Duel not found' using errcode = 'P0002';
  end if;

  if v_duel.status = 'waiting_b' and v_duel.expires_at <= now() then
    update public.duels set status = 'expired' where id = p_duel_id;
    return '[]'::json;
  end if;

  if v_duel.status <> 'waiting_b' then
    return '[]'::json;
  end if;

  -- Opening an unassigned public challenge atomically claims player B.
  if v_duel.player_b_id is null and v_user_id <> v_duel.player_a_id then
    update public.duels
    set player_b_id = v_user_id
    where id = p_duel_id;
    v_duel.player_b_id := v_user_id;
  end if;

  if v_user_id <> v_duel.player_a_id
     and v_user_id is distinct from v_duel.player_b_id then
    raise exception 'You are not a participant in this duel'
      using errcode = '42501';
  end if;

  if (v_user_id = v_duel.player_a_id and v_duel.player_a_submitted_at is not null)
     or (v_user_id = v_duel.player_b_id and v_duel.player_b_submitted_at is not null) then
    raise exception 'Answers have already been submitted for this duel'
      using errcode = '22023';
  end if;

  select json_agg(
    json_build_object(
      'word_id', q.id,
      'prompt', q.word,
      'options', q.options
    ) order by q.ordinality
  ) into v_questions
  from (
    select c.id, c.word, ids.ordinality,
      (
        select json_agg(
          option_value
          order by md5(v_duel.id::text || c.id::text || option_value)
        )
        from (
          select c.translation as option_value
          union all
          select distractor.translation
          from (
            select unique_options.translation
            from (
              select distinct other.translation
              from public.cards other
              where other.deck_id = v_duel.deck_id
                and other.id <> c.id
                and other.translation <> c.translation
                and nullif(btrim(other.translation), '') is not null
            ) unique_options
            order by md5(v_duel.id::text || c.id::text || unique_options.translation)
            limit 3
          ) distractor
        ) choices
      ) as options
    from unnest(v_duel.question_ids) with ordinality ids(id, ordinality)
    join public.cards c on c.id = ids.id
  ) q;

  if exists (
    select 1
    from json_array_elements(v_questions) item
    where json_array_length(item->'options') <> 4
  ) then
    raise exception 'The deck needs at least four distinct translations'
      using errcode = '22023';
  end if;

  return coalesce(v_questions, '[]'::json);
end;
$$;

-- Keeps lobby reads bounded to the current user's history plus active public
-- challenges. RLS still applies because this function uses invoker rights.
create or replace function public.list_duels()
returns setof public.duels
language sql
stable
security invoker
set search_path = public, pg_temp
as $$
  select d.*
  from public.duels d
  where auth.uid() in (d.player_a_id, d.player_b_id)
     or (
       d.status = 'waiting_b'
       and d.player_b_id is null
       and d.expires_at > now()
     )
  order by d.created_at desc;
$$;

create or replace function public.submit_duel_answers(
  p_duel_id uuid,
  p_answers jsonb
) returns json
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_duel public.duels%rowtype;
  v_score integer := 0;
  v_answer_count integer;
  v_distinct_count integer;
  v_player_a_done boolean;
  v_player_b_done boolean;
  v_winner uuid;
  v_a_time bigint;
  v_b_time bigint;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if jsonb_typeof(p_answers) <> 'array' or jsonb_array_length(p_answers) <> 10 then
    raise exception 'Exactly 10 answers are required' using errcode = '22023';
  end if;

  select * into v_duel
  from public.duels
  where id = p_duel_id
  for update;

  if not found then
    raise exception 'Duel not found' using errcode = 'P0002';
  end if;

  if v_duel.status <> 'waiting_b' then
    raise exception 'Duel is not accepting answers' using errcode = '22023';
  end if;

  if v_user_id <> v_duel.player_a_id
     and v_user_id is distinct from v_duel.player_b_id then
    raise exception 'You are not a participant in this duel'
      using errcode = '42501';
  end if;

  if v_duel.expires_at <= now() then
    update public.duels set status = 'expired' where id = p_duel_id;
    return json_build_object(
      'duel_id', v_duel.id,
      'score', 0,
      'status', 'expired',
      'player_a_score', v_duel.player_a_score,
      'player_b_score', v_duel.player_b_score,
      'winner_id', null,
      'submitted_as', case when v_user_id = v_duel.player_a_id
        then 'player_a' else 'player_b' end
    );
  end if;

  if (v_user_id = v_duel.player_a_id and v_duel.player_a_submitted_at is not null)
     or (v_user_id = v_duel.player_b_id and v_duel.player_b_submitted_at is not null) then
    raise exception 'Answers have already been submitted for this duel'
      using errcode = '23505';
  end if;

  select count(*), count(distinct parsed.word_id)
  into v_answer_count, v_distinct_count
  from jsonb_to_recordset(p_answers) as parsed(
    word_id uuid,
    selected_option text,
    time_spent_ms integer
  );

  if v_answer_count <> 10 or v_distinct_count <> 10 then
    raise exception 'Answers must contain each of the 10 questions once'
      using errcode = '22023';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_answers) as parsed(
      word_id uuid,
      selected_option text,
      time_spent_ms integer
    )
    where parsed.word_id <> all(v_duel.question_ids)
       or parsed.selected_option is null
       or parsed.time_spent_ms is null
       or parsed.time_spent_ms < 0
  ) then
    raise exception 'Malformed answer payload' using errcode = '22023';
  end if;

  with evaluated as (
    select
      parsed.word_id,
      parsed.selected_option,
      least(parsed.time_spent_ms, 10000) as elapsed_ms,
      parsed.selected_option = c.translation as correct
    from jsonb_to_recordset(p_answers) as parsed(
      word_id uuid,
      selected_option text,
      time_spent_ms integer
    )
    join public.cards c on c.id = parsed.word_id
  ), inserted as (
    insert into public.duel_answers (
      duel_id, user_id, word_id, selected_option,
      is_correct, time_spent_ms, points_earned
    )
    select
      p_duel_id,
      v_user_id,
      e.word_id,
      e.selected_option,
      e.correct,
      e.elapsed_ms,
      case when e.correct then
        round(500 + (((10000 - e.elapsed_ms)::numeric / 10000) * 500))::integer
      else 0 end
    from evaluated e
    returning points_earned
  )
  select coalesce(sum(points_earned), 0)::integer into v_score from inserted;

  if v_user_id = v_duel.player_a_id then
    update public.duels
    set player_a_score = v_score, player_a_submitted_at = now()
    where id = p_duel_id;
  else
    update public.duels
    set player_b_score = v_score, player_b_submitted_at = now()
    where id = p_duel_id;
  end if;

  select * into v_duel from public.duels where id = p_duel_id;
  v_player_a_done := v_duel.player_a_submitted_at is not null;
  v_player_b_done := v_duel.player_b_submitted_at is not null;

  if v_player_a_done and v_player_b_done then
    if v_duel.player_a_score > v_duel.player_b_score then
      v_winner := v_duel.player_a_id;
    elsif v_duel.player_b_score > v_duel.player_a_score then
      v_winner := v_duel.player_b_id;
    else
      select coalesce(sum(time_spent_ms), 0) into v_a_time
      from public.duel_answers
      where duel_id = p_duel_id and user_id = v_duel.player_a_id;
      select coalesce(sum(time_spent_ms), 0) into v_b_time
      from public.duel_answers
      where duel_id = p_duel_id and user_id = v_duel.player_b_id;
      -- Deterministic final fallback makes even identical submissions draw-free.
      v_winner := case when v_a_time <= v_b_time
        then v_duel.player_a_id else v_duel.player_b_id end;
    end if;

    update public.duels
    set status = 'completed', winner_id = v_winner
    where id = p_duel_id;
  end if;

  select * into v_duel from public.duels where id = p_duel_id;
  return json_build_object(
    'duel_id', v_duel.id,
    'score', v_score,
    'status', v_duel.status,
    'player_a_score', v_duel.player_a_score,
    'player_b_score', v_duel.player_b_score,
    'winner_id', v_duel.winner_id,
    'submitted_as', case when v_user_id = v_duel.player_a_id
      then 'player_a' else 'player_b' end
  );
end;
$$;

-- Exact email/UUID lookup avoids exposing a browsable user directory while
-- still allowing players to find a known friend.
create or replace function public.search_battle_opponent(p_query text)
returns json
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_query text := btrim(coalesce(p_query, ''));
  v_result json;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if v_query = '' then
    return null;
  end if;

  select json_build_object(
    'id', u.id,
    -- A public battle ID must not become an email-discovery endpoint. Return
    -- the email only when the caller already supplied that exact email.
    'email', case when lower(u.email) = lower(v_query) then u.email end,
    'display_name', p.display_name
  )
  into v_result
  from auth.users u
  left join public.profiles p on p.id = u.id
  where u.id <> v_user_id
    and (
      lower(u.email) = lower(v_query)
      or u.id::text = lower(v_query)
    )
  limit 1;

  return v_result;
end;
$$;

revoke all on function public.create_duel(uuid, uuid) from public;
revoke all on function public.get_duel_questions(uuid) from public;
revoke all on function public.submit_duel_answers(uuid, jsonb) from public;
revoke all on function public.search_battle_opponent(text) from public;
revoke all on function public.list_duels() from public;
grant execute on function public.create_duel(uuid, uuid) to authenticated;
grant execute on function public.get_duel_questions(uuid) to authenticated;
grant execute on function public.submit_duel_answers(uuid, jsonb) to authenticated;
grant execute on function public.search_battle_opponent(text) to authenticated;
grant execute on function public.list_duels() to authenticated;

