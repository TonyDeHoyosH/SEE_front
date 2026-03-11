import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/base_api_service.dart';
import '../../services/local_database_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/floating_navbar.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/onboarding_overlay.dart';
import '../capsules/capsules_screen.dart';
import '../victories/victories_screen.dart';
import '../crisis/crisis_emotion_screen.dart';
import '../../utils/report_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      _DashboardView(
        onNavigateToVictories: () {
          setState(() {
            _selectedIndex = 1;
          });
        },
      ),
      const VictoriesScreen(),
      const CapsulesScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      endDrawer: const AppDrawer(), // Global endDrawer for the flow
      body: Stack(
        children: [
          Positioned.fill(
            child: screens[_selectedIndex],
          ),
          FloatingNavbar(
            currentIndex: _selectedIndex,
            onTap: (index) {
              if (index == 3) {
                ReportUtils.openClinicalReport(context);
              } else {
                setState(() {
                  _selectedIndex = index;
                });
              }
            },
          ),
        ],
      ),
    );
  }
}

class _DashboardView extends StatefulWidget {
  final VoidCallback onNavigateToVictories;

  const _DashboardView({required this.onNavigateToVictories});

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  late Future<Map<String, int>> _metricsFuture;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _metricsFuture = _loadMetrics();
  }

  @override
  void dispose() {
    _removeOnboarding();
    super.dispose();
  }

  void _removeOnboarding() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _maybeShowOnboarding(int victories, int capsules) async {
    if (victories > 0 || capsules > 0) return;
    // Llave por usuario: cada cuenta tiene su propio flag
    final userId = context.read<AuthProvider>().user?.id ?? 'guest';
    final userKey = 'onboarding_seen_v1_$userId';
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(userKey) == true) return;
    if (!mounted) return;
    _overlayEntry = OverlayEntry(
      builder: (_) => OnboardingOverlay(
        onDone: () async {
          _removeOnboarding();
          final p = await SharedPreferences.getInstance();
          await p.setBool(userKey, true);
        },
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  Future<Map<String, int>> _loadMetrics() async {
    final victories = await LocalDatabaseService.countWeeklyVictories();
    int capsuleCount = 0;
    try {
      final capsules = await context.read<CoreApiService>().getCapsules();
      capsuleCount = capsules.where((c) => c.isActive).length;
    } catch (_) {
      capsuleCount = await LocalDatabaseService.countActiveCapsules();
    }
    final result = {
      'capsules': capsuleCount,
      'victories': victories,
    };
    // Show onboarding after first paint
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowOnboarding(victories, capsuleCount);
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    return Scaffold(
      backgroundColor: Colors.transparent, // Use global gradient
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24,
              120), // 24dp padding as requested, extra space for navbar
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: const AppDrawerButton(),
              ),
              const SizedBox(height: 28), // 28dp gap

              if (user != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¡Hola, ${user.nombrePreferido}!',
                        style: AppTheme.lightTheme.textTheme.displaySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Este es tu espacio seguro',
                        style:
                            AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 32),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '¿Cómo te sientes hoy?',
                  style: AppTheme.lightTheme.textTheme.headlineMedium?.copyWith(
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _FeelingButton(
                      emoji: '😊',
                      label: 'Estoy bien',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                '¡Check positivo registrado! Qué bueno que te sientas bien hoy.'),
                            backgroundColor: Color(0xFF4CAF50),
                            duration: Duration(seconds: 3),
                          ),
                        );
                        // Still navigate to victories to keep the flow
                        widget.onNavigateToVictories();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _FeelingButton(
                      emoji: '🆘',
                      label: 'Necesito ayuda',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CrisisEmotionScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              GlassCard(
                padding: const EdgeInsets.all(24),
                child: FutureBuilder<Map<String, int>>(
                  future: _metricsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final data =
                        snapshot.data ?? {'capsules': 0, 'victories': 0};

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Resumen semanal',
                          style: AppTheme.lightTheme.textTheme.headlineMedium
                              ?.copyWith(
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _SummaryRow(
                          icon: Icons.emoji_events_rounded,
                          title: 'Victorias',
                          value: '${data['victories']}',
                        ),
                        const SizedBox(height: 16),
                        _SummaryRow(
                          icon: Icons.auto_awesome,
                          title: 'Cápsulas activas',
                          value: '${data['capsules']}',
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeelingButton extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;

  const _FeelingButton({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 40),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _SummaryRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.accentPrimary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: AppTheme.accentPrimary, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            title,
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: AppTheme.lightTheme.textTheme.headlineMedium,
        ),
      ],
    );
  }
}
