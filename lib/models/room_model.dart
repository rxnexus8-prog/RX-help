class RoomModel {
  final String id;
  final String roomCode;
  final String hostId;
  final String hostNumber;  // may be masked or 'Unknown'
  final String status; // waiting | ringing | active | ended
  final String? requesterId;
  final String? requesterNumber;
  final Map<String, dynamic>? offer;
  final Map<String, dynamic>? answer;

  RoomModel({
    required this.id,
    required this.roomCode,
    required this.hostId,
    required this.hostNumber,
    required this.status,
    this.requesterId,
    this.requesterNumber,
    this.offer,
    this.answer,
  });

  factory RoomModel.fromMap(Map<String, dynamic> map) {
    return RoomModel(
      id: map['id'],
      roomCode: map['room_code'],
      hostId: map['host_id'],
      hostNumber: map['host_number'] ?? 'Unknown',
      status: map['status'] ?? 'waiting',
      requesterId: map['requester_id'],
      requesterNumber: map['requester_number'],
      offer: map['offer'],
      answer: map['answer'],
    );
  }
}
