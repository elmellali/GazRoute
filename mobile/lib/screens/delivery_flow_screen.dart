import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:uuid/uuid.dart';

import 'package:gaz_field_agent/l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/api_client.dart';
import '../services/outbox_service.dart';

/// Delivery Flow Screen: Cylinder matrix, payments, CNDP signature, offline sync.
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
  bool _loading = true;
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
    _recipient.dispose();
    _payment.dispose();
    _override.dispose();
    for (final c in _delivered.values) {
      c.dispose();
    }
    for (final c in _empties.values) {
      c.dispose();
    }
    for (final c in _defective.values) {
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
          _delivered[id] = TextEditingController(text: '0');
          _empties[id] = TextEditingController(text: '0');
          _defective[id] = TextEditingController(text: '0');
        }
        _loading = false;
      });
      _recalc();
    } catch (e) {
      setState(() {
        _errorRaw = e.toString();
        _loading = false;
      });
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
              '${l.receipt} ${res['receipt_number']} · ${l.total} ${res['total_amount_mad']} MAD · ${l.balance} ${res['remaining_outlet_balance_mad']} MAD';
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
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(l.deliveryTitle),
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
                // Stop Info Header
                RawPanel(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isAr ? 'بيانات الاستلام والتسليم' : 'BORDEREAU DE LIVRAISON',
                        style: AppTheme.label(context, color: AppTheme.inkSecondary),
                      ),
                      StatusBadge(
                        label: isAr ? 'قيد المعالجة' : 'EN COURS',
                        status: 'IN_SERVICE',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Recipient Name
                Text(
                  l.recipientName.toUpperCase(),
                  style: AppTheme.label(context, color: AppTheme.inkMuted),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _recipient,
                  style: AppTheme.body(context, color: AppTheme.inkPrimary),
                  decoration: InputDecoration(
                    hintText: isAr ? 'اسم المستلم المسئول' : 'Nom du responsable / gérant',
                    prefixIcon: const Icon(Icons.person_outline, color: AppTheme.inkMuted, size: 18),
                  ),
                ),
                const SizedBox(height: 20),

                // Cylinder Counts
                Text(
                  isAr ? 'حركة قنينات الغاز' : 'MOUVEMENT DES BOUTEILLES',
                  style: AppTheme.label(context, color: AppTheme.inkMuted),
                ),
                const SizedBox(height: 8),

                ..._cylinders.map((c) {
                  final id = c['id'] as String;
                  final sizeKg = c['size_kg'] ?? 12;
                  final gasType = c['gas_type'] ?? 'BUTANE';
                  final price = c['base_sale_price_mad'] ?? 0;
                  final dep = c['deposit_amount_mad'] ?? 0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: RawPanel(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '$sizeKg KG $gasType',
                                style: AppTheme.headline(context, size: 15, weight: FontWeight.w700),
                              ),
                              Text(
                                '$price MAD · Caution $dep MAD',
                                style: AppTheme.label(context, color: AppTheme.inkSecondary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l.deliveredFull,
                                      style: AppTheme.label(context, size: 10, color: AppTheme.inkMuted),
                                    ),
                                    const SizedBox(height: 4),
                                    TextFormField(
                                      controller: _delivered[id],
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: AppTheme.headline(context, size: 16, weight: FontWeight.w700),
                                      decoration: const InputDecoration(isDense: true),
                                      onChanged: (_) => _recalc(),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l.returns,
                                      style: AppTheme.label(context, size: 10, color: AppTheme.inkMuted),
                                    ),
                                    const SizedBox(height: 4),
                                    TextFormField(
                                      controller: _empties[id],
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: AppTheme.headline(context, size: 16, weight: FontWeight.w700),
                                      decoration: const InputDecoration(isDense: true),
                                      onChanged: (_) => _recalc(),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l.defective,
                                      style: AppTheme.label(context, size: 10, color: AppTheme.statusRed),
                                    ),
                                    const SizedBox(height: 4),
                                    TextFormField(
                                      controller: _defective[id],
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: AppTheme.headline(
                                        context,
                                        size: 16,
                                        weight: FontWeight.w700,
                                        color: AppTheme.statusRed,
                                      ),
                                      decoration: const InputDecoration(isDense: true),
                                      onChanged: (_) => _recalc(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                // Total Calculation Display
                if (_totalDue != null) ...[
                  const SizedBox(height: 8),
                  RawPanel(
                    borderColor: AppTheme.accentAmber,
                    backgroundColor: AppTheme.surfaceBright,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.totalDue.toUpperCase(),
                              style: AppTheme.label(context, color: AppTheme.inkSecondary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isAr ? 'المبلغ الصافي المستحق' : 'Montant total net calculé',
                              style: AppTheme.body(context, size: 11, color: AppTheme.inkMuted),
                            ),
                          ],
                        ),
                        Text(
                          '${_totalDue!.toStringAsFixed(2)} MAD',
                          style: AppTheme.headline(
                            context,
                            size: 22,
                            weight: FontWeight.w700,
                            color: AppTheme.accentAmber,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Payment and Override
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.cashCollected.toUpperCase(), style: AppTheme.label(context, color: AppTheme.inkMuted)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _payment,
                            keyboardType: TextInputType.number,
                            style: AppTheme.headline(context, size: 16, weight: FontWeight.w700),
                            decoration: const InputDecoration(
                              isDense: true,
                              prefixIcon: Icon(Icons.payments_outlined, color: AppTheme.inkMuted, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.overrideCode.toUpperCase(), style: AppTheme.label(context, color: AppTheme.inkMuted)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _override,
                            style: AppTheme.body(context, color: AppTheme.inkPrimary),
                            decoration: const InputDecoration(
                              isDense: true,
                              prefixIcon: Icon(Icons.vpn_key_outlined, color: AppTheme.inkMuted, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Signature Pad
                RawPanel(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.draw_outlined, color: AppTheme.accentAmber, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                isAr ? 'توقيع العميل (إلزامي)' : 'SIGNATURE CLIENT (OBLIGATOIRE)',
                                style: AppTheme.label(context, color: AppTheme.inkPrimary),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.inkMuted,
                              padding: EdgeInsets.zero,
                            ),
                            onPressed: () => _signatureController.clear(),
                            icon: const Icon(Icons.refresh, size: 14),
                            label: Text(
                              isAr ? 'مسح' : 'Effacer',
                              style: AppTheme.label(context, size: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 140,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          border: Border.all(color: AppTheme.borderRaw),
                        ),
                        child: Signature(
                          controller: _signatureController,
                          backgroundColor: const Color(0xFFF1F5F9),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isAr
                            ? 'معالجة التوقيع مطابقة لمعايير CNDP وحفظ المعاملات الميدانية'
                            : 'Preuve de livraison horodatée conforme CNDP n°09-08.',
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
                  onPressed: _busy ? null : _submit,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.bgCarbon),
                        )
                      : const Icon(Icons.done_all, size: 18),
                  label: Text(_busy ? l.saving.toUpperCase() : l.finalizeStop.toUpperCase()),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}
