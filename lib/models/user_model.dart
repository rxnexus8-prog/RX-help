class UserModel {
  final String id;
  final String callNumber;
  final bool useRandomNumber;
  final bool showAsUnknown;
  final String? displayName;

  UserModel({
    required this.id,
    required this.callNumber,
    this.useRandomNumber = false,
    this.showAsUnknown = false,
    this.displayName,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      callNumber: map['call_number'] ?? '',
      useRandomNumber: map['use_random_number'] ?? false,
      showAsUnknown: map['show_as_unknown'] ?? false,
      displayName: map['display_name'],
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'call_number': callNumber,
        'use_random_number': useRandomNumber,
        'show_as_unknown': showAsUnknown,
        'display_name': displayName,
      };

  /// Mask number: first 3 + last 3 visible, rest = *
  static String maskNumber(String number) {
    if (number.length <= 6) return number;
    final visible = 3;
    final start = number.substring(0, visible);
    final end = number.substring(number.length - visible);
    final stars = '*' * (number.length - visible * 2);
    return '$start$stars$end';
  }
}
