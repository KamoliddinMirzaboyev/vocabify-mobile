import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/services/supabase_service.dart';
import '../core/services/offline_queue_service.dart';
import '../core/services/cache_service.dart';
import '../models/profile_model.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  Session? _session;
  ProfileModel? _profile;
  bool _isLoading = true;
  StreamSubscription<AuthState>? _authSubscription;

  User? get user => _user;
  Session? get session => _session;
  ProfileModel? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _init();
  }

  void _init() async {
    _session = SupabaseService.currentSession;
    _user = SupabaseService.currentUser;

    if (_user != null) {
      // Instant display from local cache
      final cached = await CacheService.instance.getCachedProfile();
      if (cached != null) {
        _profile = cached;
        _isLoading = false;
        notifyListeners();
      }
      loadProfile();
    } else {
      _isLoading = false;
      notifyListeners();
    }

    _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      _session = session;
      _user = session?.user;

      if (_user != null) {
        final cached = await CacheService.instance.getCachedProfile();
        if (cached != null && _profile == null) {
          _profile = cached;
          _isLoading = false;
          notifyListeners();
        }
        loadProfile();
      } else {
        _profile = null;
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  Future<void> loadProfile() async {
    if (_user == null) return;
    try {
      final res = await SupabaseService.client
          .from('profiles')
          .select('*')
          .eq('id', _user!.id)
          .maybeSingle();

      if (res != null) {
        _profile = ProfileModel.fromJson(res);
        await CacheService.instance.cacheProfile(_profile!);
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      // If network fails, try to load from cache if not already loaded
      _profile ??= await CacheService.instance.getCachedProfile();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> signIn(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      final res = await SupabaseService.client.auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      );

      _session = res.session;
      _user = res.user;
      await loadProfile();
      return null;
    } on AuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.message;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'Tizimga kirishda xatolik yuz berdi';
    }
  }

  Future<String?> signUp(String email, String password, String name) async {
    try {
      _isLoading = true;
      notifyListeners();

      final res = await SupabaseService.client.auth.signUp(
        email: email.trim(),
        password: password.trim(),
        data: {'display_name': name.trim().isEmpty ? email.split('@')[0] : name.trim()},
      );

      _session = res.session;
      _user = res.user;

      // Ensure profile exists or is created
      if (_user != null) {
        await loadProfile();
      }

      return null;
    } on AuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.message;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'Ro\'yxatdan o\'tishda xatolik yuz berdi';
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    await SupabaseService.client.auth.signOut();
    await CacheService.instance.clearUserCache();
    _user = null;
    _session = null;
    _profile = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> updateProfile({required String displayName, required int dailyGoal}) async {
    if (_user == null) return false;

    // Optimistic local update
    if (_profile != null) {
      _profile = _profile!.copyWith(displayName: displayName, dailyGoal: dailyGoal);
      await CacheService.instance.cacheProfile(_profile!);
      notifyListeners();
    }

    try {
      await OfflineQueueService.instance.queuedWrite(
        QueuedOp(
          kind: OpKind.update,
          table: 'profiles',
          match: {'id': _user!.id},
          values: {
            'display_name': displayName,
            'daily_goal': dailyGoal,
            'updated_at': DateTime.now().toIso8601String(),
          },
        ),
      );
      OfflineQueueService.instance.flushQueue();
      return true;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
