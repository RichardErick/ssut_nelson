# Mejoras de Seguridad Implementadas

## Fecha: 10 de abril de 2026

---

## 1. Bloqueo de Cuenta Progresivo

### Descripción
El sistema ahora implementa un bloqueo progresivo que aumenta exponencialmente cada vez que un usuario falla repetidamente en su intento de inicio de sesión.

### Funcionamiento
- **Primer bloqueo**: 10 minutos
- **Segundo bloqueo**: 20 minutos (10 × 2)
- **Tercer bloqueo**: 40 minutos (10 × 4)
- **Cuarto bloqueo**: 80 minutos (10 × 8)
- **Quinto bloqueo**: 160 minutos (10 × 16)
- **Sexto bloqueo**: 320 minutos (10 × 32)
- **Séptimo bloqueo**: 640 minutos (10 × 64)
- **Octavo bloqueo y siguientes**: 1440 minutos (24 horas - máximo)

### Fórmula
```
Tiempo de bloqueo = 10 minutos × 2^(bloqueos_acumulados)
```

### Reset del Contador
El contador de bloqueos acumulados se reinicia a 0 cuando el usuario inicia sesión exitosamente.

### Archivos Modificados

#### Backend
- **`backend/Models/Usuario.cs`**: Agregado campo `BloqueosAcumulados`
- **`backend/Controllers/AuthController.cs`**: 
  - Lógica de cálculo progresivo del tiempo de bloqueo
  - Reset del contador tras login exitoso
  - Mensajes informativos con el número de bloqueo

#### Base de Datos
- **`database/add_bloqueos_acumulados.sql`**: Script SQL para agregar la columna
- **`database/APLICAR_BLOQUEO_PROGRESIVO.bat`**: Script batch para aplicar cambios

### Cómo Aplicar los Cambios en la BD

**Opción 1: Usando el script batch (Windows)**
```bash
cd database
APLICAR_BLOQUEO_PROGRESIVO.bat
```

**Opción 2: Manual con psql**
```bash
psql -U postgres -d ssut_gestion_documental -f database/add_bloqueos_acumulados.sql
```

**Opción 3: Manual desde pgAdmin**
1. Abrir pgAdmin
2. Conectarse a la base de datos `ssut_gestion_documental`
3. Abrir la herramienta Query Tool
4. Copiar y ejecutar el contenido de `database/add_bloqueos_acumulados.sql`

---

## 2. Protección de Comprobantes contra Descargas y Capturas

### Descripción
Se implementaron medidas de seguridad para proteger los comprobantes visualizados en el sistema, dificultando su descarga, impresión o captura de pantalla.

### Medidas Implementadas

#### 2.1 Eliminación de Opciones de Exportación
Se removieron las siguientes opciones del menú de documentos:
- ❌ Descargar documento
- ❌ Imprimir documento
- ❌ Descargar código QR
- ❌ Compartir documento

**Archivo modificado**: `frontend/lib/screens/documentos/documento_detail_screen.dart`

#### 2.2 Watermark de Seguridad
Se agregó un watermark dinámico que se superpone sobre toda la pantalla del comprobante con las siguientes características:

- **Contenido**: Nombre completo del usuario + fecha/hora actual
- **Patrón**: Diagonal repetido cada 250px horizontal y 150px vertical
- **Inclinación**: -23 grados (-0.4 radianes)
- **Opacidad**: 4% (muy sutil pero visible)
- **Color**: Negro
- **Tamaño de fuente**: 14px

**Propósito**: 
- Identificar al usuario que visualizó el documento
- Disuadir capturas de pantalla no autorizadas
- Proporcionar trazabilidad en caso de filtración

#### 2.3 Protección contra Capturas (Solo Móvil)
Se configuró `SystemChrome.setApplicationSwitcherDescription` para mostrar "Documento Protegido" en el switcher de aplicaciones.

**Nota**: En plataformas web y desktop, esta protección es limitada. La protección más efectiva es el watermark.

### Archivos Modificados
- **`frontend/lib/screens/documentos/documento_detail_screen.dart`**:
  - Eliminación del menú popup con opciones de descarga/impresión
  - Agregada clase `_SecurityWatermarkPainter` para el watermark
  - Protegido el Scaffold con Stack para superponer el watermark

---

## Consideraciones de Seguridad

### Limitaciones Conocidas

1. **Capturas de Pantalla en Desktop/Web**
   - Flutter no puede bloquear capturas de pantalla nativas del SO en Windows/Mac/Linux
   - El watermark actúa como disuasivo y mecanismo de trazabilidad

2. **Fotos con Teléfono**
   - No hay forma técnica de evitar que alguien tome foto a la pantalla
   - El watermark identifica al responsable si el documento se filtra

3. **Acceso Directo a PDFs**
   - Los archivos PDF siguen accesibles vía URL directa para usuarios con conocimiento técnico
   - Se recomienda implementar protección adicional en el backend si es crítico

### Recomendaciones Adicionales

1. **Auditoría**: Implementar logging de todas las visualizaciones de comprobantes
2. **Roles**: Restringir acceso a comprobantes solo a usuarios autorizados
3. **Expiración**: Considerar tokens temporales para acceso a documentos sensibles
4. **Cifrado**: Evaluar cifrado de PDFs en el servidor
5. **VPN**: Para acceso remoto, considerar VPN para acceso al sistema

---

## Testing

### Probar Bloqueo Progresivo

1. Ejecutar script SQL para agregar columna `bloqueos_acumulados`
2. Reiniciar backend
3. Intentar login con contraseña incorrecta 3 veces
4. Verificar bloqueo de 10 minutos
5. Esperar a que expire el bloqueo
6. Intentar login incorrecto 3 veces más
7. Verificar bloqueo de 20 minutos
8. Hacer login exitoso → contador debe resetearse

### Probar Protección de Comprobantes

1. Iniciar sesión con usuario válido
2. Navegar a un comprobante
3. Verificar que NO aparecen opciones de descarga/impresión en el menú (⋮)
4. Verificar watermark con nombre de usuario visible sobre el contenido
5. Capturar pantalla y verificar que el watermark aparece en la captura

---

## Rollback (Deshacer Cambios)

Si necesitas revertir los cambios:

### Backend
```sql
ALTER TABLE usuarios DROP COLUMN IF EXISTS bloqueos_acumulados;
```

### Frontend
- Revertir commits relacionados con `documento_detail_screen.dart` y `AuthController.cs`

---

## Contacto

Para dudas o problemas relacionados con estas mejoras, contactar al equipo de desarrollo.
