# Solución: QR Scanner Compatible

## ✅ Problema Solucionado

### **Problema Original**:
- Al adjuntar foto del QR descargado salía: "No se pudo leer un QR en la imagen"
- El QR scanner no podía leer el archivo descargado
- Se generaba PDF en lugar de imagen PNG

### **Causa del Problema**:
- **Formato incorrecto**: Se generaba PDF, pero el QR scanner espera imagen (PNG/JPG)
- **Librería de lectura**: `zxing2` necesita imagen de mapa de bits, no PDF
- **Compatibilidad**: Los PDFs no son directamente escaneables por lectores QR móviles

## 🔧 **Solución Implementada**

### **Dos Opciones de Descarga**:

#### 1. **Descarga PDF** (Botón "PDF"):
- **Función**: `_descargarCodigoQR()`
- **Archivo**: `QR_{codigo}.pdf`
- **Uso**: Impresión profesional, documentación
- **Contenido**: QR + información completa del documento

#### 2. **Descarga Imagen PNG** (Botón "IMG"):
- **Función**: `_descargarCodigoQRImagen()`
- **Archivo**: `QR_{codigo}.png`
- **Uso**: **Compatible con QR scanner** ✅
- **Contenido**: QR puro como imagen PNG

### **Interfaz Mejorada**:
```dart
Row(
  children: [
    // Botón PDF (morado)
    OutlinedButton.icon(
      icon: Icons.picture_as_pdf_rounded,
      label: Text('PDF'),
      onPressed: () => _descargarCodigoQR(doc),
    ),
    
    // Botón Imagen PNG (verde) - COMPATIBLE CON SCANNER
    OutlinedButton.icon(
      icon: Icons.image_rounded,
      label: Text('IMG'),
      onPressed: () => _descargarCodigoQRImagen(doc),
    ),
    
    // Botón Copiar (azul)
    OutlinedButton.icon(
      icon: Icons.copy_rounded,
      label: Text('Copiar'),
      onPressed: () => _copiarCodigoQR(),
    ),
  ],
)
```

## 🎯 **Generación de Imagen PNG Real**

### **Proceso Técnico**:
```dart
Future<Uint8List> _generarImagenPNGReal(String qrData, Documento doc) async {
  // 1. Crear canvas de dibujo
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  
  // 2. Fondo blanco
  canvas.drawRect(Rect.fromLTWH(0, 0, 600, 600), backgroundPaint);
  
  // 3. Generar QR usando QrPainter
  final qrPainter = QrPainter(
    data: qrData,
    version: QrVersions.auto,
    eyeStyle: QrEyeStyle(color: Colors.black),
    dataModuleStyle: QrDataModuleStyle(color: Colors.black),
  );
  
  // 4. Dibujar QR centrado (400x400 px)
  qrPainter.paint(canvas, Size(400, 400));
  
  // 5. Agregar título y código como texto
  // 6. Convertir a imagen PNG
  final img = await picture.toImage(600, 600);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  
  return byteData.buffer.asUint8List();
}
```

### **Características de la Imagen PNG**:
- **Tamaño**: 600x600 píxeles
- **Formato**: PNG (compatible con todos los scanners)
- **QR**: 400x400 píxeles centrado
- **Fondo**: Blanco sólido
- **Texto**: Título del documento y código QR como texto
- **Calidad**: Alta resolución para escaneo perfecto

## 📱 **Compatibilidad con QR Scanner**

### **Flujo de Uso Correcto**:
1. **Descargar**: Usuario hace clic en botón "IMG" (verde)
2. **Archivo**: Se descarga `QR_CODIGO.png`
3. **Escanear**: Usuario abre QR scanner en la app
4. **Adjuntar**: Hace clic en "Adjuntar foto QR"
5. **Seleccionar**: Elige el archivo PNG descargado
6. **Resultado**: ✅ QR se lee correctamente
7. **Navegación**: Va directo al documento

### **Mensaje de Confirmación**:
```
"Imagen QR descargada: QR_CODIGO.png (compatible con scanner)"
```

## 🎨 **Mejoras en la Interfaz**

### **Botones del QR Card**:
- 🟣 **PDF**: Descarga PDF profesional para impresión
- 🟢 **IMG**: Descarga PNG compatible con scanner ✅
- 🔵 **Copiar**: Copia código al portapapeles

### **Colores Semánticos**:
- **Morado**: PDF (documentación)
- **Verde**: Imagen (compatible/funcional)
- **Azul**: Copiar (acción rápida)

### **Iconos Apropiados**:
- `picture_as_pdf_rounded`: Para PDF
- `image_rounded`: Para imagen PNG
- `copy_rounded`: Para copiar

## 🎉 **Resultado Final**

### **Antes**:
- ❌ Solo descarga PDF
- ❌ QR scanner no puede leer
- ❌ Error: "No se pudo leer un QR en la imagen"

### **Ahora**:
- ✅ **Dos opciones**: PDF para impresión, PNG para scanner
- ✅ **QR scanner funciona**: Lee perfectamente el PNG
- ✅ **Navegación directa**: Va al documento automáticamente
- ✅ **Interfaz clara**: Botones específicos para cada uso

## 📁 **Archivos Modificados**

- `frontend/lib/screens/documentos/documento_detail_screen.dart`
  - Agregada función `_descargarCodigoQRImagen()`
  - Agregada función `_generarImagenPNGReal()`
  - Mejorado QR card con 3 botones
  - Optimizada generación de imágenes

## 💡 **Casos de Uso**

### **Botón PDF**:
- Impresión profesional
- Documentación física
- Archivo en carpetas

### **Botón IMG** (⭐ Principal):
- **Escaneo con QR scanner de la app**
- Compartir por WhatsApp/email
- Uso en dispositivos móviles

### **Botón Copiar**:
- Pegar directamente en buscador QR
- Compartir código como texto
- Backup rápido

La solución está completamente implementada y el QR scanner ahora puede leer perfectamente las imágenes PNG descargadas. ✅