import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'services/base_api_service.dart';
import 'services/auth_api_service.dart';
import 'services/core_api_service.dart';
import 'services/mock_api_service.dart';
import 'providers/auth_provider.dart';
import 'providers/data_provider.dart';
import 'providers/crisis_provider.dart';
import 'providers/victory_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';

// Cambia a false cuando el backend esté corriendo en el servidor.
const bool _kUseMock = true;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final AuthApiService authService;
  final CoreApiService coreService;

  if (_kUseMock) {
    final mock = MockApiService();
    authService = mock;
    coreService = mock;
  } else {
    authService = HttpAuthApiService();
    coreService = HttpCoreApiService();
  }

  final authProvider = AuthProvider(authService);
  await authProvider.loadSavedUser();

  runApp(MyApp(
    authProvider: authProvider,
    coreService: coreService,
  ));
}

class MyApp extends StatelessWidget {
  final AuthProvider authProvider;
  final CoreApiService coreService;

  const MyApp({
    super.key,
    required this.authProvider,
    required this.coreService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<CoreApiService>.value(value: coreService),
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
          create: (_) => VictoryProvider(),
        ),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return MaterialApp(
            title: 'AWOS',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: authProvider.isAuthenticated
                ? const HomeScreen()
                : const LoginScreen(),
          );
        },
      ),
    );
  }
}
