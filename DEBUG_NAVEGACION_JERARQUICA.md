# Debug: Navegación Jerárquica - Instrucciones de Prueba

## Problemas Identificados y Solucionados

### 1. Error de Animación Corregido
- **Error**: `opacity >= 0.0 && opacity <= 1.0 is not true`
- **Solución**: Agregado `clamp(0.0, 1.0)` a todos los TweenAnimationBuilder
- **Estado**: ✅ CORREGIDO

### 2. Debug Mejorado del FloatingActionButton
- **Problema**: Los logs de debug no aparecían
- **Solución**: Agregado debug detallado al inicio del método
- **Estado**: ✅ MEJORADO

## Instrucciones de Prueba

### Paso 1: Abrir Herramientas de Desarrollador
1. Presiona **F12** en el navegador
2. Ve a la pestaña **Console**
3. Limpia la consola (botón de limpiar)

### Paso 2: Probar Navegación Jerárquica

#### Nivel 1 - Vista Principal
1. Estar en la vista principal de carpetas
2. **Resultado esperado**: Botón "Nueva Carpeta"
3. **Debug esperado en consola**:
   ```
   DEBUG FAB: Ejecutando _buildFloatingActionButton()
   DEBUG FAB: _carpetaSeleccionada = null
   DEBUG FAB: Nivel 1 - Vista principal, mostrando Nueva Carpeta
   ```

#### Nivel 2 - Dentro de Carpeta Padre
1. Hacer clic en una carpeta padre (ej: "GESTION")
2. **Resultado esperado**: Botón "Nueva Subcarpeta"
3. **Debug esperado en consola**:
   ```
   DEBUG: Abriendo carpeta "GESTION" (ID: 11, PadreID: null)
   DEBUG: Estado actualizado - _carpetaSeleccionada: GESTION
   DEBUG: carpetaPadreId de la carpeta seleccionada: null
   DEBUG: Forzando rebuild después de abrir carpeta
   DEBUG FAB: Ejecutando _buildFloatingActionButton()
   DEBUG FAB: _carpetaSeleccionada = GESTION
   DEBUG FAB: _carpetaSeleccionada?.carpetaPadreId = null
   DEBUG FAB: Nivel 2 - Dentro de carpeta padre "GESTION", mostrando Nueva Subcarpeta
   ```

#### Nivel 3 - Dentro de Subcarpeta
1. Hacer clic en una subcarpeta (ej: "Rango Documental")
2. **Resultado esperado**: Botón "Nuevo Documento"
3. **Debug esperado en consola**:
   ```
   DEBUG: Abriendo carpeta "Rango Documental" (ID: 12, PadreID: 11)
   DEBUG FAB: Nivel 3 - Dentro de subcarpeta "Rango Documental", mostrando Nuevo Documento
   ```

## Datos de Prueba Según los Logs

Según los logs proporcionados, tienes estas carpetas:
- **Carpeta Padre**: GESTION (ID: 11, carpetaPadreId: null)
- **Subcarpeta**: Rango Documental (ID: 12, carpetaPadreId: 11)

## Qué Hacer Si Sigue Sin Funcionar

### Si no aparecen los logs de debug:
1. Verificar que estás en la pestaña Console de las herramientas de desarrollador
2. Asegurarte de que no hay filtros activos en la consola
3. Refrescar la página completamente (Ctrl+Shift+R)

### Si aparecen los logs pero el botón es incorrecto:
1. Copiar y pegar TODOS los logs de debug que aparezcan
2. Verificar que el `carpetaPadreId` sea correcto en los logs
3. Revisar si hay errores adicionales en la consola

### Si hay errores de compilación:
1. Ejecutar `flutter clean` en la carpeta frontend
2. Ejecutar `flutter pub get`
3. Volver a ejecutar la aplicación

## Comandos de Prueba

```bash
# Limpiar y reconstruir
cd frontend
flutter clean
flutter pub get
flutter run -d chrome --web-port=3000
```

## Información Adicional

- **Usuario actual**: doc_admin (Administrador de Documentos)
- **Permisos**: Tiene permiso "subir_documento" ✅
- **Rol**: AdministradorDocumentos ✅

El usuario tiene todos los permisos necesarios, por lo que el problema debe estar en la lógica de navegación jerárquica.