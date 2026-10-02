import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gaz_field_agent/l10n/app_localizations.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';
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
      backgroundColor: AppTheme.bgBase,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.space24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: AlignmentDirectional.topEnd,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(80, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: _toggleLocale,
                    child: Text('🌐 ${l.langToggle}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: AppTheme.space24),

                // Monolithic Authentication Terminal Card
                RawPanel(
                  leftBarColor: AppTheme.accent,
                  padding: const EdgeInsets.all(AppTheme.space24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accentGlow,
                              border: Border.all(color: AppTheme.accent),
                            ),
                            child: const Text('PORTAIL CHAUFFEUR', style: TextStyle(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                          const StatusBadge(label: 'OFFLINE READY', status: BadgeStatus.neutral),
                        ],
                      ),
                      const SizedBox(height: AppTheme.space16),

                      Text(
                        l.appTitle,
                        style: AppTheme.headlineFont(context, fontSize: 22),
                      ),
                      const SizedBox(height: AppTheme.space4),
                      Text(
                        l.appSubtitle,
                        style: AppTheme.bodyFont(context, fontSize: 12, color: AppTheme.inkMuted),
                      ),
                      const SizedBox(height: AppTheme.space24),

                      const Text('NUMÉRO DE TÉLÉPHONE (COMPTE AGENT)', style: TextStyle(color: AppTheme.inkMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                      const SizedBox(height: AppTheme.space4),
                      TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        style: AppTheme.monoFont(fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: '+212600000000',
                          prefixIcon: Icon(Icons.phone_outlined, size: 18, color: AppTheme.inkMuted),
                        ),
                      ),

                      if (_codeSent) ...[
                        const SizedBox(height: AppTheme.space16),
                        if (_devCode != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: AppTheme.space8),
                            padding: const EdgeInsets.all(AppTheme.space8),
                            decoration: BoxDecoration(
                              color: AppTheme.bgSurface2,
                              border: Border.all(color: AppTheme.borderRaw),
                            ),
                            child: Row(
                              children: [
                                const Text('⚡ ', style: TextStyle(fontSize: 14)),
                                Text('${l.devCode}: ', style: const TextStyle(color: AppTheme.inkMuted, fontSize: 11)),
                                Text(_devCode!, style: AppTheme.monoFont(color: AppTheme.accent, fontSize: 14)),
                              ],
                            ),
                          ),
                        const Text('CODE OTP REÇU', style: TextStyle(color: AppTheme.inkMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                        const SizedBox(height: AppTheme.space4),
                        TextField(
                          controller: _otp,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: AppTheme.monoFont(fontSize: 22, color: AppTheme.accent),
                          decoration: const InputDecoration(
                            hintText: '000000',
                            counterText: '',
                          ),
                        ),
                      ],

                      if (_error != null) ...[
                        const SizedBox(height: AppTheme.space12),
                        Container(
                          padding: const EdgeInsets.all(AppTheme.space8),
                          decoration: BoxDecoration(
                            color: AppTheme.signalDangerBg,
                            border: Border.all(color: AppTheme.signalDangerBorder),
                          ),
                          child: Text(_error!, style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12)),
                        ),
                      ],

                      const SizedBox(height: AppTheme.space20),
                      FilledButton(
                        onPressed: _busy ? null : (_codeSent ? _verify : _requestOtp),
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentContrast),
                              )
                            : Text(_codeSent ? '✓ ${l.verify}' : '→ ${l.requestOtp}'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

