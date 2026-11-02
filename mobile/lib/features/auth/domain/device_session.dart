/// A device signed in as this person, for Settings.
class DeviceSession {
  const DeviceSession({
    required this.id,
    required this.device,
    required this.signedInAt,
    required this.lastActiveAt,
    required this.isCurrent,
  });

  factory DeviceSession.fromJson(Map<String, dynamic> json) => DeviceSession(
    id: json['id'] as String,
    device: json['device'] as String,
    signedInAt: DateTime.parse(json['signedInAt'] as String).toLocal(),
    lastActiveAt: DateTime.parse(json['lastActiveAt'] as String).toLocal(),
    isCurrent: json['current'] as bool? ?? false,
  );

  final String id;

  /// As "Chrome on Windows".
  final String device;
  final DateTime signedInAt;
  final DateTime lastActiveAt;

  /// This phone.
  final bool isCurrent;

  bool get isPhone => device.contains('Android') || device.contains('iOS');
}
