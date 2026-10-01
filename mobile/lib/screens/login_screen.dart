import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gaz_field_agent/l10n/app_localizations.dart';

import '../services/api_client.dart';
import 'permissions_screen.dart';

class LoginScreen extends StatefulWidget {
  final Future<void> Function(Locale)? onLocaleChanged;
  const LoginScreen({super.key, this.onLocaleChanged});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController(text: '+212600000004');
  final _otp = TextEditingController();
  String? _devCode;
  String? _error;
  bool _busy = false;
  bool _codeSent = false;

  Future<void> _requestOtp() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final base = await ApiClient.instance.baseUrl;
      final res = await http.post(
        Uri.parse('$base/api/v1/auth/otp/request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': _phone.text.trim()}),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode != 200) {
        throw Exception(body['detail'] ?? res.body);
      }
      setState(() {
        _codeSent = true;
        _devCode = body['dev_code'] as String?;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final base = await ApiClient.instance.baseUrl;
      final res = await http.post(
        Uri.parse('$base/api/v1/auth/otp/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': _phone.text.trim(),
          'otp_code': _otp.text.trim(),
          'device_id': 'android-field-01',
        }),
      );
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode != 200) {
        throw Exception(data['detail'] ?? res.body);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', data['access_token'] as String);
      await prefs.setString('refresh_token', data['refresh_token'] as String);
      await prefs.setString('role', data['role'] as String);
      await prefs.setString('tenant_id', data['tenant_id'] as String);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PermissionsScreen(onLocaleChanged: widget.onLocaleChanged),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _toggleLocale() async {
    final next = Localizations.localeOf(context).languageCode == 'ar'
        ? const Locale('fr')
        : const Locale('ar');
    await widget.onLocaleChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.topEnd,
                child: TextButton(
                  onPressed: _toggleLocale,
                  child: Text(l.langToggle),
                ),
              ),
              const Spacer(),
              Text(
                l.appTitle,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l.appSubtitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: l.phone),
              ),
              if (_codeSent) ...[
                const SizedBox(height: 12),
                if (_devCode != null)
                  Text('${l.devCode}: $_devCode',
                      style: const TextStyle(color: Colors.orange)),
                TextField(
                  controller: _otp,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(labelText: l.otpCode),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : (_codeSent ? _verify : _requestOtp),
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_codeSent ? l.verify : l.requestOtp),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
