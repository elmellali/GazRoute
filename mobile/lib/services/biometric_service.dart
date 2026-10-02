import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Biometric Authentication Service (Fingerprint & Face Recognition)
class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();

  /// Check if device hardware supports biometrics
  Future<bool> get isBiometricAvailable async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } on PlatformException {
      return false;
    }
  }

  /// Get list of available biometric modalities (fingerprint, face, etc.)
  Future<List<BiometricType>> get availableBiometrics async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Check whether biometric quick-login is enabled in user settings
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('biometric_enabled') ?? false;
  }

  /// Set biometric quick-login preference
  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', enabled);
  }

  /// Has a previously saved session token available for quick biometric login
  Future<bool> hasSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final phone = prefs.getString('user_phone');
    return token != null && token.isNotEmpty && phone != null && phone.isNotEmpty;
  }

  /// Prompt user for Fingerprint or Face recognition
  Future<bool> authenticate({
    required String reason,
    String cancelButton = 'Annuler',
  }) async {
    try {
      final available = await isBiometricAvailable;
      if (!available) return false;

      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }

  /// Label for the detected biometric capability (e.g. 'Face ID', 'Empreinte Digitale', or both)
  Future<String> getBiometricLabel({required bool isAr}) async {
    final types = await availableBiometrics;
    final hasFace = types.contains(BiometricType.face);
    final hasFinger = types.contains(BiometricType.fingerprint) || types.contains(BiometricType.strong);

    if (hasFace && hasFinger) {
      return isAr ? 'بصمة الإصبع أو الوجه' : 'Empreinte & Face ID';
    } else if (hasFace) {
      return isAr ? 'التعرف على الوجه (Face ID)' : 'Reconnaissance Faciale (Face ID)';
    } else if (hasFinger) {
      return isAr ? 'بصمة الإصبع' : 'Empreinte Digitale';
    }
    return isAr ? 'المصادقة البيومترية' : 'Biométrie Sécurisée';
  }
}
