class DeckModel {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final String color;
  final String icon;
  final int cardCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DeckModel({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    this.color = 'violet',
    this.icon = '📚',
    this.cardCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory DeckModel.fromJson(Map<String, dynamic> json) {
    int count = 0;
    if (json['cards'] is List && (json['cards'] as List).isNotEmpty) {
      final first = (json['cards'] as List).first;
      if (first is Map && first.containsKey('count')) {
        count = (first['count'] as num?)?.toInt() ?? 0;
      }
    } else if (json['card_count'] != null) {
      count = (json['card_count'] as num).toInt();
    }

    return DeckModel(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      color: json['color'] as String? ?? 'violet',
      icon: json['icon'] as String? ?? '📚',
      cardCount: count,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'description': description,
      'color': color,
      'icon': icon,
      'card_count': cardCount,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  DeckModel copyWith({
    String? name,
    String? description,
    String? color,
    String? icon,
    int? cardCount,
  }) {
    return DeckModel(
      id: id,
      userId: userId,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      cardCount: cardCount ?? this.cardCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
