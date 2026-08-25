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

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (position.accuracy > maximumAcceptedAccuracyMeters) {
        throw const EncounterLocationException(
          EncounterLocationFailure.unavailable,
        );
      }
      return EncounterPosition(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );
    } on EncounterLocationException {
      rethrow;
    } on TimeoutException {
      throw const EncounterLocationException(
        EncounterLocationFailure.unavailable,
      );
    } catch (_) {
      throw const EncounterLocationException(
        EncounterLocationFailure.unavailable,
      );
    }
  }
}
