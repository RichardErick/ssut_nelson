import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'services/audit_service.dart';
import 'services/documento_service.dart';
import 'services/movimiento_service.dart';
import 'services/reporte_service.dart';
import 'services/sync_service.dart';
import 'services/usuario_service.dart';
import 'services/carpeta_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_BO', null);

  runApp(const MyApp());
}

// Navigator key global para los servicios
final navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        Provider(
          create: (_) => ApiService(baseUrl: 'http://localhost:5000/api'),
        ),
        ProxyProvider<ApiService, AuditService>(
          update: (_, api, __) => AuditService(api),
        ),
        ChangeNotifierProxyProvider<AuditService, AuthProvider>(
          create: (_) => AuthProvider(),
          update: (_, audit, auth) => auth!..setAuditService(audit),
        ),
        ProxyProvider2<ApiService, AuditService, SyncService>(
          update: (_, api, audit, __) => SyncService(api, audit),
        ),
        Provider(create: (_) => DocumentoService()),
        Provider(create: (_) => MovimientoService()),
        Provider(create: (_) => ReporteService()),
        Provider(create: (_) => UsuarioService()),
        Provider(create: (_) => CarpetaService()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'SSUT Gestión Documental',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.temaClaro,
            darkTheme: AppTheme.temaOscuro,
            themeMode: themeProvider.themeMode,
            home: const LoginScreen(),
            routes: {
              '/home': (context) => const HomeScreen(),
              '/login': (context) => const LoginScreen(),
            },
          );
        },
      ),
    );
  }
}
