import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gaz_field_agent/l10n/app_localizations.dart';

import '../services/api_client.dart';
import '../services/geofence_service.dart';
import 'route_map_screen.dart';

class ChecklistItem {
  final String label;
  bool value;
  ChecklistItem(this.label, this.value);
}

/// Screen C: Pre-trip vehicle safety & load custody.
class VehicleCheckScreen extends StatefulWidget {
  final Future<void> Function(Locale)? onLocaleChanged;
  const VehicleCheckScreen({super.key, this.onLocaleChanged});

  @override
  State<VehicleCheckScreen> createState() => _VehicleCheckScreenState();
}

class _VehicleCheckScreenState extends State<VehicleCheckScreen> {
  late List<ChecklistItem> _items;
  String? _vehicleId;
  String? _shiftId;
  String? _error;
  bool _busy = false;
  List<Map<String, dynamic>> _vehicles = [];

  @override
  void initState() {
    super.initState();
    _items = [];
    _load();
  }

  void _buildItems(AppLocalizations l) {
    if (_items.isNotEmpty) return;
    _items = [
      ChecklistItem(l.check1, false),
      ChecklistItem(l.check2, false),
      ChecklistItem(l.check3, false),
      ChecklistItem(l.check4, false),
      ChecklistItem(l.check5, false),
    ];
  }

  Future<void> _load() async {
    try {
      final api = ApiClient.instance;
      final vehicles = await api.get('/api/v1/vehicles') as List;
      setState(() {
        _vehicles = vehicles.cast<Map<String, dynamic>>();
        if (_vehicles.isNotEmpty && _vehicleId == null) {
          _vehicleId = _vehicles.first['id'] as String;
        }
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _accept() async {
    final l = AppLocalizations.of(context);
    _buildItems(l);
    if (_items.any((i) => !i.value)) {
      setState(() => _error = l.checklistMustPass);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = ApiClient.instance;
      final prefs = await SharedPreferences.getInstance();

      final shift = await api.post('/api/v1/shifts/start', {
        'vehicle_id': _vehicleId,
        'odometer_km': 0,
        'pre_trip_safety': {
          'fire_extinguisher_valid': _items[0].value,
          'cargo_straps_secured': _items[1].value,
          'stacking_compliant': _items[2].value,
          'no_gas_leaks': _items[3].value,
        },
      });
      _shiftId = shift['id'] as String;
      await prefs.setString('shift_id', _shiftId!);
      await prefs.setBool('shift_started', true);
      await prefs.setString('vehicle_id', _vehicleId!);

      await GeofenceService.instance.startShiftMonitoring();

      setState(() => _busy = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l.shiftStarted}: ${shift['status'] ?? 'ACTIVE'}'),
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RouteMapScreen(onLocaleChanged: widget.onLocaleChanged),
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    _buildItems(l);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.preTripTitle),
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
          DropdownButtonFormField<String>(
            initialValue: _vehicleId,
            decoration: InputDecoration(labelText: l.assignedVehicle),
            items: _vehicles
                .map((v) => DropdownMenuItem(
                      value: v['id'] as String,
                      child: Text('${v['plate_number']} ${v['model'] ?? ''}'),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _vehicleId = v),
          ),
          const SizedBox(height: 16),
          ..._items.map(
            (item) => CheckboxListTile(
              value: item.value,
              title: Text(item.label),
              onChanged: (v) => setState(() => item.value = v ?? false),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _accept,
            child: Text(_busy ? l.starting : l.acceptLoad),
          ),
        ],
      ),
    );
  }
}
