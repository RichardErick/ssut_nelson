import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
import '../utils/error_helper.dart';
import '../widgets/animated_background.dart';
import '../widgets/app_alert.dart';
import '../widgets/glass_container.dart';
import 'forgot_password_screen.dart';
import 'login/widgets/lockout_timer.dart';
import 'register_screen.dart';
import 'splash_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _checkingBackend = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    // Load saved preferences for "Recordarme"
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() {
          _rememberMe = prefs.getBool('rememberMe') ?? false;
          if (_rememberMe) {
            _usernameController.text = prefs.getString('savedUsername') ?? '';
          }
        });
      }
    });
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutQuart),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      await Future.delayed(const Duration(milliseconds: 800));

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();
      try {
        await authProvider.login(username, password);

        if (authProvider.isAuthenticated) {
          // Save preferences if "Recordarme" is checked
          final prefs = await SharedPreferences.getInstance();
          if (_rememberMe) {
            await prefs.setBool('rememberMe', true);
            await prefs.setString('savedUsername', username);
          } else {
            await prefs.setBool('rememberMe', false);
            await prefs.remove('savedUsername');
          }

          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const SessionSplashScreen()),
            );
          }
        } else {
          _showError('Credenciales invalidas');
        }
      } catch (e) {
        String msg = ErrorHelper.getErrorMessage(e);
        _showError(msg);
        // Trigger rebuild to show lockout timer if locked
        setState(() {});
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    final isLockout =
        message.toLowerCase().contains('bloquead') ||
        message.toLowerCase().contains('intentos');
    AppAlert.error(
      context,
      isLockout ? 'Cuenta bloqueada' : 'Error de inicio de sesión',
      message,
      buttonText: 'Entendido',
    );
  }

  Future<void> _checkBackendConnection() async {
    if (_checkingBackend || !mounted) return;
    setState(() => _checkingBackend = true);
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 3),
      ));
      await dio.get('http://localhost:5000/swagger/v1/swagger.json');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Servidor alcanzable. Puedes iniciar sesión.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'No se pudo conectar al servidor. En otra terminal ejecuta: cd backend y luego dotnet run',
          ),
          backgroundColor: Colors.orange.shade800,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _checkingBackend = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        debugPrint(
          '[LOGIN] build() isAuthenticated=${authProvider.isAuthenticated}',
        );
        if (authProvider.isAuthenticated) {
          debugPrint('[LOGIN] ya autenticado -> redirigiendo a /home');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const SessionSplashScreen()),
              );
            }
          });
          return Scaffold(
            body: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade900, Colors.blue.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Cargando...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        debugPrint('[LOGIN] mostrando formulario de login');
        return _buildLoginContent(context);
      },
    );
  }

  Widget _buildLoginContent(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    debugPrint(
      '[LOGIN] _buildLoginContent() size=${size.width}x${size.height} isDesktop=$isDesktop',
    );

    return Scaffold(
      body:
          isDesktop
              ? Row(
                children: [
                  // Left Side - Hero Section
                  Expanded(
                    flex: 5,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade900, Colors.blue.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: -100,
                            right: -100,
                            child: Container(
                              width: 400,
                              height: 400,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.05),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 50,
                            left: 50,
                            child: Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.05),
                              ),
                            ),
                          ),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildLogo(size: 80),
                                const SizedBox(height: 32),
                                Text(
                                  'SSUT',
                                  style: GoogleFonts.poppins(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 4,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Sistema de Gestion Documental',
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    color: Colors.white70,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Right Side - Login Form
                  Expanded(
                    flex: 4,
                    child: Container(
                      color: Colors.white,
                      child: Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 450),
                          padding: const EdgeInsets.all(48),
                          child: Consumer<AuthProvider>(
                            builder: (context, authProvider, _) {
                              if (authProvider.isLocked) {
                                return LockoutTimer(
                                  lockoutEndTime: authProvider.lockoutEndTime!,
                                  onTimerEnd: () {
                                    setState(() {});
                                  },
                                );
                              }

                              return Form(
                                key: _formKey,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'Bienvenido de nuevo',
                                      style: GoogleFonts.poppins(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade900,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Ingrese sus credenciales para acceder',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 48),
                                    _buildTextField(
                                      controller: _usernameController,
                                      label: 'Usuario',
                                      hint: 'ej. juan.perez',
                                      icon: Icons.person_outline_rounded,
                                      isDark: true,
                                      validator: (v) {
                                        final t = (v ?? '').trim();
                                        if (t.isEmpty) {
                                          return 'Ingrese su usuario';
                                        }
                                        if (t.length < 4 || t.length > 20) {
                                          return 'Debe tener entre 4 y 20 caracteres';
                                        }
                                        if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(t)) {
                                          return 'Solo letras, numeros y guion bajo';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 24),
                                    _buildTextField(
                                      controller: _passwordController,
                                      label: 'Contrasena',
                                      hint: '********',
                                      icon: Icons.lock_outline_rounded,
                                      isPassword: true,
                                      isDark: true,
                                      validator: (v) {
                                        if (v == null || v.isEmpty) {
                                          return 'Ingrese su contraseña';
                                        }
                                        // No exigir longitud mínima en login: el servidor valida (permite doc_admin/admin).
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'El backend debe estar en http://localhost:5000',
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: _checkingBackend ? null : _checkBackendConnection,
                                          child: _checkingBackend
                                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                              : const Text('Comprobar conexión'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Checkbox(
                                              value: _rememberMe,
                                              activeColor: Colors.blue.shade900,
                                              checkColor: Colors.white,
                                              onChanged: (val) {
                                                setState(() {
                                                  _rememberMe = val ?? false;
                                                });
                                              },
                                            ),
                                            Text(
                                              'Recordarme',
                                              style: TextStyle(
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder:
                                                    (_) =>
                                                        const ForgotPasswordScreen(),
                                              ),
                                            );
                                          },
                                          child: Text(
                                            'Olvido su contrasena',
                                            style: TextStyle(
                                              color: Colors.blue.shade700,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 40),
                                    _buildLoginButton(isDark: true),
                                    const SizedBox(height: 24),
                                    Center(
                                      child: TextButton(
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder:
                                                  (_) => const RegisterScreen(),
                                            ),
                                          );
                                        },
                                        child: RichText(
                                          text: TextSpan(
                                            text: 'No tienes cuenta? ',
                                            style: TextStyle(
                                              color:
                                                  isDesktop
                                                      ? Colors.grey.shade600
                                                      : Colors.white70,
                                            ),
                                            children: [
                                              TextSpan(
                                                text: 'Registrarse',
                                                style: TextStyle(
                                                  color:
                                                      isDesktop
                                                          ? Colors.blue.shade900
                                                          : Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  decoration:
                                                      TextDecoration.underline,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    if (isDesktop)
                                      Center(
                                        child: Text(
                                          'SSUT - Gestion Documental v1.0',
                                          style: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 12,
                                          ),
                                        ),
                                      )
                                    else
                                      _buildFooter(),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
              : _buildMobileLayout(),
    );
  }

  Widget _buildLogo({double size = 50}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            padding: EdgeInsets.all(size / 2),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.4),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.description_rounded,
              size: size,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        Text(
          'BIENVENIDO',
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sistema de Gestion Documental SSUT',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white.withOpacity(0.7),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return AnimatedBackground(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              if (authProvider.isLocked &&
                  authProvider.lockoutEndTime != null) {
                return GlassContainer(
                  blur: 20,
                  opacity: 0.12,
                  borderRadius: 24,
                  padding: const EdgeInsets.all(28),
                  child: LockoutTimer(
                    lockoutEndTime: authProvider.lockoutEndTime!,
                    onTimerEnd: () => setState(() {}),
                  ),
                );
              }

              return GlassContainer(
                blur: 20,
                opacity: 0.12,
                borderRadius: 24,
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLogo(size: 60),
                      const SizedBox(height: 20),
                      _buildTitle(),
                      const SizedBox(height: 32),
                      _buildTextField(
                        controller: _usernameController,
                        label: 'Usuario',
                        hint: 'ej. juan.perez',
                        icon: Icons.person_outline_rounded,
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.isEmpty) return 'Ingrese su usuario';
                          if (t.length < 4 || t.length > 20) {
                            return 'Debe tener entre 4 y 20 caracteres';
                          }
                          if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(t)) {
                            return 'Solo letras, numeros y guion bajo';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _passwordController,
                        label: 'Contrasena',
                        hint: '********',
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Ingrese su contraseña';
                          }
                          // No exigir longitud mínima en login: el servidor valida (permite doc_admin/admin).
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                activeColor: Colors.white,
                                checkColor: Colors.blue.shade900,
                                onChanged: (val) {
                                  setState(() {
                                    _rememberMe = val ?? false;
                                  });
                                },
                              ),
                              Text(
                                'Recordarme',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordScreen(),
                                ),
                              );
                            },
                            child: Text(
                              'Olvide mi contrasena',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.white70),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Backend: localhost:5000',
                              style: TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          ),
                          TextButton(
                            onPressed: _checkingBackend ? null : _checkBackendConnection,
                            child: _checkingBackend
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text('Comprobar', style: TextStyle(color: Colors.white.withOpacity(0.9))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      _buildLoginButton(),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: RichText(
                          text: TextSpan(
                            text: 'No tienes cuenta ',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                            ),
                            children: const [
                              TextSpan(
                                text: 'Registrarse',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildFooter(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool isDark = false, // Desktop uses dark text on white bg
    String? Function(String?)? validator,
  }) {
    final textColor = isDark ? Colors.black87 : Colors.white;
    final hintColor =
        isDark ? Colors.grey.withOpacity(0.6) : Colors.white.withOpacity(0.4);
    final borderColor =
        isDark ? Colors.grey.shade300 : Colors.white.withOpacity(0.1);
    final fillColor =
        isDark ? Colors.grey.shade50 : Colors.white.withOpacity(0.1);
    final iconColor =
        isDark ? Colors.grey.shade600 : Colors.white.withOpacity(0.7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: GoogleFonts.inter(
              color:
                  isDark ? Colors.grey.shade800 : Colors.white.withOpacity(0.9),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: isPassword && _obscurePassword,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: hintColor),
            prefixIcon: Icon(icon, color: iconColor),
            suffixIcon:
                isPassword
                    ? IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: iconColor,
                      ),
                      onPressed:
                          () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                    )
                    : null,
            filled: true,
            fillColor: fillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.blue.shade700 : Colors.white,
                width: 2,
              ),
            ),
            errorStyle: const TextStyle(color: Colors.redAccent),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildLoginButton({bool isDark = false}) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? Colors.blue.shade900 : Colors.white,
          foregroundColor: isDark ? Colors.white : Colors.blue.shade900,
          elevation: isDark ? 4 : 0,
          shadowColor: isDark ? Colors.blue.shade900.withOpacity(0.4) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child:
            _isLoading
                ? SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark ? Colors.white : Colors.blue.shade900,
                    ),
                  ),
                )
                : Text(
                  'INICIAR SESION',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.location_on_rounded,
          size: 16,
          color: Colors.white.withOpacity(0.6),
        ),
        const SizedBox(width: 4),
        Text(
          'SSUT - Tarija, Bolivia',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}
