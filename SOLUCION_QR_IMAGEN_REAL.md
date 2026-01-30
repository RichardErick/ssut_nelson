# Solución: QR como Imagen Real + Error API Corregido

## Problemas Identificados y Solucionados

### ✅ **Error 1: API 404 - URL Malformada**
**Problema**: 
```
uri: http://localhost:5000/api/documentos/qr/http://localhost:5286/documentos/ver/CI-CONT-2026-0001
```
La URL estaba concatenando dos URLs diferentes.

**Solución**:
- Agregado procesamiento en `_buscarPorCodigo()` para limpiar URLs
- Extracción automática del código del documento desde URLs
- Manejo de diferentes formatos de entrada (URL, código limpio, link compartible)

### ✅ **Error 2: QR No Se Genera Como Imagen Real**
**Problema**: El QR se descargaba como PDF en lugar de imagen PNG real

**Solución**:
- Implementado método `_capturarQRComoImagen()` que genera PNG real
- Usa `QrPainter` de qr_flutter para renderizar exactamente como en pantalla
- Crea canvas con fondo blanco y QR centrado
- Convierte a PNG usando `ui.ImageByteFormat.png`

## Implementación Técnica

### **Generación de Imagen QR Real**
```dart
Future<Uint8List> _capturarQRComoImagen(String qrData, Documento doc) async {
  // Crear QrPainter idéntico al de pantalla
  final qrPainter = QrPainter(
    data: qrData,
    version: QrVersions.auto,
    eyeStyle: const QrEyeStyle(
      eyeShape: QrEyeShape.square,
      color: Colors.black,
    ),
    dataModuleStyle: const QrDataModuleStyle(
      dataModuleShape: QrDataModuleShape.square,
      color: Colors.black,
    ),
    gapless: false,
  );
  
  // Renderizar en canvas
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, 400, 400));
  
  // Fondo blanco
  canvas.drawRect(Rect.fromLTWH(0, 0, 400, 400), Paint()..color = Colors.white);
  
  // QR centrado
  canvas.translate(40, 40);
  qrPainter.paint(canvas, Size(320, 320));
  
  // Convertir a PNG
  final picture = recorder.endRecording();
  final img = await picture.toImage(400, 400);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  
  return byteData!.buffer.asUint8List();
}
```

### **Limpieza de URLs en Scanner**
```dart
Future<void> _buscarPorCodigo(String codigoQr) async {
  String codigoLimpio = codigoQr.trim();
  
  // Si es una URL, extraer solo el código del documento
  if (codigoLimpio.startsWith('http')) {
    final partes = codigoLimpio.split('/');
    if (partes.isNotEmpty) {
      codigoLimpio = partes.last;
    }
  }
  
  // Verificar si es un link compartible
  if (codigoLimpio.startsWith('DOC-SHARE:')) {
    await _procesarLinkCompartible(codigoLimpio);
    return;
  }
  
  // Búsqueda normal con código limpio
  final documento = await service.getByQRCode(codigoLimpio);
}
```

## Funcionalidades Mejoradas

### **Descarga de QR**
1. **PDF Info**: Documento completo con QR e información
2. **PNG QR**: Imagen PNG real del QR (400x400px)
3. **Copiar**: Código QR como texto

### **Scanner QR**
1. **Limpieza automática**: Procesa URLs y extrae códigos
2. **Múltiples formatos**: URL, código limpio, link compartible
3. **Mejor debugging**: Muestra código procesado en errores
4. **Procesamiento de imagen**: Detecta PDFs, mejora contraste

### **Compatibilidad**
- ✅ **PNG Real**: Imagen idéntica a la pantalla
- ✅ **Scanner Compatible**: Lee las imágenes generadas
- ✅ **URLs Limpias**: Procesa diferentes formatos de entrada
- ✅ **Fallback**: PDF optimizado si falla PNG

## Archivos Modificados

### 1. `frontend/lib/screens/documentos/documento_detail_screen.dart`
- Agregado método `_capturarQRComoImagen()`
- Modificado `_descargarCodigoQRImagen()` para usar PNG real
- Agregado import `dart:ui` para canvas rendering

### 2. `frontend/lib/screens/qr/qr_scanner_screen.dart`
- Mejorado `_buscarPorCodigo()` con limpieza de URLs
- Agregado procesamiento de diferentes formatos
- Mejor manejo de errores con debugging

## Instrucciones de Uso

### **Para Descargar QR como Imagen:**
1. Ir a detalle de documento
2. Hacer clic en botón "PNG QR" (verde)
3. Se descarga archivo `QR_CODIGO.png` (imagen real 400x400px)

### **Para Leer QR Descargado:**
1. Ir al scanner QR
2. Hacer clic en "Adjuntar foto QR"
3. Seleccionar la imagen PNG descargada
4. El scanner procesará automáticamente la imagen

### **Formatos Soportados por Scanner:**
- ✅ **Imágenes PNG/JPG**: Procesamiento directo
- ✅ **URLs**: Extracción automática del código
- ✅ **Códigos limpios**: Procesamiento directo
- ✅ **Links compartibles**: Formato `DOC-SHARE:...`
- ❌ **PDFs**: Instrucciones para captura de pantalla

## Estado Actual

### ✅ **Funcionando Correctamente**
- Generación de PNG real del QR
- Descarga como imagen PNG (no PDF)
- Scanner lee las imágenes generadas
- URLs se procesan correctamente
- No más errores 404 en API

### ✅ **Calidad de Imagen**
- Resolución: 400x400 píxeles
- Formato: PNG con transparencia
- Fondo: Blanco sólido
- QR: Negro sólido, centrado
- Idéntico al mostrado en pantalla

## Conclusión

Ahora el sistema genera QR como imágenes PNG reales que son completamente compatibles con el scanner. El error 404 de la API también está corregido con el procesamiento automático de URLs.