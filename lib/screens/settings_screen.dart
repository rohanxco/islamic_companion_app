// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';

import '../models/location_selection.dart';
import '../services/location_storage.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _cityCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();

  bool _loading = true;
  LocationSelection? _saved;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    _countryCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    setState(() {
      _loading = true;
      _msg = null;
    });

    final saved = await LocationStorage.getManualLocation();

    setState(() {
      _saved = saved;
      _loading = false;
    });
  }

  double? _parseDouble(String s) {
    final v = s.trim();
    if (v.isEmpty) return null;
    return double.tryParse(v);
  }

  Future<void> _save() async {
    setState(() => _msg = null);

    final city = _cityCtrl.text.trim();
    if (city.isEmpty) {
      setState(() => _msg = 'City is required.');
      return;
    }

    final country = _countryCtrl.text.trim();
    final lat = _parseDouble(_latCtrl.text);
    final lng = _parseDouble(_lngCtrl.text);

    // If one coordinate is entered, require the other too (avoids half-saved coords)
    final hasLat = lat != null;
    final hasLng = lng != null;
    if (hasLat != hasLng) {
      setState(
        () => _msg = 'Enter both latitude and longitude, or leave both empty.',
      );
      return;
    }

    // Optional: basic range validation
    if (lat != null && (lat < -90 || lat > 90)) {
      setState(() => _msg = 'Latitude must be between -90 and 90.');
      return;
    }
    if (lng != null && (lng < -180 || lng > 180)) {
      setState(() => _msg = 'Longitude must be between -180 and 180.');
      return;
    }

    final loc = LocationSelection(
      city: city,
      country: country,
      latitude: lat,
      longitude: lng,
    );

    await LocationStorage.saveManualLocation(loc);
    await _loadSaved();

    setState(() => _msg = 'Saved.');
  }

  Future<void> _clear() async {
    await LocationStorage.clearManualLocation();
    await _loadSaved();
    setState(() => _msg = 'Cleared.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (_saved != null)
            TextButton(onPressed: _clear, child: const Text('Clear')),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SavedCard(saved: _saved),
                const SizedBox(height: 16),

                Text(
                  'Set manual location (optional coordinates):',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: _cityCtrl,
                  decoration: const InputDecoration(
                    labelText: 'City (required)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: _countryCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Country (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: _latCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Latitude (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: _lngCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Longitude (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                  ),
                ),

                if (_msg != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _msg!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _msg == 'Saved.' || _msg == 'Cleared.'
                          ? Colors.green
                          : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _SavedCard extends StatelessWidget {
  final LocationSelection? saved;

  const _SavedCard({required this.saved});

  @override
  Widget build(BuildContext context) {
    final subtitle = (saved == null) ? 'None' : _format(saved!);

    return Card(
      child: ListTile(
        title: const Text('Saved manual location'),
        subtitle: Text(subtitle),
        leading: const Icon(Icons.location_on_outlined),
      ),
    );
  }

  String _format(LocationSelection loc) {
    final parts = <String>[];
    if (loc.city.isNotEmpty) parts.add(loc.city);
    if (loc.country != null && loc.country!.isNotEmpty) parts.add(loc.country!);

    final base = parts.isEmpty ? 'Saved location' : parts.join(', ');

    if (loc.latitude != null && loc.longitude != null) {
      return '$base\n(${loc.latitude}, ${loc.longitude})';
    }
    return base;
  }
}
