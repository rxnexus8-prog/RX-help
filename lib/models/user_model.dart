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

  UserModel copyWith({String? displayName, bool? isOnline}) {
    return UserModel(
      id: id,
      callNumber: callNumber,
      passwordHash: passwordHash,
      useRandomNumber: useRandomNumber,
      showAsUnknown: showAsUnknown,
      displayName: displayName ?? this.displayName,
      uniqueUid: uniqueUid,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}
