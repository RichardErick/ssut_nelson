import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/data_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'services/anexo_service.dart';
import 'services/api_service.dart';
import 'services/audit_service.dart';
import 'services/carpeta_service.dart';
import 'services/catalogo_service.dart';
import 'services/documento_service.dart';
import 'services/movimiento_service.dart';
import 'services/permiso_service.dart';
import 'services/reporte_service.dart';
import 'services/sync_service.dart';
import 'services/usuario_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Capturar errores asíncronos no manejados
  runZonedGuarded(
    () async {
      debugPrint('[MAIN] Iniciando app...');

      FlutterError.onError = (details) {
        debugPrint('[MAIN] FlutterError: ${details.exception}');
        debugPrint('[MAIN] Stack: ${details.stack}');
        FlutterError.presentError(details);
      };
      ErrorWidget.builder = (details) {
        return Material(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(24),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error al cargar la aplicación',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${details.exception}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      };

      try {
        await initializeDateFormatting('es_BO', null);
        debugPrint('[MAIN] runApp(MyApp)');
        runApp(const MyApp());
      } catch (e, st) {
        debugPrint('[MAIN] Error en arranque: $e');
        debugPrint('[MAIN] Stack: $st');
        runApp(_ErrorApp('$e', st));
      }
    },
    (error, stack) {
      debugPrint('[MAIN] Error no capturado: $error');
      debugPrint('[MAIN] Stack: $stack');
    },
  );
}

// Navigator key global para los servicios
final navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('[MAIN] MyApp.build() - creando providers y MaterialApp');
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => DataProvider()),
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
        Provider(create: (_) => CatalogoService()),
        Provider(create: (_) => AnexoService()),
        ProxyProvider<ApiService, PermisoService>(
          update: (_, api, __) => PermisoService(api),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          debugPrint(
            '[MAIN] MaterialApp builder - themeMode=${themeProvider.themeMode}',
          );
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'SSUT Gestión Documental',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.temaClaro,
            darkTheme: AppTheme.temaOscuro,
            themeMode: themeProvider.themeMode,
            home: const SplashScreen(), // [MAIN] home = SplashScreen
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

/// Pantalla de error si falla el arranque (evita pantalla en blanco).
class _ErrorApp extends StatelessWidget {
  final String message;
  final StackTrace? stack;

  const _ErrorApp(this.message, [this.stack]);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 72,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Error al iniciar la aplicación',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (stack != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        '$stack',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 10,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Text(
                      'Revisa la consola del navegador (F12) para más detalles.\n'
                      'Asegúrate de que el backend esté en http://localhost:5000',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
