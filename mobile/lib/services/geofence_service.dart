import 'dart:async';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

/// Geofence parameters from specification §6.
class GeofenceConfig {
  static const double radiusM = 60;
  static const double accuracyLimitM = 50;
  static const Duration dwellTime = Duration(seconds: 25);
  static const int activeWindowStops = 2;
}

enum StopState {
  pending,
  enRoute,
  nearby,
  arrived,
  inService,
  completed,
  exception,
}

class GeofenceEvent {
  final double latitude;
  final double longitude;
  final double accuracyM;
  final DateTime timestamp;

  GeofenceEvent({
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.timestamp,
  });
}

class GeofenceService {
  GeofenceService._();
  static final GeofenceService instance = GeofenceService._();

  StreamSubscription<Position>? _sub;
  final _controller = StreamController<GeofenceEvent>.broadcast();
  Position? _last;

  Stream<GeofenceEvent> get events => _controller.stream;
  Position? get lastPosition => _last;

  /// Location minimization: only from Shift Start to Shift End.
  Future<void> startShiftMonitoring() async {
    stop();
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      _last = pos;
      _controller.add(GeofenceEvent(
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracyM: pos.accuracy,
        timestamp: DateTime.now().toUtc(),
      ));
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _last = null;
  }

  static double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final p1 = lat1 * math.pi / 180;
    final p2 = lat2 * math.pi / 180;
    final dp = (lat2 - lat1) * math.pi / 180;
    final dl = (lon2 - lon1) * math.pi / 180;
    final a = math.pow(math.sin(dp / 2), 2) +
        math.cos(p1) * math.cos(p2) * math.pow(math.sin(dl / 2), 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  bool isInside({
    required double outletLat,
    required double outletLng,
    required double radiusM,
    required double accuracyM,
  }) {
    if (_last == null) return false;
    if (accuracyM > GeofenceConfig.accuracyLimitM) return false;
    final d = distanceMeters(_last!.latitude, _last!.longitude, outletLat, outletLng);
    return d <= radiusM;
  }

  double? distanceTo(double outletLat, double outletLng) {
    final p = _last;
    if (p == null) return null;
    return distanceMeters(p.latitude, p.longitude, outletLat, outletLng);
  }
}
