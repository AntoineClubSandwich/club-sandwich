import 'dart:async';

import 'package:geolocator/geolocator.dart';

class EncounterPosition {
  const EncounterPosition({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
}

enum EncounterLocationFailure { serviceDisabled, permissionDenied, unavailable }

class EncounterLocationException implements Exception {
  const EncounterLocationException(this.failure);

  final EncounterLocationFailure failure;
}

class EncounterLocationService {
  const EncounterLocationService();

  static const maximumAcceptedAccuracyMeters = 25.0;

  Future<EncounterPosition> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const EncounterLocationException(
        EncounterLocationFailure.serviceDisabled,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const EncounterLocationException(
        EncounterLocationFailure.permissionDenied,
      );
    }

    // A single getCurrentPosition() shot often returns an early, coarse fix
    // (especially on web/mobile-browser geolocation) well above the 25 m
    // bar, even though a much better fix arrives a few seconds later. Watch
    // the position stream for a bounded window and keep the best sample
    // seen, instead of failing on whatever the first callback reports.
    Position? best;
    final completer = Completer<void>();
    StreamSubscription<Position>? subscription;
    final timer = Timer(const Duration(seconds: 12), () {
      if (!completer.isCompleted) completer.complete();
    });

    try {
      subscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
            ),
          ).listen(
            (position) {
              final current = best;
              if (current == null || position.accuracy < current.accuracy) {
                best = position;
              }
              if (position.accuracy <= maximumAcceptedAccuracyMeters &&
                  !completer.isCompleted) {
                completer.complete();
              }
            },
            onError: (_) {
              if (!completer.isCompleted) completer.complete();
            },
          );
      await completer.future;
    } finally {
      timer.cancel();
      await subscription?.cancel();
    }

    final result = best;
    if (result == null || result.accuracy > maximumAcceptedAccuracyMeters) {
      throw const EncounterLocationException(
        EncounterLocationFailure.unavailable,
      );
    }
    return EncounterPosition(
      latitude: result.latitude,
      longitude: result.longitude,
      accuracy: result.accuracy,
    );
  }
}
