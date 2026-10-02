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
import 'theme/app_theme.dart';

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
      theme: AppTheme.themeData(_locale),
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
      return const Scaffold(
        backgroundColor: AppTheme.bgBase,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      );
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
          return const Scaffold(
            backgroundColor: AppTheme.bgBase,
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            ),
          );
        }
        final granted = snap.data!.getBool('permissions_granted') ?? false;
        if (!granted) return PermissionsScreen(onLocaleChanged: onLocaleChanged);
        return HomeHub(onLocaleChanged: onLocaleChanged);
      },
    );
  }
}

/// Industrial Command Hub for Field Driver Agent
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
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accentGlow,
                border: Border.all(color: AppTheme.accent),
              ),
              child: const Text('GPL', style: TextStyle(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            Text(l.appTitle, style: AppTheme.headlineFont(context, fontSize: 16)),
          ],
        ),
        actions: [
          const _SyncChip(),
          TextButton(
            onPressed: () => _toggleLocale(context),
            child: Text(l.langToggle, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.inkPrimary)),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.signalDanger, size: 20),
            tooltip: l.logout,
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              await prefs.setString('locale', isAr ? 'ar' : 'fr');
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => LoginScreen(onLocaleChanged: onLocaleChanged),
                  ),
                  (_) => false,
                );
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.space16),
        children: [
          // Monolithic Operations Hero Card
          RawPanel(
            leftBarColor: AppTheme.accent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'POSTE DE PILOTAGE CHAUFFEUR',
                      style: TextStyle(
                        color: AppTheme.inkMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    StatusBadge(label: 'ONLINE', status: BadgeStatus.ok),
                  ],
                ),
                const SizedBox(height: AppTheme.space8),
                Text(
                  l.homeRoute,
                  style: AppTheme.headlineFont(context, fontSize: 20),
                ),
                const SizedBox(height: AppTheme.space4),
                Text(
                  'Distribution sécurisée de bouteilles, géofencing et encaissement B2B.',
                  style: AppTheme.bodyFont(context, fontSize: 12, color: AppTheme.inkMuted),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.space8),

          // Operational Workflow Actions
          _HubActionTile(
            number: '01',
            title: l.homeVehicleCheck,
            subtitle: 'Contrôle ADR & prise en charge du chargement camion',
            icon: Icons.checklist_rtl_sharp,
            isPrimary: true,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VehicleCheckScreen()),
            ),
          ),

          _HubActionTile(
            number: '02',
            title: l.homeRoute,
            subtitle: 'Séquence ordonnée des arrêts & validation GPS',
            icon: Icons.map_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RouteMapScreen()),
            ),
          ),

          _HubActionTile(
            number: '03',
            title: l.homeDelivery,
            subtitle: 'Déchargement pleines/vides, signature & encaissement',
            icon: Icons.local_gas_station_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DeliveryFlowScreen()),
            ),
          ),

          _HubActionTile(
            number: '04',
            title: l.homeSafety,
            subtitle: 'Registre d\'incidents ADR, fuite & preuve photo',
            icon: Icons.warning_amber_sharp,
            accentColor: AppTheme.signalDanger,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SafetyReportScreen()),
            ),
          ),

          _HubActionTile(
            number: '05',
            title: l.homeReconciliation,
            subtitle: 'Clôture de shift, déchargement dépôt & remise caisse',
            icon: Icons.account_balance_wallet_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReconciliationScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _HubActionTile extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;
  final Color? accentColor;

  const _HubActionTile({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.space8),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface1,
        border: Border.all(
          color: isPrimary ? AppTheme.accent : AppTheme.borderRaw,
          width: isPrimary ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.transparent,
          highlightColor: AppTheme.bgSurface2,
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accentColor != null
                        ? accentColor!.withValues(alpha: 0.15)
                        : (isPrimary ? AppTheme.accentGlow : AppTheme.bgSurface3),
                    border: Border.all(
                      color: accentColor ?? (isPrimary ? AppTheme.accent : AppTheme.borderRaw),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      color: accentColor ?? (isPrimary ? AppTheme.accent : AppTheme.inkPrimary),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            number,
                            style: AppTheme.monoFont(
                              color: isPrimary ? AppTheme.accent : AppTheme.inkMuted,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              title,
                              style: AppTheme.headlineFont(
                                context,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTheme.bodyFont(
                          context,
                          fontSize: 11,
                          color: AppTheme.inkMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: isPrimary ? AppTheme.accent : AppTheme.inkMuted,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: pending == 0 ? AppTheme.signalOkBg : AppTheme.signalWarnBg,
        border: Border.all(
          color: pending == 0 ? AppTheme.signalOkBorder : AppTheme.signalWarnBorder,
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          pending == 0 ? '✓ SYNC' : '$pending ⏳',
          style: TextStyle(
            color: pending == 0 ? AppTheme.signalOk : AppTheme.signalWarn,
            fontWeight: FontWeight.w700,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}

