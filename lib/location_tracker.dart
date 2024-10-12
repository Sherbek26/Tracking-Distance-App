import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:tracking_distance/database/database_helper.dart';
import 'package:tracking_distance/database/journey.dart';
import 'location_service.dart';

class LocationTracker extends StatefulWidget {
  const LocationTracker({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _LocationTrackerState createState() => _LocationTrackerState();
}

class _LocationTrackerState extends State<LocationTracker> {
  final LocationService _locationService = LocationService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final FlutterBackgroundService _backgroundService =
      FlutterBackgroundService();

  bool _isJourneyStarted = false;
  bool _isWaiting = false;
  DateTime? _journeyStartTime;
  int _waitingSeconds = 0;
  late Timer _waitingTimer;

  @override
  void initState() {
    super.initState();
    _locationService.init();
  }

  void _startWaiting() {
    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _waitingSeconds++;
      });
    });
  }

  void _stopWaiting() {
    _waitingTimer.cancel();
    setState(() {
      _isWaiting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Location Tracker'),
          backgroundColor: Colors.deepOrange,
          bottom: const TabBar(
            labelStyle: TextStyle(color: Colors.white),
            tabs: [
              Tab(text: 'Journeys'),
              Tab(text: 'Start'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            FutureBuilder<List<Journey>>(
              future: _databaseHelper.getJourneys(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final journeys = snapshot.data!;
                return ListView.builder(
                  itemCount: journeys.length,
                  itemBuilder: (context, index) {
                    final journey = journeys[index];
                    return Container(
                      margin: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Colors.amberAccent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.deepOrange, width: 2),
                      ),
                      child: ListTile(
                        title:
                            Text('${journey.distance.toStringAsFixed(2)} km'),
                        subtitle: Text('${journey.address}\n'
                            'Start: ${journey.startTime}\n'
                            'End: ${journey.endTime}'),
                      ),
                    );
                  },
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${_locationService.totalDistance.toStringAsFixed(2)} km',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Current Location: ${_locationService.currentAddress}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Waiting Time: ${_waitingSeconds ~/ 60} min ${_waitingSeconds % 60} sec',
                          style: const TextStyle(color: Colors.white),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isWaiting = !_isWaiting;
                            });

                            if (_isWaiting) {
                              _locationService.stopWaiting();
                              _startWaiting();
                              _backgroundService.invoke('startWaiting');
                            } else {
                              _locationService.startWaiting();
                              _stopWaiting();
                              _backgroundService.invoke('stopWaiting');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            foregroundColor:
                                _isWaiting ? Colors.red : Colors.green,
                          ),
                          child: Text(
                              _isWaiting ? 'Stop Waiting' : 'Start Waiting'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  AnimatedContainer(
                    duration: const Duration(seconds: 1),
                    width: _isJourneyStarted ? 100 : 50,
                    height: _isJourneyStarted ? 100 : 50,
                    decoration: BoxDecoration(
                      color: _isJourneyStarted ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Icon(
                      _isJourneyStarted ? Icons.stop : Icons.play_arrow,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      if (_isJourneyStarted) {
                        _locationService.stopWaiting();
                        _backgroundService.invoke('stopWaiting');
                        _isJourneyStarted = false;

                        _databaseHelper.insertJourney(Journey(
                          id: 0,
                          distance: _locationService.totalDistance,
                          address: _locationService.currentAddress,
                          startTime: _journeyStartTime ?? DateTime.now(),
                          endTime: DateTime.now(),
                        ));
                      } else {
                        _locationService.startWaiting();
                        _backgroundService.invoke('startWaiting');
                        _isJourneyStarted = true;
                        _journeyStartTime = DateTime.now();
                      }
                      setState(() {});
                    },
                    child: Text(
                        _isJourneyStarted ? 'Stop Journey' : 'Start Journey'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _locationService.dispose();
    _waitingTimer.cancel();
    super.dispose();
  }
}
