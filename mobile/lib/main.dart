import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gaz_field_agent/l10n/app_localizations.dart';

import 'screens/login_screen.dart';
import 'screens/permissions_screen.dart';
import 'screens/vehicle_check_screen.dart';
import 'screens/route_map_screen.dart';
import 'screens/delivery_flow_screen.dart';
import 'screens/reconciliation_screen.dart';
import 'screens/safety_report_screen.dart';
import 'services/outbox_service.dart';
import 'services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OutboxService.instance.db;
  runApp(const GazFieldApp());
}

class GazFieldApp extends StatefulWidget {
  const GazFieldApp({super.key});

  @override
  State<GazFieldApp> createState() => _GazFieldAppState();
}

class _GazFieldAppState extends State<GazFieldApp> {
  Locale _locale = const Locale('ar');

  @override
  void initState() {
    super.initState();
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('locale') ?? 'ar';
    if (mounted) setState(() => _locale = Locale(code));
  }

  Future<void> setLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', locale.languageCode);
    if (mounted) setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'وكيل توزيع الغاز',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: const [Locale('ar'), Locale('fr')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1D4ED8),
          brightness: Brightness.light,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: BootstrapGate(onLocaleChanged: setLocale),
    );
  }
}

/// Decides first screen based on stored session + permissions.
class BootstrapGate extends StatefulWidget {
  final Future<void> Function(Locale)? onLocaleChanged;
  const BootstrapGate({super.key, this.onLocaleChanged});

  @override
  State<BootstrapGate> createState() => _BootstrapGateState();
}

class _BootstrapGateState extends State<BootstrapGate> {
  bool? _ready;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final permsOk = prefs.getBool('permissions_granted') ?? false;
    if (token == null || !permsOk) {
      setState(() => _ready = false);
    } else {
      setState(() => _ready = true);
    }
    SyncService.instance.start();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_ready!) {
      return LoginScreen(onLocaleChanged: widget.onLocaleChanged);
    }
    return PermissionsOrHome(onLocaleChanged: widget.onLocaleChanged);
  }
}

class PermissionsOrHome extends StatelessWidget {
  final Future<void> Function(Locale)? onLocaleChanged;
  const PermissionsOrHome({super.key, this.onLocaleChanged});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final granted = snap.data!.getBool('permissions_granted') ?? false;
        if (!granted) return PermissionsScreen(onLocaleChanged: onLocaleChanged);
        return HomeHub(onLocaleChanged: onLocaleChanged);
      },
    );
  }
}

/// Simple hub after login; agent proceeds through C -> O flow.
class HomeHub extends StatelessWidget {
  final Future<void> Function(Locale)? onLocaleChanged;
  const HomeHub({super.key, this.onLocaleChanged});

  Future<void> _toggleLocale(BuildContext context) async {
    final next = Localizations.localeOf(context).languageCode == 'ar'
        ? const Locale('fr')
        : const Locale('ar');
    await onLocaleChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      appBar: AppBar(
        title: Text(l.appTitle),
        actions: [
          const _SyncChip(),
          TextButton(
            onPressed: () => _toggleLocale(context),
            child: Text(l.langToggle),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l.logout,
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              // keep locale preference across logout
              await prefs.setString('locale', isAr ? 'ar' : 'fr');
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) =>
                        LoginScreen(onLocaleChanged: onLocaleChanged),
                  ),
                  (_) => false,
                );
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VehicleCheckScreen()),
            ),
            child: Text(l.homeVehicleCheck),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RouteMapScreen()),
            ),
            child: Text(l.homeRoute),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DeliveryFlowScreen()),
            ),
            child: Text(l.homeDelivery),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SafetyReportScreen()),
            ),
            child: Text(l.homeSafety),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReconciliationScreen()),
            ),
            child: Text(l.homeReconciliation),
          ),
        ],
      ),
    );
  }
}

class _SyncChip extends StatefulWidget {
  const _SyncChip();

  @override
  State<_SyncChip> createState() => _SyncChipState();
}

class _SyncChipState extends State<_SyncChip> {
  int pending = 0;

  @override
  void initState() {
    super.initState();
    _tick();
    Stream.periodic(const Duration(seconds: 3)).listen((_) => _tick());
  }

  Future<void> _tick() async {
    final n = await OutboxService.instance.pendingCount();
    if (mounted) setState(() => pending = n);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Center(
        child: Text(
          pending == 0 ? '✓' : '$pending ⏳',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
