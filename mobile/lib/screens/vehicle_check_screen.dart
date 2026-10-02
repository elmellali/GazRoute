import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gaz_field_agent/l10n/app_localizations.dart';

import '../services/api_client.dart';
import '../services/geofence_service.dart';
import '../theme/app_theme.dart';
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
      final prefs = await SharedPreferences.getInstance();

      // Check if agent already has an active shift; if so, resume directly
      try {
        final activeShift = await api.get('/api/v1/shifts/me/active');
        if (activeShift != null && activeShift is Map && activeShift['id'] != null) {
          final sId = activeShift['id'] as String;
          final vId = activeShift['vehicle_id'] as String?;
          await prefs.setString('shift_id', sId);
          await prefs.setBool('shift_started', true);
          if (vId != null) await prefs.setString('vehicle_id', vId);

          await GeofenceService.instance.startShiftMonitoring();

          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => RouteMapScreen(onLocaleChanged: widget.onLocaleChanged),
              ),
            );
            return;
          }
        }
      } catch (_) {}

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
          backgroundColor: AppTheme.bgSurface2,
          content: Text('✓ ${l.shiftStarted}: ${shift['status'] ?? 'ACTIVE'}', style: const TextStyle(color: AppTheme.signalOk)),
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RouteMapScreen(onLocaleChanged: widget.onLocaleChanged),
        ),
      );
    } catch (e) {
      if (e.toString().contains('already has an active shift')) {
        try {
          final activeShift = await ApiClient.instance.get('/api/v1/shifts/me/active');
          if (activeShift != null && activeShift is Map && activeShift['id'] != null) {
            final sId = activeShift['id'] as String;
            final vId = activeShift['vehicle_id'] as String? ?? _vehicleId;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('shift_id', sId);
            await prefs.setBool('shift_started', true);
            if (vId != null) await prefs.setString('vehicle_id', vId);

            await GeofenceService.instance.startShiftMonitoring();

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: AppTheme.bgSurface2,
                  content: Text('✓ Shift actif repris avec succès', style: TextStyle(color: AppTheme.signalOk)),
                ),
              );
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => RouteMapScreen(onLocaleChanged: widget.onLocaleChanged),
                ),
              );
              return;
            }
          }
        } catch (_) {}
      }

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
      backgroundColor: AppTheme.bgBase,
      appBar: AppBar(
        title: Text(l.preTripTitle, style: AppTheme.headlineFont(context, fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () async {
              final next = Localizations.localeOf(context).languageCode == 'ar'
                  ? const Locale('fr')
                  : const Locale('ar');
              await widget.onLocaleChanged?.call(next);
            },
            child: Text('🌐 ${l.langToggle}', style: const TextStyle(color: AppTheme.inkPrimary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.space16),
        children: [
          // Monolithic Vehicle Selector
          RawPanel(
            leftBarColor: AppTheme.accent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'VÉHICULE & ARMEMENT',
                      style: TextStyle(color: AppTheme.inkMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                    ),
                    StatusBadge(label: 'ADR SÉCURITÉ', status: BadgeStatus.neutral),
                  ],
                ),
                const SizedBox(height: AppTheme.space12),
                Text(l.assignedVehicle, style: const TextStyle(color: AppTheme.inkMuted, fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: AppTheme.space4),
                DropdownButtonFormField<String>(
                  initialValue: _vehicleId,
                  dropdownColor: AppTheme.bgSurface2,
                  style: AppTheme.monoFont(fontSize: 14),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.local_shipping_outlined, size: 20, color: AppTheme.accent),
                  ),
                  items: _vehicles
                      .map((v) => DropdownMenuItem(
                            value: v['id'] as String,
                            child: Text('${v['plate_number']} · ${v['model'] ?? ''}'),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _vehicleId = v),
                ),
              ],
            ),
          ),

          // Checklist Header
          const Padding(
            padding: EdgeInsets.only(left: 2, bottom: 8, top: 4),
            child: Text(
              'CONTRÔLE DE SÉCURITÉ PRÉ-DÉPART (OBLIGATOIRE)',
              style: TextStyle(color: AppTheme.inkMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8),
            ),
          ),

          // Checklist items with raw cards
          ..._items.map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: AppTheme.space8),
              decoration: BoxDecoration(
                color: item.value ? AppTheme.bgSurface2 : AppTheme.bgSurface1,
                border: Border.all(
                  color: item.value ? AppTheme.signalOkBorder : AppTheme.borderRaw,
                  width: 1,
                ),
              ),
              child: CheckboxListTile(
                value: item.value,
                activeColor: AppTheme.signalOk,
                checkColor: Colors.black,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                title: Text(
                  item.label,
                  style: AppTheme.bodyFont(
                    context,
                    fontSize: 13,
                    fontWeight: item.value ? FontWeight.w600 : FontWeight.w400,
                    color: item.value ? AppTheme.inkPrimary : AppTheme.inkSecondary,
                  ),
                ),
                onChanged: (v) => setState(() => item.value = v ?? false),
              ),
            ),
          ),

          if (_error != null)
            Container(
              margin: const EdgeInsets.symmetric(vertical: AppTheme.space8),
              padding: const EdgeInsets.all(AppTheme.space12),
              decoration: BoxDecoration(
                color: AppTheme.signalDangerBg,
                border: Border.all(color: AppTheme.signalDangerBorder),
              ),
              child: Row(
                children: [
                  const Text('🚨 ', style: TextStyle(fontSize: 14)),
                  Expanded(
                    child: Text(_error!, style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12)),
                  ),
                ],
              ),
            ),

          const SizedBox(height: AppTheme.space16),
          FilledButton(
            onPressed: _busy ? null : _accept,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentContrast),
                  )
                : Text('✓ ${l.acceptLoad}'),
          ),
          const SizedBox(height: AppTheme.space16),
        ],
      ),
    );
  }
}

