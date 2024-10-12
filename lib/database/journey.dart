class Journey {
  final int? id;
  final double distance;
  final String address;
  final DateTime startTime;
  final DateTime endTime;

  Journey({
    this.id,
    required this.distance,
    required this.address,
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'distance': distance,
      'address': address,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
    };
  }
}
