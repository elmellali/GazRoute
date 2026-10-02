import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:gaz_field_agent/l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/api_client.dart';
import '../services/geofence_service.dart';
import 'delivery_flow_screen.dart';
import 'safety_report_screen.dart';
import 'reconciliation_screen.dart';

/// Route Map & Stops Screen: Editorial sequence list, geofence check-in, stop actions.
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
  bool _loading = true;

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

  String _errorText(AppLocalizations l, bool isAr) {
    if (_errorKey == 'noRoutes') return l.noRoutes;
    if (_errorKey == 'noGps') return l.noGps;
    if (_errorRaw != null) {
      if (_errorRaw!.contains('TimeoutException')) {
        return isAr
            ? 'انتهت مهلة الاتصال بالخادم. يرجى التحقق من تشغيل الخادم والاتصال بالشبكة.'
            : 'Délai d\'attente dépassé. Vérifiez la connexion au serveur.';
      }
      if (_errorRaw!.contains('SocketException') || _errorRaw!.contains('Connection refused')) {
        return isAr
            ? 'تعذر الاتصال بالخادم المحلي. يرجى التأكد من تشغيل الخادم على المنفذ 8000.'
            : 'Impossible de joindre le serveur. Vérifiez qu\'il est démarré sur le port 8000.';
      }
    }
    return _errorRaw ?? _errorKey ?? '';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorKey = null;
      _errorRaw = null;
    });
    try {
      final api = ApiClient.instance;
      final routes = await api.get('/api/v1/routes/mine') as List?;
      if (routes == null || routes.isEmpty) {
        setState(() {
          _errorKey = 'noRoutes';
          _loading = false;
        });
        return;
      }
      final route = routes.first as Map<String, dynamic>;
      final stops = (route['stops'] as List).cast<dynamic>();
      setState(() {
        _stops = stops;
        if (stops.isNotEmpty) {
          _stopId = stops.first['id'] as String;
        }
        _loading = false;
      });
      if (_stopId != null) {
        await _loadStop(_stopId!);
      }
    } catch (e) {
      setState(() {
        _errorRaw = e.toString();
        _loading = false;
      });
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
      if (_stopId != null) {
        await _loadStop(_stopId!);
      }
      await _load();
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
          backgroundColor: AppTheme.surfaceBright,
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: AppTheme.accentAmber, size: 18),
              const SizedBox(width: 8),
              Text(
                '${l.arrived} · ${_distance?.toStringAsFixed(0) ?? '0'} m',
                style: AppTheme.body(context, color: AppTheme.inkPrimary),
              ),
            ],
          ),
        ),
      );
      await _load();
    } catch (e) {
      setState(() => _errorRaw = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(l.routeArrivalTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.warning_amber_rounded, color: AppTheme.statusRed),
            tooltip: l.safetyReport,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SafetyReportScreen(onLocaleChanged: widget.onLocaleChanged),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined, color: AppTheme.accentAmber),
            tooltip: l.reconciliation,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReconciliationScreen(onLocaleChanged: widget.onLocaleChanged),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final next = isAr ? const Locale('fr') : const Locale('ar');
              await widget.onLocaleChanged?.call(next);
            },
            child: Text(l.langToggle, style: AppTheme.label(context, color: AppTheme.accentAmber)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentAmber))
          : RefreshIndicator(
              color: AppTheme.accentAmber,
              backgroundColor: AppTheme.surfaceDark,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                children: [
                  // Status diagnostic header
                  RawPanel(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.accentAmber,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isAr ? 'خطة التوزيع الحالية' : 'PLAN DE TOURNÉE ACTIF',
                              style: AppTheme.label(context, color: AppTheme.inkSecondary),
                            ),
                          ],
                        ),
                        StatusBadge(
                          label: '${_stops.length} ${isAr ? "نقاط" : "STOPS"}',
                          status: _stops.isNotEmpty ? 'COMPLETED' : 'PENDING',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    l.stops.toUpperCase(),
                    style: AppTheme.label(context, color: AppTheme.inkMuted),
                  ),
                  const SizedBox(height: 8),

                  // Stop cards
                  if (_stops.isEmpty && _errorKey == null && _errorRaw == null)
                    RawPanel(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          isAr ? 'لا توجد محطات مسندة حالياً' : 'Aucun point de livraison planifié.',
                          style: AppTheme.body(context, color: AppTheme.inkSecondary),
                        ),
                      ),
                    ),

                  ..._stops.map((s) {
                    final isSelected = s['id'] == _stopId;
                    final order = s['sequence_order']?.toString() ?? '0';
                    final status = s['status'] as String? ?? 'PENDING';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () {
                          setState(() => _stopId = s['id'] as String);
                          _loadStop(s['id'] as String);
                        },
                        child: RawPanel(
                          borderColor: isSelected ? AppTheme.accentAmber : AppTheme.borderRaw,
                          backgroundColor: isSelected ? AppTheme.surfaceBright : AppTheme.surfaceDark,
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isSelected ? AppTheme.accentAmber : AppTheme.surfaceMuted,
                                  border: Border.all(
                                    color: isSelected ? AppTheme.accentAmber : AppTheme.borderRaw,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  order.padLeft(2, '0'),
                                  style: AppTheme.headline(
                                    context,
                                    size: 14,
                                    weight: FontWeight.w700,
                                    color: isSelected ? AppTheme.bgCarbon : AppTheme.inkPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${l.stop} $order',
                                      style: AppTheme.headline(context, size: 15, weight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _statusLabel(l, status),
                                      style: AppTheme.body(context, size: 12, color: AppTheme.inkSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              StatusBadge(
                                label: _statusLabel(l, status),
                                status: status,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  // Active outlet details panel
                  if (_outlet != null) ...[
                    const SizedBox(height: 16),
                    RawPanel(
                      borderColor: AppTheme.borderRaw,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.storefront_outlined, color: AppTheme.accentAmber, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _outlet!['name'] as String? ?? 'Point de Vente',
                                  style: AppTheme.headline(context, size: 18, weight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: AppTheme.borderRaw),
                          const SizedBox(height: 12),

                          // Metadata row
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(l.tel.toUpperCase(), style: AppTheme.label(context, color: AppTheme.inkMuted)),
                                    const SizedBox(height: 2),
                                    Text(
                                      _outlet!['phone']?.toString() ?? '—',
                                      style: AppTheme.body(context, color: AppTheme.inkPrimary, weight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(l.geofence.toUpperCase(), style: AppTheme.label(context, color: AppTheme.inkMuted)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_outlet!['geofence_radius_m'] ?? 50} m',
                                      style: AppTheme.body(context, color: AppTheme.inkPrimary, weight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          if (_distance != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceMuted,
                                border: Border.all(color: AppTheme.borderRaw),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _distance! <= (_outlet!['geofence_radius_m'] ?? 50)
                                        ? Icons.gps_fixed
                                        : Icons.gps_not_fixed,
                                    size: 16,
                                    color: _distance! <= (_outlet!['geofence_radius_m'] ?? 50)
                                        ? AppTheme.accentAmber
                                        : AppTheme.inkMuted,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${l.distance}: ${_distance!.toStringAsFixed(1)} m',
                                    style: AppTheme.label(context, color: AppTheme.inkPrimary),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _enRoute,
                                  icon: const Icon(Icons.directions_car_outlined, size: 16),
                                  label: Text(l.enRoute),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _arrived ? null : () => _confirmArrival(),
                                  icon: const Icon(Icons.pin_drop_outlined, size: 16),
                                  label: Text(l.confirmArrival),
                                ),
                              ),
                            ],
                          ),

                          if (_arrived) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.surfaceBright,
                                  foregroundColor: AppTheme.accentAmber,
                                  side: const BorderSide(color: AppTheme.accentAmber, width: 1.5),
                                ),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DeliveryFlowScreen(
                                      stopId: _stopId,
                                      onLocaleChanged: widget.onLocaleChanged,
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.local_shipping_outlined, color: AppTheme.accentAmber),
                                label: Text(
                                  l.openDelivery.toUpperCase(),
                                  style: AppTheme.headline(
                                    context,
                                    size: 13,
                                    weight: FontWeight.w700,
                                    color: AppTheme.accentAmber,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  if (_errorKey != null || _errorRaw != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0x22EF4444),
                        border: Border.all(color: AppTheme.statusRed),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.error_outline, color: AppTheme.statusRed, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorText(l, isAr),
                                  style: AppTheme.body(context, size: 13, color: AppTheme.statusRed),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.accentAmber,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              ),
                              onPressed: _load,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: Text(
                                isAr ? 'إعادة المحاولة' : 'Réessayer',
                                style: AppTheme.label(context, color: AppTheme.accentAmber),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
