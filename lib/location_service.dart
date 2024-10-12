import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationData {
  final double totalDistance;
  final String currentAddress;
  final int totalWaitingTime;
  final bool isTracking;
  final String formattedWaitingTime;

  LocationData({
    required this.totalDistance,
    required this.currentAddress,
    required this.totalWaitingTime,
    required this.isTracking,
    required this.formattedWaitingTime,
  });
}

class LocationService {
  Position? _lastPosition;
  double _totalDistance = 0.0;
  String _currentAddress = "Fetching address...";
  int _totalWaitingTime = 0;
  bool _isTracking = true;
  Timer? _waitingTimer;

  final _locationController = StreamController<LocationData>.broadcast();
  StreamSubscription<Position>? _positionSubscription;

  double get totalDistance => _totalDistance;
  String get currentAddress => _currentAddress;
  int get totalWaitingTime => _totalWaitingTime;
  String get formattedWaitingTime => _formatWaitingTime(_totalWaitingTime);

  Stream<LocationData> get locationStream => _locationController.stream;

  Future<void> init() async {
    await _checkPermission();
    _startLocationTracking();
  }

  Future<void> _checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('permissions are permanently denied.');
    }
  }

  String _formatWaitingTime(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int remainingSeconds = seconds % 60;

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _startLocationTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen(_handleNewPosition);
  }

  void _handleNewPosition(Position position) async {
    if (_lastPosition != null) {
      double distance = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      if (distance >= 5) {
        _totalDistance += distance / 1000;
        _lastPosition = position;
      }
    } else {
      _lastPosition = position;
    }

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        _currentAddress =
            "${place.street}, ${place.locality}, ${place.country}";
      }
    } catch (e) {
      print("Error fetching address: $e");
    }

    _emitCurrentState();
  }

  void startWaiting() {
    _isTracking = false;
    _positionSubscription?.pause();
    _waitingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _totalWaitingTime++;
      _emitCurrentState();
    });
  }

  void stopWaiting() {
    _waitingTimer?.cancel();
    _isTracking = true;
    _positionSubscription?.resume();
    _emitCurrentState();
  }

  void _emitCurrentState() {
    _locationController.add(LocationData(
      totalDistance: _totalDistance,
      currentAddress: _currentAddress,
      totalWaitingTime: _totalWaitingTime,
      isTracking: _isTracking,
      formattedWaitingTime: _formatWaitingTime(_totalWaitingTime),
    ));
  }

  void dispose() {
    _waitingTimer?.cancel();
    _positionSubscription?.cancel();
    _locationController.close();
  }
}
