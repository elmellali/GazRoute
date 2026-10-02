import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gaz_field_agent/l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/api_client.dart';

/// Safety Report Screen: ADR Gas Safety Incident recording with GPS and severity classification.
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

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
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
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(l.safetyIncident),
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
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // Safety Warning Banner
          RawPanel(
            borderColor: _severity == 'CRITICAL' ? AppTheme.statusRed : AppTheme.accentAmber,
            backgroundColor: AppTheme.surfaceBright,
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.report_problem_outlined,
                  color: _severity == 'CRITICAL' ? AppTheme.statusRed : AppTheme.accentAmber,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAr ? 'بروتوكول السلامة ADR والغاز' : 'PROTOCOLE DE SÉCURITÉ ADR',
                        style: AppTheme.headline(
                          context,
                          size: 14,
                          weight: FontWeight.w700,
                          color: _severity == 'CRITICAL' ? AppTheme.statusRed : AppTheme.accentAmber,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isAr
                            ? 'يتم إشعار مركز الإشراف فور تسجيل أي حادث خطير مع إحداثيات GPS المباشرة.'
                            : 'Tout signalement critique alerte immédiatement la cellule de sécurité avec horodatage et localisation GPS.',
                        style: AppTheme.body(context, size: 12, color: AppTheme.inkSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Severity Selector
          Text(
            (isAr ? 'مستوى الخطورة' : 'NIVEAU DE GRAVITÉ').toUpperCase(),
            style: AppTheme.label(context, color: AppTheme.inkMuted),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              _buildSeverityOption(context, 'LOW', l.low, AppTheme.inkMuted),
              const SizedBox(width: 8),
              _buildSeverityOption(context, 'HIGH', l.high, AppTheme.accentAmber),
              const SizedBox(width: 8),
              _buildSeverityOption(context, 'CRITICAL', l.critical, AppTheme.statusRed),
            ],
          ),
          const SizedBox(height: 20),

          // Incident Type
          Text(
            l.incidentType.toUpperCase(),
            style: AppTheme.label(context, color: AppTheme.inkMuted),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _incidentType,
            dropdownColor: AppTheme.surfaceBright,
            style: AppTheme.headline(context, size: 14, weight: FontWeight.w600),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.category_outlined, color: AppTheme.inkMuted, size: 18),
            ),
            items: _types
                .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(_typeLabel(l, c)),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _incidentType = v ?? 'LEAK'),
          ),
          const SizedBox(height: 20),

          // Description
          Text(
            l.description.toUpperCase(),
            style: AppTheme.label(context, color: AppTheme.inkMuted),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _description,
            maxLines: 4,
            style: AppTheme.body(context, color: AppTheme.inkPrimary),
            decoration: InputDecoration(
              hintText: isAr
                  ? 'صف الظروف، موقع التسرب، الإجراءات الفورية المتخذة...'
                  : 'Décrivez précisément les faits, la localisation de la fuite, les mesures prises...',
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
            style: ElevatedButton.styleFrom(
              backgroundColor: _severity == 'CRITICAL' ? AppTheme.statusRed : AppTheme.accentAmber,
              foregroundColor: _severity == 'CRITICAL' ? Colors.white : AppTheme.bgCarbon,
            ),
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.bgCarbon),
                  )
                : const Icon(Icons.send_outlined, size: 18),
            label: Text(
              _busy
                  ? l.saving.toUpperCase()
                  : (isAr ? 'إرسال تقرير السلامة' : 'TRANSMETTRE LE RAPPORT').toUpperCase(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeverityOption(BuildContext context, String code, String label, Color color) {
    final isSelected = _severity == code;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _severity = code),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : AppTheme.surfaceDark,
            border: Border.all(
              color: isSelected ? color : AppTheme.borderRaw,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: AppTheme.headline(
                  context,
                  size: 12,
                  weight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? color : AppTheme.inkSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
