import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:gaz_field_agent/l10n/app_localizations.dart';

import '../services/api_client.dart';
import '../services/geofence_service.dart';
import 'delivery_flow_screen.dart';
import 'safety_report_screen.dart';
import 'reconciliation_screen.dart';

/// Screens D–G: ordered route stop list, map, en-route, arrival card, stop summary.
class RouteMapScreen extends StatefulWidget {
  final Future<void> Function(Locale)? onLocaleChanged;
  const RouteMapScreen({super.key, this.onLocaleChanged});

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  List<dynamic> _stops = [];
  Map<String, dynamic>? _outlet;
  String? _stopId;
  String? _errorKey;
  String? _errorRaw;
  double? _distance;
  bool _arrived = false;

  String _statusLabel(AppLocalizations l, String? raw) {
    if (raw == null) return '—';
    switch (raw) {
      case 'PENDING':
        return l.status_PENDING;
      case 'EN_ROUTE':
        return l.status_EN_ROUTE;
      case 'NEARBY':
        return l.status_NEARBY;
      case 'ARRIVED':
        return l.status_ARRIVED;
      case 'IN_SERVICE':
        return l.status_IN_SERVICE;
      case 'COMPLETED':
        return l.status_COMPLETED;
      case 'EXCEPTION':
        return l.status_EXCEPTION;
      default:
        return raw;
    }
  }

  String _errorText(AppLocalizations l) {
    if (_errorKey == 'noRoutes') return l.noRoutes;
    if (_errorKey == 'noGps') return l.noGps;
    return _errorRaw ?? _errorKey ?? '';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = ApiClient.instance;
      final routes = await api.get('/api/v1/routes/mine') as List;
      if (routes.isEmpty) {
        setState(() => _errorKey = 'noRoutes');
        return;
      }
      final route = routes.first as Map<String, dynamic>;
      final stops = (route['stops'] as List).cast<dynamic>();
      setState(() {
        _stops = stops;
        if (stops.isNotEmpty) {
          _stopId = stops.first['id'] as String;
        }
      });
      if (_stopId != null) {
        await _loadStop(_stopId!);
      }
    } catch (e) {
      setState(() => _errorRaw = e.toString());
    }
  }

  Future<void> _loadStop(String stopId) async {
    try {
      final api = ApiClient.instance;
      final stop = await api.get('/api/v1/routes/stops/$stopId')
          as Map<String, dynamic>;
      final outletId = stop['outlet_id'] as String;
      final outlet = await api.get('/api/v1/outlets/$outletId')
          as Map<String, dynamic>;
      setState(() {
        _outlet = outlet;
        _arrived = stop['status'] == 'ARRIVED' ||
            stop['status'] == 'IN_SERVICE' ||
            stop['status'] == 'COMPLETED';
      });
    } catch (e) {
      setState(() => _errorRaw = e.toString());
    }
  }

  Future<void> _enRoute() async {
    try {
      await ApiClient.instance.post('/api/v1/routes/stops/$_stopId/en-route', {});
      setState(() {});
    } catch (e) {
      setState(() => _errorRaw = e.toString());
    }
  }

  Future<void> _confirmArrival({String method = 'geofence'}) async {
    final l = AppLocalizations.of(context);
    final prefs = await SharedPreferences.getInstance();
    final pos = GeofenceService.instance.lastPosition;
    if (pos == null) {
      setState(() {
        _errorKey = 'noGps';
        _errorRaw = null;
      });
      return;
    }
    final lat = pos.latitude;
    final lng = pos.longitude;
    final d = GeofenceService.instance.distanceTo(lat, lng);
    setState(() => _distance = d);
    try {
      final res = await ApiClient.instance.post(
        '/api/v1/routes/stops/$_stopId/check-in',
        {
          'client_event_id': const Uuid().v4(),
          'occurred_at': DateTime.now().toUtc().toIso8601String(),
          'method': method,
          'latitude': lat,
          'longitude': lng,
          'accuracy_m': pos.accuracy,
        },
      );
      setState(() {
        _arrived = true;
        _distance = (res['distance_meters'] as num?)?.toDouble();
        _errorKey = null;
        _errorRaw = null;
      });
      await prefs.setBool('arrived_$_stopId', true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${l.arrived} · ${_distance?.toStringAsFixed(0) ?? '0'} m',
          ),
        ),
      );
    } catch (e) {
      setState(() => _errorRaw = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.routeArrivalTitle),
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
          IconButton(
            icon: const Icon(Icons.warning, color: Colors.red),
            tooltip: l.safetyReport,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SafetyReportScreen(onLocaleChanged: widget.onLocaleChanged),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined),
            tooltip: l.reconciliation,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ReconciliationScreen(onLocaleChanged: widget.onLocaleChanged),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.stops, style: Theme.of(context).textTheme.titleMedium),
          ..._stops.map(
            (s) => Card(
              child: ListTile(
                title: Text('${l.stop} ${s['sequence_order']}'),
                subtitle: Text(_statusLabel(l, s['status'] as String?)),
                selected: s['id'] == _stopId,
                onTap: () {
                  setState(() => _stopId = s['id'] as String);
                  _loadStop(_stopId!);
                },
              ),
            ),
          ),
          if (_outlet != null) ...[
            const Divider(height: 32),
            Text(_outlet!['name'] as String,
                style: Theme.of(context).textTheme.titleLarge),
            Text('${l.tel}: ${_outlet!['phone']}'),
            Text('${l.geofence}: ${_outlet!['geofence_radius_m']} m'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _enRoute,
                    child: Text(l.enRoute),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _arrived ? null : () => _confirmArrival(),
                    child: Text(l.confirmArrival),
                  ),
                ),
              ],
            ),
            if (_distance != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${l.distance}: ${_distance!.toStringAsFixed(1)} m',
                ),
              ),
            if (_arrived) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DeliveryFlowScreen(
                      stopId: _stopId,
                      onLocaleChanged: widget.onLocaleChanged,
                    ),
                  ),
                ),
                child: Text(l.openDelivery),
              ),
            ],
          ],
          if (_errorKey != null || _errorRaw != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _errorText(l),
                style: const TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }
}
