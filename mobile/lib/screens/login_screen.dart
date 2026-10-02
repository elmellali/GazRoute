import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gaz_field_agent/l10n/app_localizations.dart';

import '../services/api_client.dart';
import '../services/biometric_service.dart';
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
  final _pin = TextEditingController(text: 'Passw0rd!');
  final _otp = TextEditingController();

  bool _useOtpMode = false;
  String? _devCode;
  String? _error;
  bool _busy = false;
  bool _codeSent = false;
  bool _hasBiometrics = false;
  bool _hasSavedSession = false;
  String _biometricLabel = 'Biométrie Sécurisée';

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  @override
  void dispose() {
    _phone.dispose();
    _pin.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    final isAvailable = await BiometricService.instance.isBiometricAvailable;
    final hasSession = await BiometricService.instance.hasSavedSession();
    if (!mounted) return;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final label = await BiometricService.instance.getBiometricLabel(isAr: isAr);

    if (mounted) {
      setState(() {
        _hasBiometrics = isAvailable;
        _hasSavedSession = hasSession;
        _biometricLabel = label;
      });
    }

    // Auto-prompt biometric authentication if previously authenticated session exists
    if (isAvailable && hasSession) {
      _authenticateWithBiometrics();
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final reason = isAr
        ? 'المصادقة البيومترية لسائق التوزيع للوصول المباشر'
        : 'Authentification biométrique chauffeur GazRoute pour accès direct';

    final authenticated = await BiometricService.instance.authenticate(
      reason: reason,
      cancelButton: isAr ? 'إلغاء' : 'Annuler',
    );

    if (authenticated && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PermissionsScreen(onLocaleChanged: widget.onLocaleChanged),
        ),
      );
    }
  }

  /// Direct PIN / Password Login (0 DH - Zero SMS Cost)
  Future<void> _loginWithPin() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final base = await ApiClient.instance.baseUrl;
      final res = await http.post(
        Uri.parse('$base/api/v1/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': _phone.text.trim(),
          'password': _pin.text.trim(),
          'device_id': 'android-field-01',
        }),
      );
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode != 200) {
        throw Exception(data['detail'] ?? 'Identifiants invalides');
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', data['access_token'] as String);
      await prefs.setString('refresh_token', data['refresh_token'] as String);
      await prefs.setString('role', data['role'] as String);
      await prefs.setString('tenant_id', data['tenant_id'] as String);
      await prefs.setString('user_phone', _phone.text.trim());
      await prefs.setBool('biometric_enabled', true);

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

  Future<void> _verifyOtp() async {
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
      await prefs.setString('user_phone', _phone.text.trim());
      await prefs.setBool('biometric_enabled', true);

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
    _checkBiometrics();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

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
                            child: Text(
                              isAr ? 'بوابة السائقين' : 'PORTAIL CHAUFFEUR',
                              style: const TextStyle(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const StatusBadge(label: 'OFFLINE 0 DH', status: BadgeStatus.ok),
                        ],
                      ),
                      const SizedBox(height: AppTheme.space16),

                      Text(
                        l.appTitle,
                        style: AppTheme.headlineFont(context, fontSize: 22),
                      ),
                      const SizedBox(height: AppTheme.space4),
                      Text(
                        isAr
                            ? 'تسجيل الدخول المباشر بالرمز السري وبصمة الإصبع أو الوجه'
                            : 'Accès direct par code PIN / Mot de passe & Biométrie',
                        style: AppTheme.bodyFont(context, fontSize: 12, color: AppTheme.inkMuted),
                      ),
                      const SizedBox(height: AppTheme.space24),

                      // Biometric quick-access banner if enabled
                      if (_hasBiometrics && _hasSavedSession) ...[
                        RawPanel(
                          borderColor: AppTheme.accent,
                          backgroundColor: AppTheme.bgSurface2,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.fingerprint, color: AppTheme.accent, size: 28),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _biometricLabel,
                                          style: AppTheme.headlineFont(context, fontSize: 14, fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isAr ? 'جلسة محفوظة ومحمية محلياً' : 'Session chauffeur mémorisée',
                                          style: AppTheme.bodyFont(context, fontSize: 11, color: AppTheme.inkMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accent,
                                  foregroundColor: AppTheme.bgCarbon,
                                ),
                                onPressed: _authenticateWithBiometrics,
                                icon: const Icon(Icons.lock_open, size: 18),
                                label: Text(
                                  (isAr ? 'فتح الجلسة بالبصمة / الوجه' : 'Déverrouiller par Biométrie').toUpperCase(),
                                  style: AppTheme.headlineFont(context, fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Expanded(child: Divider(color: AppTheme.borderRaw)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                isAr ? 'أو الدخول بالرمز السري' : 'OU PAR CODE PIN',
                                style: AppTheme.label(context, size: 10, color: AppTheme.inkMuted),
                              ),
                            ),
                            const Expanded(child: Divider(color: AppTheme.borderRaw)),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Phone Input
                      Text(
                        isAr ? 'رقم هاتف السائق' : 'NUMÉRO DE TÉLÉPHONE DU CHAUFFEUR',
                        style: const TextStyle(color: AppTheme.inkMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                      ),
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
                      const SizedBox(height: AppTheme.space16),

                      // Direct PIN / Password Mode (Default: 0 SMS needed)
                      if (!_useOtpMode) ...[
                        Text(
                          isAr ? 'الرمز السري / كلمة المرور (PIN)' : 'CODE PIN / MOT DE PASSE (0 DH)',
                          style: const TextStyle(color: AppTheme.inkMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: AppTheme.space4),
                        TextField(
                          controller: _pin,
                          obscureText: true,
                          style: AppTheme.monoFont(fontSize: 16),
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            prefixIcon: const Icon(Icons.lock_outline, size: 18, color: AppTheme.inkMuted),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.info_outline, size: 16, color: AppTheme.inkMuted),
                              tooltip: 'PIN par défaut: 123456 ou Passw0rd!',
                              onPressed: () {},
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.space20),
                        FilledButton.icon(
                          onPressed: _busy ? null : _loginWithPin,
                          icon: const Icon(Icons.login, size: 18),
                          label: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentContrast),
                                )
                              : Text((isAr ? 'دخول مباشر (0 درهم)' : 'Connexion Directe (0 DH)').toUpperCase()),
                        ),
                      ],

                      // Alternative SMS OTP Mode (if user toggles it)
                      if (_useOtpMode) ...[
                        if (_codeSent) ...[
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
                        const SizedBox(height: AppTheme.space20),
                        FilledButton(
                          onPressed: _busy ? null : (_codeSent ? _verifyOtp : _requestOtp),
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentContrast),
                                )
                              : Text(_codeSent ? '✓ ${l.verify}' : '→ ${l.requestOtp}'),
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

                      const SizedBox(height: AppTheme.space16),
                      Center(
                        child: TextButton(
                          onPressed: () => setState(() => _useOtpMode = !_useOtpMode),
                          child: Text(
                            _useOtpMode
                                ? (isAr ? 'التبديل إلى الدخول بالرمز السري PIN' : 'Revenir au mode Code PIN (0 DH)')
                                : (isAr ? 'طلب رمز SMS OTP بدلاً من الرمز' : 'Utiliser un code SMS OTP'),
                            style: AppTheme.bodyFont(context, fontSize: 11, color: AppTheme.inkMuted),
                          ),
                        ),
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
