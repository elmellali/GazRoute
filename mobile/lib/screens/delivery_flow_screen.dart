import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:uuid/uuid.dart';

import 'package:gaz_field_agent/l10n/app_localizations.dart';

import '../services/api_client.dart';
import '../services/outbox_service.dart';

/// Screens H–L: delivery matrix, returns, payment, proof, review.
class DeliveryFlowScreen extends StatefulWidget {
  final String? stopId;
  final Future<void> Function(Locale)? onLocaleChanged;
  const DeliveryFlowScreen({super.key, this.stopId, this.onLocaleChanged});

  @override
  State<DeliveryFlowScreen> createState() => _DeliveryFlowScreenState();
}

class _DeliveryFlowScreenState extends State<DeliveryFlowScreen> {
  String? _stopId;
  List<Map<String, dynamic>> _cylinders = [];
  final Map<String, TextEditingController> _delivered = {};
  final Map<String, TextEditingController> _empties = {};
  final Map<String, TextEditingController> _defective = {};
  final _recipient = TextEditingController();
  final _payment = TextEditingController(text: '0');
  final _override = TextEditingController();
  String? _errorKey;
  String? _errorRaw;
  String? _success;
  bool _busy = false;
  double? _totalDue;
  late final SignatureController _signatureController;

  String _errorText(AppLocalizations l) {
    if (_errorKey == 'noStopSelected') return l.noStopSelected;
    if (_errorKey == 'enterQty') return l.enterQty;
    if (_errorKey == 'recipientRequired') return l.recipientRequired;
    return _errorRaw ?? _errorKey ?? '';
  }

  @override
  void initState() {
    super.initState();
    _signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    _stopId = widget.stopId;
    _load();
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final api = ApiClient.instance;
      final types = await api.get('/api/v1/cylinder-types') as List;
      setState(() {
        _cylinders = types.cast<Map<String, dynamic>>();
        for (final c in _cylinders) {
          final id = c['id'] as String;
          _delivered[id] = TextEditingController(text: '0');
          _empties[id] = TextEditingController(text: '0');
          _defective[id] = TextEditingController(text: '0');
        }
      });
      _recalc();
    } catch (e) {
      setState(() => _errorRaw = e.toString());
    }
  }

  void _recalc() {
    double total = 0;
    for (final c in _cylinders) {
      final id = c['id'] as String;
      final qty = double.tryParse(_delivered[id]?.text ?? '0') ?? 0;
      final ret = (double.tryParse(_empties[id]?.text ?? '0') ?? 0) +
          (double.tryParse(_defective[id]?.text ?? '0') ?? 0);
      final price = (c['base_sale_price_mad'] as num?)?.toDouble() ?? 0;
      final dep = (c['deposit_amount_mad'] as num?)?.toDouble() ?? 0;
      total += qty * price + (qty - ret) * dep;
    }
    setState(() => _totalDue = total);
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    if (_stopId == null) {
      setState(() {
        _errorKey = 'noStopSelected';
        _errorRaw = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _errorKey = null;
      _errorRaw = null;
      _success = null;
    });
    try {
      final lines = <Map<String, dynamic>>[];
      for (final c in _cylinders) {
        final id = c['id'] as String;
        final d = double.tryParse(_delivered[id]?.text ?? '0') ?? 0;
        final e = double.tryParse(_empties[id]?.text ?? '0') ?? 0;
        final df = double.tryParse(_defective[id]?.text ?? '0') ?? 0;
        if (d > 0 || e > 0 || df > 0) {
          lines.add({
            'cylinder_type_id': id,
            'delivered_full_qty': d,
            'returned_empty_qty': e,
            'returned_defective_qty': df,
          });
        }
      }
      if (lines.isEmpty) {
        setState(() {
          _errorKey = 'enterQty';
          _busy = false;
        });
        return;
      }
      if (_recipient.text.trim().isEmpty) {
        setState(() {
          _errorKey = 'recipientRequired';
          _busy = false;
        });
        return;
      }

      String? sigBase64;
      if (_signatureController.isNotEmpty) {
        final bytes = await _signatureController.toPngBytes();
        if (bytes != null) {
          sigBase64 = base64Encode(bytes);
        }
      }

      final payAmt = double.tryParse(_payment.text) ?? 0;
      final body = {
        'client_event_id': const Uuid().v4(),
        'occurred_at': DateTime.now().toUtc().toIso8601String(),
        'recipient_name': _recipient.text.trim(),
        'signature_media_token': sigBase64,
        'photo_media_token': null,
        'lines': lines,
        if (payAmt > 0)
          'payment': {
            'amount_mad': payAmt,
            'method': 'cash',
          },
        if (_override.text.trim().isNotEmpty) 'override_code': _override.text.trim(),
      };

      try {
        final res = await ApiClient.instance.post(
          '/api/v1/route-stops/$_stopId/deliveries',
          body,
        );
        setState(() {
          _success =
              '${l.receipt} ${res['receipt_number']} · ${l.total} ${res['total_amount_mad']} MAD · ${l.balance} ${res['remaining_outlet_balance_mad']}';
          _busy = false;
        });
      } on ApiException catch (e) {
        setState(() {
          _errorRaw = e.message;
          _busy = false;
        });
      } catch (_) {
        await OutboxService.instance.enqueue(
          entityType: 'DELIVERY',
          payload: {
            'path': '/api/v1/route-stops/$_stopId/deliveries',
            ...body,
          },
          clientEventId: body['client_event_id'] as String,
          idempotencyKey: const Uuid().v4(),
        );
        setState(() {
          _success = l.savedOffline;
          _busy = false;
        });
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
        title: Text(l.deliveryTitle),
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
          TextField(
            controller: _recipient,
            decoration: InputDecoration(labelText: l.recipientName),
          ),
          const SizedBox(height: 16),
          ..._cylinders.map((c) {
            final id = c['id'] as String;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${c['size_kg']} kg ${c['gas_type']} · '
                      '${c['base_sale_price_mad']} MAD · ${l.total} ${c['deposit_amount_mad']}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _delivered[id],
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: l.deliveredFull),
                            onChanged: (_) => _recalc(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _empties[id],
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: l.returns),
                            onChanged: (_) => _recalc(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _defective[id],
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: l.defective),
                            onChanged: (_) => _recalc(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          if (_totalDue != null)
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '${l.totalDue}: ${_totalDue!.toStringAsFixed(2)} MAD',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          TextField(
            controller: _payment,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l.cashCollected),
          ),
          TextField(
            controller: _override,
            decoration: InputDecoration(labelText: l.overrideCode),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        Localizations.localeOf(context).languageCode == 'ar'
                            ? 'توقيع الزبون'
                            : 'Signature Client',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: () => _signatureController.clear(),
                        icon: const Icon(Icons.clear, size: 16),
                        label: Text(
                          Localizations.localeOf(context).languageCode == 'ar'
                              ? 'مسح'
                              : 'Effacer',
                        ),
                      ),
                    ],
                  ),
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Signature(
                        controller: _signatureController,
                        backgroundColor: Colors.grey.shade50,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_errorKey != null || _errorRaw != null)
            Text(_errorText(l), style: const TextStyle(color: Colors.red)),
          if (_success != null)
            Text(_success!, style: const TextStyle(color: Colors.green)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? l.saving : l.finalizeStop),
          ),
        ],
      ),
    );
  }
}
