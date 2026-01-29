// lib/screens/qibla_screen.dart
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';

import '../models/location_selection.dart';
import '../services/location_service.dart';
import '../services/location_storage.dart';
import '../services/qibla_service.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  bool _loading = true;
  String? _error;

  double? _bearing; // 0..360 from North
  double? _heading; // compass heading 0..360 from North (mobile only)
  LocationSelection? _sourceLoc;

  @override
  void initState() {
    super.initState();
    _init();
    _listenCompass();
  }

  void _listenCompass() {
    // Web: compass is generally not available/reliable
    if (kIsWeb) return;

    FlutterCompass.events?.listen((event) {
      final h = event.heading;
      if (!mounted) return;
      if (h == null) return;
      setState(() => _heading = h);
    });
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Try GPS first
      final status = await LocationService.getStatus();
      if (status == LocationStatus.denied) {
        final req = await LocationService.requestPermission();
        if (req != LocationStatus.ready) {
          await _useManualOrFail();
          return;
        }
      } else if (status == LocationStatus.deniedForever) {
        await _useManualOrFail(
          msg:
              'Location permission is permanently denied.\n\nOpen settings and allow Location, or set Manual Location in Settings.',
        );
        return;
      } else if (status == LocationStatus.servicesOff) {
        await _useManualOrFail(
          msg:
              'Location services are off.\n\nTurn on Location, or set Manual Location in Settings.',
        );
        return;
      }

      final pos = await LocationService.getCurrentPosition();
      final b = QiblaService.bearingDegrees(
        latitude: pos.latitude,
        longitude: pos.longitude,
      );

      if (!mounted) return;
      setState(() {
        _sourceLoc = LocationSelection(
          city: 'Current Location',
          country: null,
          latitude: pos.latitude,
          longitude: pos.longitude,
        );
        _bearing = b;
        _loading = false;
      });
    } catch (e) {
      await _useManualOrFail(msg: 'Could not get location.\n\n$e');
    }
  }

  Future<void> _useManualOrFail({String? msg}) async {
    final manual = await LocationStorage.getSavedLocation();
    if (manual != null) {
      final b = QiblaService.bearingDegrees(
        latitude: manual.latitude!,
        longitude: manual.longitude!,
      );
      if (!mounted) return;
      setState(() {
        _sourceLoc = manual;
        _bearing = b;
        _loading = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = msg ?? 'Could not get location.\n\nSet Manual Location in Settings.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bearing = _bearing;

    return Scaffold(
      appBar: AppBar(title: const Text('Qibla')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
              ? _ErrorView(message: _error!, onRetry: _init)
              : _QiblaView(
                  bearing: bearing!,
                  heading: _heading,
                  sourceLabel: _sourceLoc?.displayName ?? 'Location',
                ),
    );
  }
}

class _QiblaView extends StatelessWidget {
  final double bearing;
  final double? heading;
  final String sourceLabel;

  const _QiblaView({
    required this.bearing,
    required this.heading,
    required this.sourceLabel,
  });

  @override
  Widget build(BuildContext context) {
    final rotationDeg = (heading == null) ? bearing : (bearing - heading!);
    final mode =
        (heading == null) ? 'Web / Static (no compass)' : 'Mobile / Compass mode';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Source: $sourceLabel'),
        const SizedBox(height: 6),
        Text(mode, style: TextStyle(color: Colors.grey[700])),
        const SizedBox(height: 18),
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(width: 2),
            ),
            child: Center(
              child: Transform.rotate(
                angle: rotationDeg * pi / 180.0,
                child: const Icon(Icons.navigation, size: 160),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Text(
            'Qibla Bearing: ${bearing.toStringAsFixed(1)}°',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (heading != null) ...[
          const SizedBox(height: 6),
          Center(child: Text('Your Heading: ${heading!.toStringAsFixed(1)}°')),
        ],
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
