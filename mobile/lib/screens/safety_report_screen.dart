import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gaz_field_agent/l10n/app_localizations.dart';

import '../services/api_client.dart';

/// Screen N: gas safety incident report (CRITICAL severity raises alert).
class SafetyReportScreen extends StatefulWidget {
  final Future<void> Function(Locale)? onLocaleChanged;
  const SafetyReportScreen({super.key, this.onLocaleChanged});

  @override
  State<SafetyReportScreen> createState() => _SafetyReportScreenState();
}

class _SafetyReportScreenState extends State<SafetyReportScreen> {
  String _severity = 'HIGH';
  String _incidentType = 'LEAK';
  final _description = TextEditingController();
  String? _errorKey;
  String? _errorRaw;
  String? _success;
  bool _busy = false;

  static const _types = [
    'LEAK',
    'FIRE',
    'CYLINDER_DAMAGE',
    'VEHICLE_INCIDENT',
    'NEAR_MISS',
    'OTHER',
  ];

  String _typeLabel(AppLocalizations l, String code) {
    switch (code) {
      case 'LEAK':
        return l.typeLeak;
      case 'FIRE':
        return l.typeFire;
      case 'CYLINDER_DAMAGE':
        return l.typeCylinderDamage;
      case 'VEHICLE_INCIDENT':
        return l.typeVehicleIncident;
      case 'NEAR_MISS':
        return l.typeNearMiss;
      default:
        return l.typeOther;
    }
  }

  String _errorText(AppLocalizations l) {
    if (_errorKey == 'descriptionRequired') return l.descriptionRequired;
    if (_errorKey == 'noActiveShift') return l.noActiveShift;
    return _errorRaw ?? _errorKey ?? '';
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    if (_description.text.trim().isEmpty) {
      setState(() => _errorKey = 'descriptionRequired');
      return;
    }
    setState(() {
      _busy = true;
      _errorKey = null;
      _errorRaw = null;
      _success = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final shiftId = prefs.getString('shift_id');
      if (shiftId == null) {
        setState(() {
          _errorKey = 'noActiveShift';
          _busy = false;
        });
        return;
      }

      double? lat;
      double? lng;
      try {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm != LocationPermission.denied &&
            perm != LocationPermission.deniedForever) {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          ).timeout(const Duration(seconds: 8));
          lat = pos.latitude;
          lng = pos.longitude;
        }
      } catch (_) {
        // location optional
      }

      final res = await ApiClient.instance.post('/api/v1/safety-incidents', {
        'shift_id': shiftId,
        'incident_type': _incidentType,
        'severity': _severity,
        'description': _description.text.trim(),
        if (lat != null) 'latitude': lat,
        if (lng != null) 'longitude': lng,
      });
      setState(() {
        _success = '${l.incidentRecorded}: ${res['id']} ($_severity)';
        _busy = false;
      });
      _description.clear();
    } catch (e) {
      setState(() {
        _errorRaw = e.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.safetyIncident),
        actions: [
          TextButton(
            onPressed: () async {
              final next = Localizations.localeOf(context).languageCode == 'ar'
                  ? const Locale('fr')
                  : const Locale('ar');
              await widget.onLocaleChanged?.call(next);
            },
            child: Text(l.langToggle),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'LOW', label: Text(l.low)),
              ButtonSegment(value: 'HIGH', label: Text(l.high)),
              ButtonSegment(value: 'CRITICAL', label: Text(l.critical)),
            ],
            selected: {_severity},
            onSelectionChanged: (s) => setState(() => _severity = s.first),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _incidentType,
            decoration: InputDecoration(labelText: l.incidentType),
            items: _types
                .map((c) => DropdownMenuItem(value: c, child: Text(_typeLabel(l, c))))
                .toList(),
            onChanged: (v) => setState(() => _incidentType = v ?? 'LEAK'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _description,
            maxLines: 4,
            decoration: InputDecoration(labelText: l.description),
          ),
          if (_severity == 'CRITICAL')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l.criticalAlert,
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          if (_errorKey != null || _errorRaw != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_errorText(l), style: const TextStyle(color: Colors.red)),
            ),
          if (_success != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_success!, style: const TextStyle(color: Colors.green)),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? l.submitting : l.submitIncident),
          ),
        ],
      ),
    );
  }
}
