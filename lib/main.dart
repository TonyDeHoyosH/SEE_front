import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/base_api_service.dart';
import 'services/api_service.dart';
import 'services/mock_api_service.dart';
import 'providers/auth_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/data_provider.dart';
import 'providers/crisis_provider.dart';
import 'providers/victory_provider.dart';
import 'providers/reflections_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'widgets/offline_banner.dart';

// Cambia a false cuando el backend esté corriendo en el servidor.
const bool _kUseMock = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await initializeDateFormatting('es', null);

  final AuthApiService authService;
  final CoreApiService coreService;
  final ReportsApiService reportsService;

  if (_kUseMock) {
    final mock = MockApiService();
    authService = mock;
    coreService = mock;
    reportsService = mock;
  } else {
    final realApi = ApiServiceImpl();
    authService = realApi;
    coreService = realApi;
    reportsService = realApi;
  }

  final authProvider = AuthProvider(authService, coreService);
  await authProvider.loadSavedUser();

  runApp(MyApp(
    authProvider: authProvider,
    coreService: coreService,
    reportsService: reportsService,
  ));
}

class MyApp extends StatelessWidget {
  final AuthProvider authProvider;
  final CoreApiService coreService;
  final ReportsApiService reportsService;

  const MyApp({
    super.key,
    required this.authProvider,
    required this.coreService,
    required this.reportsService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<CoreApiService>.value(value: coreService),
        Provider<ReportsApiService>.value(value: reportsService),
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(
          create: (_) {
            final provider = DataProvider(coreService);
            provider.loadCatalogs();
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => CrisisProvider(coreService),
        ),
        ChangeNotifierProvider(
          create: (_) => VictoryProvider(coreService),
        ),
        ChangeNotifierProvider(create: (_) => ReflectionsProvider()..loadPending()),
        ChangeNotifierProvider(
          create: (ctx) => ConnectivityProvider(
            coreService,
            () => ctx.read<AuthProvider>().user?.id,
            onSyncComplete: () => ctx.read<AuthProvider>().refreshAvatarFromCache(),
          ),
        ),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return MaterialApp(
            title: 'SEE',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            builder: (context, child) {
              return Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.globalBackgroundGradient,
                ),
                child: Stack(
                  children: [
                    child!,
                    const OfflineBanner(),
                  ],
                ),
              );
            },
            home: authProvider.isAuthenticated
                ? const HomeScreen()
                : const LoginScreen(),
          );
        },
      ),
    );
  }
}
