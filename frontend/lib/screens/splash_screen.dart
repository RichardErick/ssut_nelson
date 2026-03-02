import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

/// Pantalla inicial al abrir la app. Muestra logo y carga, luego redirige a login o home.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    debugPrint('[SPLASH] initState() - pantalla de carga visible');
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();

    // Inicio inmediato: esperar como mucho 400ms por auth, luego redirigir
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
      try {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        await auth.authReady.timeout(
          const Duration(milliseconds: 400),
          onTimeout: () => debugPrint('[SPLASH] auth timeout 400ms'),
        );
      } catch (_) {}
      if (mounted) _redirect();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _redirect() {
    debugPrint('[SPLASH] _redirect() mounted=$mounted');
    if (!mounted) return;
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      
      // Si está autenticado, verificar si tiene contraseña débil
      if (auth.isAuthenticated) {
        if (auth.tieneContrasenaDebil) {
          debugPrint('[SPLASH] Usuario con contraseña débil -> navegando a /weak-password-warning');
          Navigator.of(context).pushReplacementNamed('/weak-password-warning');
          return;
        }
        debugPrint('[SPLASH] Usuario autenticado -> navegando a /home');
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        debugPrint('[SPLASH] Usuario no autenticado -> navegando a /login');
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e, st) {
      debugPrint('[SPLASH] ERROR en _redirect: $e');
      debugPrint('[SPLASH] stack: $st');
      if (mounted) {
        try {
          Navigator.of(context).pushReplacementNamed('/login');
        } catch (_) {
          debugPrint('[SPLASH] No se pudo navegar a /login');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Material(
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade900,
                  Colors.blue.shade700,
                  const Color(0xFF0D47A1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Center(
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.description_rounded,
                          size: 72,
                          color: Colors.white,
                        ),
                        SizedBox(height: 28),
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Cargando...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Sistema de Gestión Documental SSUT',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Splash breve tras iniciar sesión ("Iniciando sesión...").
class SessionSplashScreen extends StatefulWidget {
  const SessionSplashScreen({super.key});

  @override
  State<SessionSplashScreen> createState() => _SessionSplashScreenState();
}

class _SessionSplashScreenState extends State<SessionSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();

    Future.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      
      // Verificar si el usuario tiene contraseña débil
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.tieneContrasenaDebil) {
        Navigator.of(context).pushReplacementNamed('/weak-password-warning');
      } else {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Material(
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade800,
                  Colors.blue.shade600,
                  const Color(0xFF1565C0),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 64,
                        color: Colors.white,
                      ),
                      SizedBox(height: 24),
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Iniciando sesión...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Redirigiendo al sistema',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
