# Solución: Error 404 al Ver Documento desde Movimientos

## Problema Identificado

Al hacer clic en un documento desde la pantalla de Movimientos, aparecía un error:
```
Error: No se pudo cargar el documento
statusCode: 404
url: http://localhost:5000/api/documentos/3
```

## Causa Raíz

El servicio `MovimientoService` tenía datos mock (de prueba) que se usaban cuando fallaba la conexión con el backend. Estos datos mock contenían referencias a documentos con IDs que no existen en la base de datos real:

```dart
Movimiento(
  id: 3,
  documentoId: 3,  // ← Este documento no existe en la BD
  documentoCodigo: 'FAC-2024-789',
  ...
)
```

Cuando el usuario hacía clic en el documento, el sistema intentaba cargar el documento con ID 3, pero este no existía, resultando en un error 404.

## Solución Implementada

**Archivo modificado:** `frontend/lib/services/movimiento_service.dart`

### Cambio realizado:

Eliminado el fallback a datos mock. Ahora el servicio:
- ✅ Obtiene los movimientos reales del backend
- ✅ Si falla, lanza el error (que se maneja en la UI)
- ❌ Ya NO usa datos mock que pueden tener IDs inválidos

### Antes:
```dart
Future<List<Movimiento>> getAll() async {
  try {
    final response = await apiService.get('/movimientos');
    return (response.data as List)
        .map((json) => Movimiento.fromJson(json))
        .toList();
  } catch (e) {
    print('API Error: $e. Returning mock movements.');
    return _getMockMovimientos(); // ← Datos falsos con IDs inválidos
  }
}
```

### Después:
```dart
Future<List<Movimiento>> getAll() async {
  final response = await apiService.get('/movimientos');
  return (response.data as List)
      .map((json) => Movimiento.fromJson(json))
      .toList();
}
```

## Validaciones Adicionales

También se agregaron validaciones de null en las pantallas que navegan a detalles de documento:

**Archivos modificados:**
- `frontend/lib/screens/movimientos/movimientos_screen.dart`
- `frontend/lib/screens/movimientos/mis_prestamos_screen.dart`

```dart
Future<void> _verDocumento(int documentoId) async {
  try {
    // ... cargar documento
    final doc = await service.getById(documentoId);
    
    // Validar que el documento existe
    if (doc == null) {
      AppAlert.error(context, 'Error', 'No se pudo cargar el documento.');
      return;
    }
    
    // Navegar solo si el documento existe
    Navigator.push(context, MaterialPageRoute(...));
  } catch (e) {
    AppAlert.error(context, 'Error', 'No se pudo cargar el documento.');
  }
}
```

## Resultado

Ahora:
1. ✅ Solo se muestran movimientos reales de la base de datos
2. ✅ Todos los documentos referenciados existen
3. ✅ Si un documento no existe, se muestra un mensaje de error claro
4. ✅ No hay más errores 404 por datos mock

## Cómo Probar

1. Asegúrate de que el backend esté corriendo en `http://localhost:5000`
2. Inicia sesión en el sistema
3. Ve a la pantalla de "Movimientos"
4. Si no hay movimientos, verás el mensaje "No hay movimientos registrados"
5. Si hay movimientos, al hacer clic en un documento, debería abrir correctamente
6. Si un documento no existe (caso raro), verás un mensaje de error claro

## Nota Importante

Si ves la pantalla de movimientos vacía, es porque:
- No hay movimientos registrados en la base de datos
- Necesitas crear préstamos usando el botón "Registrar préstamo"
- Los movimientos se crean automáticamente cuando:
  - Se registra un préstamo (tipo "Salida")
  - Se devuelve un documento (tipo "Entrada")
