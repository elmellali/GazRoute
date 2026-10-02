import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gaz_field_agent/l10n/app_localizations.dart';

import '../theme/app_theme.dart';
import 'vehicle_check_screen.dart';

class PermissionsScreen extends StatefulWidget {
  final Future<void> Function(Locale)? onLocaleChanged;
  const PermissionsScreen({super.key, this.onLocaleChanged});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  String _statusKey = 'readyPermissions';

  Future<void> _requestAll() async {
    final l = AppLocalizations.of(context);
    try {
      var service = await Geolocator.isLocationServiceEnabled();
      if (!service) {
        setState(() => _statusKey = 'enableLocation');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _statusKey = 'locationDenied');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('permissions_granted', true);
      await prefs.setBool('location_consent', true);
      await prefs.setString('consent_notice', l.consentNotice);
      setState(() => _statusKey = 'permissionsGranted');
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.bgSurface1,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(color: AppTheme.borderStrong, width: 1),
          ),
          title: Text(l.consentTitle, style: AppTheme.headlineFont(ctx, fontSize: 16)),
          content: Text(l.consentBody, style: AppTheme.bodyFont(ctx, fontSize: 13, color: AppTheme.inkSecondary)),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(100, 40)),
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.ok),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => VehicleCheckScreen(onLocaleChanged: widget.onLocaleChanged),
        ),
      );
    } catch (e) {
      setState(() => _statusKey = e.toString());
    }
  }

  String _statusText(AppLocalizations l) {
    switch (_statusKey) {
      case 'readyPermissions':
        return l.readyPermissions;
      case 'enableLocation':
        return l.enableLocation;
      case 'locationDenied':
        return l.locationDenied;
      case 'permissionsGranted':
        return l.permissionsGranted;
      default:
        return _statusKey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      appBar: AppBar(
        title: Text(l.permissions, style: AppTheme.headlineFont(context, fontSize: 16)),
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
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.space20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RawPanel(
              leftBarColor: AppTheme.signalInfo,
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.signalInfoBg,
                      border: Border.all(color: AppTheme.signalInfoBorder),
                    ),
                    child: const Center(
                      child: Icon(Icons.gps_fixed_sharp, size: 28, color: AppTheme.signalInfo),
                    ),
                  ),
                  const SizedBox(height: AppTheme.space16),
                  Text(
                    'CONFORMITÉ CNDP & GÉOLOCALISATION',
                    style: AppTheme.headlineFont(context, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.space8),
                  Text(
                    l.permissionsBody,
                    textAlign: TextAlign.center,
                    style: AppTheme.bodyFont(context, fontSize: 12, color: AppTheme.inkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.space12),

            Container(
              padding: const EdgeInsets.all(AppTheme.space12),
              decoration: BoxDecoration(
                color: AppTheme.bgSurface2,
                border: Border.all(color: AppTheme.borderRaw),
              ),
              child: Row(
                children: [
                  const Text('ℹ️ ', style: TextStyle(fontSize: 14)),
                  Expanded(
                    child: Text(
                      _statusText(l),
                      style: AppTheme.bodyFont(context, fontSize: 12, color: AppTheme.inkSecondary),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),
            FilledButton(
              onPressed: _requestAll,
              child: Text('✓ ${l.grantPermissions}'),
            ),
          ],
        ),
      ),
    );
  }
}

