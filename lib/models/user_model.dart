class UserModel {
  final String id;
  final String callNumber;
  final String passwordHash;
  final bool useRandomNumber;
  final bool showAsUnknown;
  final String? displayName;
  final String? uniqueUid;
  final bool isOnline;

  UserModel({
    required this.id,
    required this.callNumber,
    required this.passwordHash,
    required this.useRandomNumber,
    required this.showAsUnknown,
    this.displayName,
    this.uniqueUid,
    this.isOnline = false,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      callNumber: map['call_number'],
      passwordHash: map['password_hash'],
      useRandomNumber: map['use_random_number'] ?? false,
      showAsUnknown: map['show_as_unknown'] ?? false,
      displayName: map['display_name'],
      uniqueUid: map['unique_uid'],
      isOnline: map['is_online'] ?? false,
    );
  }

  static String maskNumber(String n) {
    if (n.length <= 6) return n;
    return '${n.substring(0, 3)}${'*' * (n.length - 6)}${n.substring(n.length - 3)}';
  }

  UserModel copyWith({
    String? callNumber,
    String? displayName,
    bool? isOnline,
    bool? useRandomNumber,
    bool? showAsUnknown,
  }) {
    return UserModel(
      id: id,
      callNumber: callNumber ?? this.callNumber,
      passwordHash: passwordHash,
      useRandomNumber: useRandomNumber ?? this.useRandomNumber,
      showAsUnknown: showAsUnknown ?? this.showAsUnknown,
      displayName: displayName ?? this.displayName,
      uniqueUid: uniqueUid,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}
