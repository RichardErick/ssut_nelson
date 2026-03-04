# DOCUMENTACIÓN TÉCNICA DEL SISTEMA
## Sistema de Información Web para la Gestión, Control y Trazabilidad Documental del SSUT

---

## 1. ARQUITECTURA DEL SISTEMA

### 1.1 Arquitectura General
El sistema está desarrollado bajo una arquitectura de tres capas:

- **Capa de Presentación (Frontend)**: Aplicación web desarrollada en Flutter
- **Capa de Lógica de Negocio (Backend)**: API REST desarrollada en ASP.NET Core 8.0 con C#
- **Capa de Datos**: Base de datos PostgreSQL

### 1.2 Patrón de Diseño
- **Frontend**: Patrón MVC (Model-View-Controller) con Provider para gestión de estado
- **Backend**: Arquitectura en capas con separación de Controllers, Services, Models y Data Access
- **Comunicación**: API RESTful con autenticación JWT (JSON Web Tokens)

---

## 2. TECNOLOGÍAS DEL BACKEND (C# / ASP.NET Core)

### 2.1 Framework Principal
- **ASP.NET Core 8.0**: Framework web de Microsoft para desarrollo de APIs REST
- **.NET 8.0**: Plataforma de desarrollo multiplataforma
- **C# 12**: Lenguaje de programación orientado a objetos

### 2.2 Librerías y Paquetes NuGet

#### 2.2.1 Entity Framework Core (ORM)
```
Microsoft.EntityFrameworkCore (v8.0.0)
Microsoft.EntityFrameworkCore.Design (v8.0.0)
Npgsql.EntityFrameworkCore.PostgreSQL (v8.0.0)
```
**Propósito**: Mapeo objeto-relacional (ORM) para interactuar con la base de datos PostgreSQL mediante código C#.

#### 2.2.2 Autenticación y Seguridad
```
Microsoft.AspNetCore.Authentication.JwtBearer (v8.0.0)
BCrypt.Net-Next (v4.0.3)
```
**Propósito**: 
- JWT Bearer: Autenticación basada en tokens JWT
- BCrypt: Encriptación segura de contraseñas con algoritmo bcrypt

#### 2.2.3 Documentación de API
```
Swashbuckle.AspNetCore (v6.5.0)
```
**Propósito**: Generación automática de documentación Swagger/OpenAPI para la API REST

#### 2.2.4 CORS (Cross-Origin Resource Sharing)
```
Microsoft.AspNetCore.Cors (v2.2.0)
```
**Propósito**: Permitir solicitudes HTTP desde el frontend Flutter hacia el backend

#### 2.2.5 Generación de Códigos QR
```
QRCoder (v1.6.0)
System.Drawing.Common (v8.0.0)
```
**Propósito**: Generación de códigos QR para trazabilidad de documentos

### 2.3 Estructura del Backend

```
backend/
├── Controllers/          # Controladores de API REST
│   ├── AuthController.cs
│   ├── DocumentosController.cs
│   ├── CarpetasController.cs
│   ├── MovimientosController.cs
│   ├── UsuariosController.cs
│   ├── PermisosController.cs
│   ├── ReportesController.cs
│   └── QRCodeController.cs
├── Models/              # Modelos de datos (entidades)
│   ├── Usuario.cs
│   ├── Documento.cs
│   ├── Carpeta.cs
│   ├── Movimiento.cs
│   ├── Permiso.cs
│   └── Area.cs
├── Services/            # Lógica de negocio
│   ├── DocumentoService.cs
│   ├── MovimientoService.cs
│   ├── ReporteService.cs
│   ├── QRCodeService.cs
│   └── EmailSender.cs
├── Data/                # Contexto de base de datos
│   └── ApplicationDbContext.cs
├── DTOs/                # Data Transfer Objects
│   ├── DocumentoDTO.cs
│   ├── MovimientoDTO.cs
│   └── ReporteDTO.cs
└── Program.cs           # Configuración principal
```

---

## 3. TECNOLOGÍAS DEL FRONTEND (Flutter/Dart)

### 3.1 Framework Principal
- **Flutter 3.7.2**: Framework de Google para desarrollo de aplicaciones multiplataforma
- **Dart 3.7.2**: Lenguaje de programación optimizado para UI

### 3.2 Librerías y Paquetes Pub

#### 3.2.1 Interfaz de Usuario
```yaml
google_fonts: ^6.1.0
cupertino_icons: ^1.0.8
```
**Propósito**: 
- Google Fonts: Tipografías personalizadas (Poppins, Inter)
- Cupertino Icons: Iconos estilo iOS

#### 3.2.2 Comunicación HTTP y API
```yaml
http: ^1.1.0
dio: ^5.4.0
```
**Propósito**: 
- HTTP: Cliente HTTP básico
- Dio: Cliente HTTP avanzado con interceptores, manejo de errores y timeouts

#### 3.2.3 Gestión de Estado
```yaml
provider: ^6.1.1
```
**Propósito**: Patrón de gestión de estado recomendado por Flutter para compartir datos entre widgets

#### 3.2.4 Almacenamiento Local
```yaml
shared_preferences: ^2.2.2
flutter_secure_storage: ^9.0.0
```
**Propósito**: 
- SharedPreferences: Almacenamiento de preferencias simples
- SecureStorage: Almacenamiento seguro de tokens JWT y datos sensibles

#### 3.2.5 Códigos QR
```yaml
qr_flutter: ^4.1.0
mobile_scanner: ^3.5.0
zxing2: ^0.2.4
```
**Propósito**: 
- QR Flutter: Generación de códigos QR
- Mobile Scanner: Escaneo de códigos QR con cámara
- ZXing2: Librería de procesamiento de códigos de barras y QR

#### 3.2.6 Formularios y Validación
```yaml
flutter_form_builder: ^10.2.0
form_builder_validators: ^11.1.2
```
**Propósito**: Construcción de formularios complejos con validaciones integradas

#### 3.2.7 Internacionalización y Fechas
```yaml
intl: ^0.20.2
flutter_localizations: sdk
```
**Propósito**: Formateo de fechas, números y soporte multiidioma

#### 3.2.8 Generación de PDF y Reportes
```yaml
pdf: ^3.10.7
printing: ^5.12.0
pdfx: ^2.6.0
```
**Propósito**: 
- PDF: Generación de documentos PDF
- Printing: Impresión de documentos
- PDFx: Visualización de archivos PDF

#### 3.2.9 Manejo de Archivos
```yaml
path_provider: ^2.1.1
image_picker: ^1.0.5
file_picker: ^8.1.0
image: ^4.2.0
universal_html: ^2.2.4
```
**Propósito**: 
- Path Provider: Acceso a directorios del sistema
- Image Picker: Selección de imágenes desde galería/cámara
- File Picker: Selección de archivos del sistema
- Image: Procesamiento de imágenes
- Universal HTML: Compatibilidad web

### 3.3 Estructura del Frontend

```
frontend/lib/
├── main.dart                    # Punto de entrada
├── models/                      # Modelos de datos
│   ├── usuario.dart
│   ├── documento.dart
│   ├── carpeta.dart
│   ├── movimiento.dart
│   └── permiso.dart
├── providers/                   # Gestión de estado
│   ├── auth_provider.dart
│   ├── data_provider.dart
│   └── theme_provider.dart
├── services/                    # Servicios de API
│   ├── api_service.dart
│   ├── documento_service.dart
│   ├── carpeta_service.dart
│   ├── movimiento_service.dart
│   ├── usuario_service.dart
│   └── reporte_service.dart
├── screens/                     # Pantallas de la aplicación
│   ├── login_screen.dart
│   ├── home_screen.dart
│   ├── documentos/
│   ├── movimientos/
│   ├── admin/
│   └── reportes/
├── widgets/                     # Componentes reutilizables
│   ├── sidebar.dart
│   ├── app_alert.dart
│   ├── loading_shimmer.dart
│   └── empty_state.dart
├── theme/                       # Tema de la aplicación
│   └── app_theme.dart
└── utils/                       # Utilidades
    ├── error_helper.dart
    └── form_validators.dart
```

---

## 4. BASE DE DATOS (PostgreSQL)

### 4.1 Sistema Gestor de Base de Datos
- **PostgreSQL 14+**: Sistema de gestión de bases de datos relacional de código abierto

### 4.2 Características Utilizadas
- **Tipos de datos avanzados**: JSON, Arrays, UUID
- **Índices**: B-tree para optimización de consultas
- **Constraints**: Primary Keys, Foreign Keys, Unique, Check
- **Triggers**: Para auditoría automática
- **Funciones**: Procedimientos almacenados para lógica compleja

### 4.3 Estructura de Tablas Principales

#### 4.3.1 Tabla: usuarios
```sql
- id (SERIAL PRIMARY KEY)
- nombre_usuario (VARCHAR UNIQUE)
- nombre_completo (VARCHAR)
- email (VARCHAR UNIQUE)
- password_hash (VARCHAR)
- rol (VARCHAR)
- area_id (INTEGER FK)
- activo (BOOLEAN)
- solicitud_rechazada (BOOLEAN)
- pregunta_secreta (VARCHAR)
- respuesta_secreta_hash (VARCHAR)
- fecha_registro (TIMESTAMP)
```

#### 4.3.2 Tabla: carpetas
```sql
- id (SERIAL PRIMARY KEY)
- nombre (VARCHAR)
- codigo (VARCHAR)
- tipo (VARCHAR)
- gestion (VARCHAR)
- rango_inicio (INTEGER)
- rango_fin (INTEGER)
- carpeta_padre_id (INTEGER FK)
- fecha_creacion (TIMESTAMP)
- activo (BOOLEAN)
```

#### 4.3.3 Tabla: documentos
```sql
- id (SERIAL PRIMARY KEY)
- codigo (VARCHAR UNIQUE)
- numero_correlativo (VARCHAR)
- tipo_documento_id (INTEGER FK)
- carpeta_id (INTEGER FK)
- gestion (VARCHAR)
- fecha_documento (DATE)
- descripcion (TEXT)
- responsable_id (INTEGER FK)
- codigo_qr (VARCHAR)
- ubicacion_fisica (VARCHAR)
- estado (VARCHAR)
- archivo_pdf_path (VARCHAR)
- fecha_registro (TIMESTAMP)
```

#### 4.3.4 Tabla: movimientos
```sql
- id (SERIAL PRIMARY KEY)
- documento_id (INTEGER FK)
- tipo_movimiento (VARCHAR)
- usuario_solicitante_id (INTEGER FK)
- usuario_autorizador_id (INTEGER FK)
- fecha_prestamo (TIMESTAMP)
- fecha_limite_devolucion (DATE)
- fecha_devolucion (TIMESTAMP)
- observaciones (TEXT)
- estado (VARCHAR)
```

#### 4.3.5 Tabla: permisos
```sql
- id (SERIAL PRIMARY KEY)
- nombre (VARCHAR UNIQUE)
- descripcion (TEXT)
- categoria (VARCHAR)
```

#### 4.3.6 Tabla: usuario_permisos
```sql
- id (SERIAL PRIMARY KEY)
- usuario_id (INTEGER FK)
- permiso_id (INTEGER FK)
- denegado (BOOLEAN)
```

#### 4.3.7 Tabla: alertas
```sql
- id (SERIAL PRIMARY KEY)
- usuario_id (INTEGER FK)
- tipo_alerta (VARCHAR)
- titulo (VARCHAR)
- mensaje (TEXT)
- movimiento_id (INTEGER FK)
- leida (BOOLEAN)
- fecha_creacion (TIMESTAMP)
```

#### 4.3.8 Tabla: auditoria
```sql
- id (SERIAL PRIMARY KEY)
- usuario_id (INTEGER FK)
- accion (VARCHAR)
- tabla_afectada (VARCHAR)
- registro_id (INTEGER)
- detalles (TEXT)
- fecha (TIMESTAMP)
```

### 4.4 Índices para Optimización
```sql
- idx_documentos_codigo
- idx_documentos_gestion_correlativo
- idx_documentos_carpeta
- idx_documentos_qr
- idx_movimientos_documento
- idx_movimientos_usuario
- idx_alertas_usuario_leida
- idx_auditoria_usuario_fecha
```

---

## 5. HERRAMIENTAS DE DESARROLLO

### 5.1 Entornos de Desarrollo Integrado (IDE)
- **Visual Studio Code**: Editor principal para Flutter/Dart
- **Visual Studio 2022**: IDE para desarrollo C#/.NET
- **JetBrains Rider**: IDE alternativo para .NET (opcional)

### 5.2 Control de Versiones
- **Git**: Sistema de control de versiones
- **GitHub**: Plataforma de alojamiento de código

### 5.3 Herramientas de Base de Datos
- **pgAdmin 4**: Administrador gráfico de PostgreSQL
- **DBeaver**: Cliente universal de bases de datos
- **Azure Data Studio**: Cliente multiplataforma (opcional)

### 5.4 Herramientas de Testing
- **Postman**: Testing de API REST
- **Swagger UI**: Documentación interactiva de API
- **Flutter DevTools**: Herramientas de depuración para Flutter

### 5.5 Gestión de Dependencias
- **NuGet**: Gestor de paquetes para .NET
- **Pub**: Gestor de paquetes para Flutter/Dart
- **npm**: Para herramientas auxiliares (opcional)

---

## 6. FUNCIONALIDADES PRINCIPALES DEL SISTEMA

### 6.1 Módulo de Autenticación
- Login con usuario y contraseña
- Autenticación JWT con tokens de acceso
- Recuperación de contraseña por pregunta secreta
- Recuperación de contraseña por administrador
- Detección de contraseñas débiles
- Registro de nuevos usuarios con aprobación

### 6.2 Módulo de Gestión Documental
- Creación de carpetas jerárquicas (Comprobantes de Ingreso/Egreso)
- Registro de documentos con metadatos
- Carga de archivos PDF
- Generación automática de códigos QR
- Búsqueda avanzada de documentos
- Filtros por fecha, tipo, carpeta, responsable
- Visualización de documentos PDF

### 6.3 Módulo de Movimientos (Préstamos)
- Solicitud de préstamo de documentos
- Aprobación/rechazo de préstamos
- Registro de devoluciones
- Alertas de vencimiento de préstamos
- Historial de movimientos por documento
- Mis préstamos activos

### 6.4 Módulo de Administración
- Gestión de usuarios (CRUD)
- Asignación de roles y permisos
- Aprobación de solicitudes de registro
- Restablecimiento de contraseñas
- Gestión de áreas
- Gestión de tipos de documento

### 6.5 Módulo de Reportes
- Reporte de documentos por carpeta
- Reporte de movimientos por período
- Reporte de préstamos activos
- Reporte de documentos por responsable
- Exportación a PDF

### 6.6 Módulo de Auditoría
- Registro automático de acciones
- Historial de cambios en documentos
- Trazabilidad completa de operaciones
- Consulta de auditoría por usuario/fecha

### 6.7 Módulo de Notificaciones
- Centro de notificaciones
- Alertas de préstamos vencidos
- Notificaciones de solicitudes pendientes
- Alertas de pregunta secreta no configurada
- Notificaciones de recuperación de contraseña

---

## 7. SEGURIDAD IMPLEMENTADA

### 7.1 Autenticación y Autorización
- **JWT (JSON Web Tokens)**: Tokens firmados con clave secreta
- **BCrypt**: Hash de contraseñas con salt automático
- **Roles y Permisos**: Sistema RBAC (Role-Based Access Control)
- **Permisos granulares**: Control a nivel de funcionalidad

### 7.2 Validaciones
- **Frontend**: Validación de formularios con flutter_form_builder
- **Backend**: Validación de DTOs con Data Annotations
- **Base de datos**: Constraints y triggers

### 7.3 Protección de Datos
- **HTTPS**: Comunicación encriptada (recomendado en producción)
- **CORS**: Configuración restrictiva de orígenes permitidos
- **SQL Injection**: Prevención mediante Entity Framework (queries parametrizadas)
- **XSS**: Sanitización de inputs en frontend

### 7.4 Almacenamiento Seguro
- **Flutter Secure Storage**: Almacenamiento encriptado de tokens
- **Contraseñas**: Nunca se almacenan en texto plano
- **Archivos**: Almacenamiento en servidor con rutas protegidas

---

## 8. REQUISITOS DEL SISTEMA

### 8.1 Servidor (Backend)
- **Sistema Operativo**: Windows Server 2016+, Linux (Ubuntu 20.04+), macOS
- **Runtime**: .NET 8.0 Runtime
- **Memoria RAM**: Mínimo 2 GB, recomendado 4 GB
- **Espacio en Disco**: Mínimo 500 MB para aplicación + espacio para archivos
- **Puerto**: 5000 (HTTP) o 5001 (HTTPS)

### 8.2 Base de Datos
- **PostgreSQL**: Versión 14 o superior
- **Memoria RAM**: Mínimo 1 GB dedicado
- **Espacio en Disco**: Mínimo 1 GB + crecimiento según volumen de datos
- **Puerto**: 5432 (predeterminado)

### 8.3 Cliente (Frontend Web)
- **Navegadores Soportados**:
  - Google Chrome 90+
  - Mozilla Firefox 88+
  - Microsoft Edge 90+
  - Safari 14+
- **Resolución**: Mínimo 1280x720, recomendado 1920x1080
- **Conexión a Internet**: Requerida para acceso al backend

### 8.4 Desarrollo
- **Flutter SDK**: 3.7.2 o superior
- **.NET SDK**: 8.0 o superior
- **PostgreSQL**: 14 o superior
- **Git**: 2.30 o superior

---

## 9. CONFIGURACIÓN Y DESPLIEGUE

### 9.1 Variables de Entorno (Backend)
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Database=ssut_gestion;Username=postgres;Password=****"
  },
  "Jwt": {
    "Key": "clave-secreta-jwt-minimo-32-caracteres",
    "Issuer": "SSUT-Backend",
    "Audience": "SSUT-Frontend"
  },
  "AllowedOrigins": ["http://localhost:8080"]
}
```

### 9.2 Configuración Frontend
```dart
// lib/services/api_service.dart
static const String baseUrl = 'http://localhost:5000/api';
```

### 9.3 Scripts de Despliegue
- **Backend**: `dotnet publish -c Release`
- **Frontend**: `flutter build web --release`
- **Base de datos**: Scripts SQL en carpeta `database/`

---

## 10. MANTENIMIENTO Y SOPORTE

### 10.1 Logs del Sistema
- **Backend**: Logs en consola y archivo (opcional con Serilog)
- **Frontend**: Logs en consola del navegador
- **Base de datos**: Logs de PostgreSQL en `/var/log/postgresql/`

### 10.2 Backups
- **Base de datos**: `pg_dump` diario recomendado
- **Archivos**: Backup de carpeta `uploads/`
- **Configuración**: Backup de archivos `appsettings.json`

### 10.3 Actualizaciones
- **Backend**: Actualización de paquetes NuGet
- **Frontend**: Actualización de paquetes Pub
- **Base de datos**: Migraciones con Entity Framework

---

## 11. CONTACTO Y SOPORTE TÉCNICO

**Desarrollador**: [Tu Nombre]
**Institución**: SSUT (Servicio Social Universitario de Trabajo)
**Email**: [tu-email@ssut.edu.bo]
**Versión del Sistema**: 1.0.0
**Fecha de Documentación**: Marzo 2026

---

## ANEXOS

### A. Comandos Útiles

#### Backend
```bash
# Restaurar paquetes
dotnet restore

# Compilar
dotnet build

# Ejecutar
dotnet run

# Crear migración
dotnet ef migrations add NombreMigracion

# Aplicar migraciones
dotnet ef database update
```

#### Frontend
```bash
# Obtener dependencias
flutter pub get

# Ejecutar en Chrome
flutter run -d chrome

# Compilar para web
flutter build web

# Limpiar cache
flutter clean
```

#### Base de Datos
```bash
# Conectar a PostgreSQL
psql -U postgres -d ssut_gestion

# Backup
pg_dump -U postgres ssut_gestion > backup.sql

# Restaurar
psql -U postgres ssut_gestion < backup.sql
```

---

**FIN DEL DOCUMENTO**
