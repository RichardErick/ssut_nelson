import 'package:dio/dio.dart';

/// Convierte excepciones técnicas en mensajes amigables para el usuario
class ErrorHelper {
  /// Convierte una excepción en un mensaje de error amigable
  static String getErrorMessage(dynamic error) {
    if (error is DioException) {
      return _getDioErrorMessage(error);
    }

    if (error is Exception) {
      final errorString = error.toString();

      // Si ya es un mensaje amigable, devolverlo
      if (!errorString.contains('Exception:') &&
          !errorString.contains('DioException') &&
          !errorString.contains('XMLHttpRequest')) {
        return errorString;
      }

      // Limpiar mensajes técnicos
      String message = errorString
          .replaceAll('Exception: ', '')
          .replaceAll('DioException [', '')
          .replaceAll(']: ', ': ');

      // Detectar tipos específicos de error
      if (message.contains('connection error') ||
          message.contains('XMLHttpRequest') ||
          message.contains('network layer')) {
        return 'Error de conexión. Verifique su conexión a internet e intente nuevamente.';
      }

      if (message.contains('timeout') || message.contains('Timeout')) {
        return 'Tiempo de espera agotado. Por favor, intente nuevamente.';
      }

      if (message.contains('401') || message.contains('Unauthorized')) {
        return 'Credenciales inválidas. Verifique su usuario y contraseña.';
      }

      if (message.contains('403') || message.contains('Forbidden')) {
        return 'No tiene permisos para realizar esta acción.';
      }

      if (message.contains('404') || message.contains('Not Found')) {
        return 'Recurso no encontrado.';
      }

      if (message.contains('500') ||
          message.contains('Internal Server Error')) {
        return 'Error del servidor. Por favor, intente más tarde.';
      }

      // Si el mensaje es muy largo o técnico, devolver uno genérico
      if (message.length > 100 ||
          message.contains('connection errored') ||
          message.contains('onError callback')) {
        return 'Error de conexión. Verifique su conexión a internet e intente nuevamente.';
      }

      return message;
    }

    // Para otros tipos de error
    final errorString = error.toString();
    if (errorString.contains('connection error') ||
        errorString.contains('XMLHttpRequest')) {
      return 'Error de conexión. Verifique su conexión a internet e intente nuevamente.';
    }

    return 'Ha ocurrido un error. Por favor, intente nuevamente.';
  }

  /// Obtiene un mensaje amigable para errores de Dio
  static String _getDioErrorMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Tiempo de espera agotado. Por favor, intente nuevamente.';

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final responseData = error.response?.data;

        // Intentar extraer el mensaje del cuerpo de la respuesta
        if (responseData is Map<String, dynamic>) {
          final message = responseData['message'] as String?;
          if (message != null && message.isNotEmpty) {
            return message;
          }
        }

        // Mensajes específicos por código de estado
        if (statusCode == 400) {
          return 'Solicitud inválida. Verifique los datos ingresados.';
        }
        if (statusCode == 401) {
          return 'Credenciales inválidas. Verifique su usuario y contraseña.';
        }
        if (statusCode == 403) {
          return 'No tiene permisos para realizar esta acción.';
        }
        if (statusCode == 404) {
          return 'Recurso no encontrado.';
        }
        if (statusCode == 423) {
          return message ?? 'Cuenta bloqueada temporalmente por exceso de intentos.';
        }
        if (statusCode == 500) {
          return 'Error del servidor. Por favor, intente más tarde.';
        }
        return 'Error del servidor (${statusCode ?? 'desconocido'}). Por favor, intente nuevamente.';

      case DioExceptionType.cancel:
        return 'Operación cancelada.';

      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
      default:
        return 'Error de conexión. Verifique su conexión a internet e intente nuevamente.';
    }
  }
}
