import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gaz_field_agent/l10n/app_localizations.dart';

import '../services/api_client.dart';
import '../services/geofence_service.dart';
import '../services/outbox_service.dart';

/// Screen O: end-of-shift reconciliation & unload at depot.
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

  Future<void> _load() async {
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
      });
    } catch (e) {
      setState(() => _errorRaw = e.toString());
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
              '${l.closeoutComplete} · ${l.cashCollected} ${res['cash_variance_mad'] ?? res['declared_cash_mad']} · '
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
    return Scaffold(
      appBar: AppBar(
        title: Text(l.reconciliationTitle),
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
          Text(l.unloadDepot, style: Theme.of(context).textTheme.titleMedium),
          ..._cylinders.map((c) {
            final id = c['id'] as String;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${c['size_kg']} kg ${c['gas_type']}'),
                  ),
                  SizedBox(
                    width: 80,
                    child: TextFormField(
                      controller: _qtyFull[id],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l.full,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 80,
                    child: TextFormField(
                      controller: _qtyEmpty[id],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l.empty,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 80,
                    child: TextFormField(
                      controller: _qtyDefective[id],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l.defective,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 32),
          TextField(
            controller: _cashCounted,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l.declaredCash),
          ),
          const SizedBox(height: 8),
          Text(l.closeoutHelp),
          if (_errorKey != null || _errorRaw != null)
            Text(_errorText(l), style: const TextStyle(color: Colors.red)),
          if (_success != null)
            Text(_success!, style: const TextStyle(color: Colors.green)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _finishCloseout,
            child: Text(_busy ? l.closing : l.finalizeCloseout),
          ),
        ],
      ),
    );
  }
}
