import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gaz_field_agent/l10n/app_localizations.dart';

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
          title: Text(l.consentTitle),
          content: Text(l.consentBody),
          actions: [
            TextButton(
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
      appBar: AppBar(
        title: Text(l.permissions),
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
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.location_on_outlined, size: 72),
            const SizedBox(height: 16),
            Text(l.permissionsBody, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Text(_statusText(l), textAlign: TextAlign.center),
            const Spacer(),
            FilledButton(
              onPressed: _requestAll,
              child: Text(l.grantPermissions),
            ),
          ],
        ),
      ),
    );
  }
}
