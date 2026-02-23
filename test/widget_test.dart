import 'package:flutter_test/flutter_test.dart';

import 'package:awos/main.dart';
import 'package:awos/services/mock_api_service.dart';
import 'package:awos/providers/auth_provider.dart';

void main() {
  testWidgets('App initializes with login screen', (WidgetTester tester) async {
    final mockService = MockApiService();
    final authProvider = AuthProvider(mockService);
    await tester.pumpWidget(MyApp(
      authProvider: authProvider,
      coreService: mockService,
    ));

    await tester.pumpAndSettle();

    expect(find.text('Bienvenido a AWOS'), findsOneWidget);
    expect(find.text('Iniciar Sesión'), findsOneWidget);
  });
}
