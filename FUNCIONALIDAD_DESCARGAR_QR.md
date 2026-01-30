# Funcionalidad de Descargar Código QR

## ✅ Implementación Completada

### Nueva Funcionalidad: Descargar Código QR

#### 🔽 **Botón de Descarga QR**
- **Ubicación**: AppBar del documento detail screen
- **Icono**: `Icons.qr_code_rounded` con fondo morado
- **Posición**: Entre botón eliminar y botón descargar documento
- **Tooltip**: "Descargar código QR"

#### 📄 **Archivo PDF Generado**
El archivo descargado incluye:

1. **Encabezado**: "CÓDIGO QR DEL DOCUMENTO"
2. **Información del documento**:
   - Código
   - Tipo de documento
   - Área de origen
   - Gestión
   - Fecha del documento
   - Descripción (si existe)

3. **Código QR grande** (200x200 px)
4. **Texto del código QR** (para copiar manualmente)
5. **Instrucciones de uso**:
   - Cómo escanear el QR
   - Cómo usar el texto en el buscador QR
   - Resultado esperado

#### 🎯 **Funcionalidad del QR Scanner**
- **Reconoce códigos QR normales**: Los códigos QR descargados son reconocibles
- **Búsqueda directa**: Usa `DocumentoService.getByQRCode()`
- **Navegación automática**: Va directo al documento encontrado

#### 🎨 **Mejoras en QR Card**
El card del QR ahora incluye:
- **Botón "Descargar QR"**: Descarga el PDF con el código QR
- **Botón "Copiar"**: Copia el código QR al portapapeles
- **Diseño mejorado**: Layout vertical con botones en la parte inferior

### Código Implementado

#### Generación del PDF con QR:
```dart
Future<Uint8List> _generarImagenQR(String qrData, Documento doc) async {
  final pdf = pw.Document();
  
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Container(
        child: pw.Column(
          children: [
            // Título e información del documento
            // Código QR grande (200x200)
            pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: qrData,
              width: 200,
              height: 200,
            ),
            // Instrucciones de uso
          ],
        ),
      ),
    ),
  );
  
  return pdf.save();
}
```

#### Descarga del archivo:
```dart
Future<void> _descargarArchivo(Uint8List bytes, String fileName) async {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.document.createElement('a') as html.AnchorElement
    ..href = url
    ..download = fileName;
  anchor.click();
}
```

### Flujo de Uso

#### Para Descargar QR:
1. Usuario abre documento detail
2. Hace clic en botón **QR** (🔳) morado
3. Se genera PDF con código QR e información
4. Archivo se descarga automáticamente: `QR_{codigo}.png`
5. Usuario puede imprimir o compartir el PDF

#### Para Usar QR Descargado:
1. Usuario escanea el QR del PDF impreso
2. O copia el texto del código del PDF
3. Pega en el buscador QR de la aplicación
4. Sistema encuentra el documento automáticamente
5. Navega al documento detail

### Beneficios

1. **Acceso Offline**: QR impreso funciona sin internet
2. **Compartir Físico**: Puede pegarse en carpetas físicas
3. **Backup**: Respaldo del código QR en caso de problemas
4. **Profesional**: PDF con información completa del documento
5. **Versatilidad**: Funciona tanto escaneado como copiado manualmente

### Archivos Modificados

- `frontend/lib/screens/documentos/documento_detail_screen.dart`
  - Agregado botón de descarga QR
  - Implementada función `_descargarCodigoQR()`
  - Implementada función `_generarImagenQR()`
  - Mejorado QR card con botones adicionales

### Casos de Uso

- **Archivo físico**: Imprimir QR y pegarlo en carpetas físicas
- **Backup**: Tener respaldo del código QR del documento
- **Compartir**: Enviar PDF con QR por email
- **Acceso rápido**: QR impreso para acceso sin buscar en sistema
- **Auditoría**: Documentación física con código de verificación

## 🎯 Resultado Final

Los usuarios ahora pueden:

1. ✅ **Descargar código QR** como PDF profesional
2. ✅ **Imprimir QR** para uso físico
3. ✅ **Escanear QR descargado** en la pantalla QR scanner
4. ✅ **Copiar código manualmente** del PDF si es necesario
5. ✅ **Acceder directamente** al documento desde QR físico

La funcionalidad está completamente integrada y lista para usar. El código QR descargado es 100% compatible con el buscador QR de la aplicación.