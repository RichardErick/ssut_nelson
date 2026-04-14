import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/models/user_role.dart';

// Mock de SharedPreferences
class MockSharedPreferences extends Mock implements SharedPreferences {}

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  
  group('Pruebas de Seguridad y RBAC del AuthProvider', () {
    late AuthProvider authProvider;

    setUp(() {
      authProvider = AuthProvider();
    });

    test('El inicio de sesión exitoso con "doc" en el usuario asigna el rol AdministradorDocumentos', () async {
      await authProvider.login('usuario_doc', 'admin123');
      
      expect(authProvider.isAuthenticated, true);
      expect(authProvider.role, UserRole.administradorDocumentos);
    });

    test('El inicio de sesión exitoso con otro usuario asigna el rol AdministradorSistema (mock por defecto)', () async {
      await authProvider.login('admin_sys', 'admin123');
      
      expect(authProvider.isAuthenticated, true);
      expect(authProvider.role, UserRole.administradorSistema);
    });

    test('El inicio de sesión fallido incrementa el contador y lanza una excepción', () async {
      expect(
        () => authProvider.login('user', 'wrong_pass'),
        throwsA(isA<Exception>()),
      );
      
      // No podemos acceder a _failedAttempts directamente (privada),
      // pero verificamos que después de 5 intentos lanza un mensaje de bloqueo específico.
    });
    
    test('Bloqueo de cuenta después de 5 intentos fallidos', () async {
      for (int i = 0; i < 5; i++) {
        try {
          await authProvider.login('user', 'wrong_pass');
        } catch (_) {}
      }

      // El sexto intento debería lanzar excepción de bloqueo
      try {
        await authProvider.login('user', 'wrong_pass');
        fail('Debería haber lanzado una excepción de bloqueo');
      } catch (e) {
        expect(e.toString(), contains('Bloqueado'));
      }
    });
  });
}
