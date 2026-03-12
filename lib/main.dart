import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

void main() => runApp(const OSMGpsApp());

class OSMGpsApp extends StatelessWidget {
  const OSMGpsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MapHome(),
    );
  }
}

class MapHome extends StatefulWidget {
  const MapHome({super.key});

  @override
  State<MapHome> createState() => _MapHomeState();
}

class _MapHomeState extends State<MapHome> {
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _posSub;
  LatLng? _myLatLng;
  bool _following = true;
  String _status = "Requesting location…";

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        setState(() => _status = "Location services are OFF. Turn on GPS.");
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) {
        setState(() => _status = "Location permission denied.");
        return;
      }
      if (perm == LocationPermission.deniedForever) {
        setState(() => _status = "Permission denied forever. Enable in Settings.");
        return;
      }

      final p = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final first = LatLng(p.latitude, p.longitude);
      setState(() {
        _myLatLng = first;
        _status = "GPS OK";
      });

      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3, 
        ),
      ).listen((pos) {
        final ll = LatLng(pos.latitude, pos.longitude);
        setState(() => _myLatLng = ll);
        if (_following) {
          _mapController.move(ll, _mapController.camera.zoom);
        }
      });

      _mapController.move(first, 18);
    } catch (e) {
      setState(() => _status = "Location error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = _myLatLng ?? const LatLng(15.0794, 120.6200);

    return Scaffold(
      appBar: AppBar(
        title: const Text("OpenStreetMap + GPS"),
        actions: [
          IconButton(
            tooltip: _following ? "Stop following" : "Follow me",
            onPressed: () => setState(() => _following = !_following),
            icon: Icon(_following ? Icons.gps_fixed : Icons.gps_not_fixed),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 16,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture && _following) {
                  setState(() => _following = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.mapmeapp',
              ),
              if (_myLatLng != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _myLatLng!,
                      width: 50,
                      height: 50,
                      child: const Icon(Icons.my_location, size: 34, color: Colors.blue),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _status + (_myLatLng != null ? " • ${_myLatLng!.latitude.toStringAsFixed(5)}, ${_myLatLng!.longitude.toStringAsFixed(5)}" : ""),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final ll = _myLatLng;
          if (ll != null) {
            setState(() => _following = true);
            _mapController.move(ll, 18);
          }
        },
        child: const Icon(Icons.center_focus_strong),
      ),
    );
  }
}