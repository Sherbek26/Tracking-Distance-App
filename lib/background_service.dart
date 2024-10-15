import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'location_service.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  service.startService();
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final LocationService locationService = LocationService();
  await locationService.init();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    locationService.stopTracking();
    service.stopSelf();
  });

  locationService.startTracking();

  locationService.locationStream.listen((locationData) {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Location Tracker",
        content:
            "Distance: ${locationData.totalDistance.toStringAsFixed(2)} km, Waiting: ${locationData.formattedWaitingTime}",
      );
    }

    service.invoke(
      'update',
      {
        "distance": locationData.totalDistance,
        "waiting_time": locationData.totalWaitingTime,
        "formatted_waiting_time": locationData.formattedWaitingTime,
        "current_address": locationData.currentAddress,
        "is_tracking": locationData.isTracking,
        "current_date": DateTime.now().toIso8601String(),
      },
    );
  });

  service.on('startWaiting').listen((event) {
    locationService.startWaiting();
  });

  service.on('stopWaiting').listen((event) {
    locationService.stopWaiting();
  });

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }
}
