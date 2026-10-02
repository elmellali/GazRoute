import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gaz_field_agent/l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/api_client.dart';
import '../services/geofence_service.dart';
import '../services/outbox_service.dart';

/// Reconciliation Screen: End-of-shift reconciliation, cylinder unload at depot, and cash count.
class ReconciliationScreen extends StatefulWidget {
  final Future<void> Function(Locale)? onLocaleChanged;
  const ReconciliationScreen({super.key, this.onLocaleChanged});

  @override
  State<ReconciliationScreen> createState() => _ReconciliationScreenState();
}

class _ReconciliationScreenState extends State<ReconciliationScreen> {
  final Map<String, TextEditingController> _qtyFull = {};
  final Map<String, TextEditingController> _qtyEmpty = {};
  final Map<String, TextEditingController> _qtyDefective = {};
  final _cashCounted = TextEditingController(text: '0');
  String? _errorKey;
  String? _errorRaw;
  String? _success;
  bool _busy = false;
  bool _loading = true;
  List<Map<String, dynamic>> _cylinders = [];

  String _errorText(AppLocalizations l) {
    if (_errorKey == 'noActiveShift') return l.noActiveShiftClose;
    return _errorRaw ?? _errorKey ?? '';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cashCounted.dispose();
    for (final c in _qtyFull.values) {
      c.dispose();
    }
    for (final c in _qtyEmpty.values) {
      c.dispose();
    }
    for (final c in _qtyDefective.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ApiClient.instance;
      final types = await api.get('/api/v1/cylinder-types') as List;
      setState(() {
        _cylinders = types.cast<Map<String, dynamic>>();
        for (final c in _cylinders) {
          final id = c['id'] as String;
          _qtyFull[id] = TextEditingController(text: '0');
          _qtyEmpty[id] = TextEditingController(text: '0');
          _qtyDefective[id] = TextEditingController(text: '0');
        }
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorRaw = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _finishCloseout() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _errorKey = null;
      _errorRaw = null;
      _success = null;
    });
    try {
      final api = ApiClient.instance;
      final prefs = await SharedPreferences.getInstance();
      final shiftId = prefs.getString('shift_id');
      final cashierId = prefs.getString('cashier_user_id') ??
          prefs.getString('user_id') ??
          prefs.getString('tenant_id');
      if (shiftId == null) {
        setState(() {
          _errorKey = 'noActiveShift';
          _busy = false;
        });
        return;
      }

      final lines = <Map<String, dynamic>>[];
      for (final c in _cylinders) {
        final id = c['id'] as String;
        final full = double.tryParse(_qtyFull[id]?.text ?? '0') ?? 0;
        final empty = double.tryParse(_qtyEmpty[id]?.text ?? '0') ?? 0;
        final def = double.tryParse(_qtyDefective[id]?.text ?? '0') ?? 0;
        if (full > 0) {
          lines.add({
            'cylinder_type_id': id,
            'state': 'full',
            'quantity': full,
          });
        }
        if (empty > 0) {
          lines.add({
            'cylinder_type_id': id,
            'state': 'empty',
            'quantity': empty,
          });
        }
        if (def > 0) {
          lines.add({
            'cylinder_type_id': id,
            'state': 'defective',
            'quantity': def,
          });
        }
      }

      final body = {
        'unloaded_lines': lines,
        'declared_cash_mad': double.tryParse(_cashCounted.text) ?? 0,
        if (cashierId != null) 'cashier_user_id': cashierId,
      };

      GeofenceService.instance.stop();

      try {
        final res = await api.post(
          '/api/v1/shifts/$shiftId/closeout-unload',
          body,
        );
        setState(() {
          _success =
              '${l.closeoutComplete} · ${l.cashCollected} ${res['cash_variance_mad'] ?? res['declared_cash_mad']} MAD · '
              '${l.movements} ${res['movements_logged'] ?? lines.length}';
          _busy = false;
        });
        await prefs.setBool('shift_started', false);
      } catch (_) {
        await OutboxService.instance.enqueue(
          entityType: 'CLOSEOUT',
          payload: {
            'path': '/api/v1/shifts/$shiftId/closeout-unload',
            ...body,
          },
          clientEventId: DateTime.now().toUtc().toIso8601String(),
          idempotencyKey: DateTime.now().microsecondsSinceEpoch.toString(),
        );
        setState(() {
          _success = l.closeoutQueued;
          _busy = false;
        });
        await prefs.setBool('shift_started', false);
      }
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
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(l.reconciliationTitle),
        actions: [
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
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                // Depot Unload Header
                RawPanel(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warehouse_outlined, color: AppTheme.accentAmber, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            isAr ? 'إرجاع وتفريغ المستودع' : 'DÉCHARGEMENT DÉPÔT',
                            style: AppTheme.label(context, color: AppTheme.inkPrimary),
                          ),
                        ],
                      ),
                      StatusBadge(
                        label: isAr ? 'نهاية الجولة' : 'CLÔTURE',
                        status: 'COMPLETED',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  l.unloadDepot.toUpperCase(),
                  style: AppTheme.label(context, color: AppTheme.inkMuted),
                ),
                const SizedBox(height: 8),

                // Table headers
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          isAr ? 'النوع' : 'TYPE',
                          style: AppTheme.label(context, size: 10, color: AppTheme.inkMuted),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          l.full.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: AppTheme.label(context, size: 10, color: AppTheme.inkMuted),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        flex: 2,
                        child: Text(
                          l.empty.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: AppTheme.label(context, size: 10, color: AppTheme.inkMuted),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        flex: 2,
                        child: Text(
                          l.defective.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: AppTheme.label(context, size: 10, color: AppTheme.statusRed),
                        ),
                      ),
                    ],
                  ),
                ),

                ..._cylinders.map((c) {
                  final id = c['id'] as String;
                  final sizeKg = c['size_kg'] ?? 12;
                  final gasType = c['gas_type'] ?? 'BUTANE';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: RawPanel(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$sizeKg KG',
                                  style: AppTheme.headline(context, size: 14, weight: FontWeight.w700),
                                ),
                                Text(
                                  '$gasType',
                                  style: AppTheme.body(context, size: 11, color: AppTheme.inkMuted),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _qtyFull[id],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: AppTheme.headline(context, size: 15, weight: FontWeight.w700),
                              decoration: const InputDecoration(isDense: true),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _qtyEmpty[id],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: AppTheme.headline(context, size: 15, weight: FontWeight.w700),
                              decoration: const InputDecoration(isDense: true),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _qtyDefective[id],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: AppTheme.headline(
                                context,
                                size: 15,
                                weight: FontWeight.w700,
                                color: AppTheme.statusRed,
                              ),
                              decoration: const InputDecoration(isDense: true),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 20),

                // Cash Declaration Card
                RawPanel(
                  borderColor: AppTheme.accentAmber,
                  backgroundColor: AppTheme.surfaceBright,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.accentAmber, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            l.declaredCash.toUpperCase(),
                            style: AppTheme.headline(context, size: 14, weight: FontWeight.w700, color: AppTheme.accentAmber),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _cashCounted,
                        keyboardType: TextInputType.number,
                        style: AppTheme.headline(context, size: 20, weight: FontWeight.w700, color: AppTheme.inkPrimary),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          suffixText: 'MAD',
                          suffixStyle: AppTheme.headline(context, size: 16, weight: FontWeight.w700, color: AppTheme.accentAmber),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l.closeoutHelp,
                        style: AppTheme.body(context, size: 11, color: AppTheme.inkMuted),
                      ),
                    ],
                  ),
                ),

                if (_errorKey != null || _errorRaw != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0x22EF4444),
                      border: Border.all(color: AppTheme.statusRed),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.statusRed, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorText(l),
                            style: AppTheme.body(context, size: 12, color: AppTheme.statusRed),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (_success != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0x2210B981),
                      border: Border.all(color: AppTheme.statusGreen),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: AppTheme.statusGreen, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _success!,
                            style: AppTheme.body(context, size: 12, color: AppTheme.statusGreen),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _finishCloseout,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.bgCarbon),
                        )
                      : const Icon(Icons.lock_clock_outlined, size: 18),
                  label: Text(_busy ? l.closing.toUpperCase() : l.finalizeCloseout.toUpperCase()),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}
