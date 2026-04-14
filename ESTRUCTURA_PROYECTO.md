# Estructura del Proyecto - Sistema de Gestión Documental SSUT

## Descripción General

Sistema de información web desarrollado con arquitectura MVC para la gestión, control y trazabilidad documental del Seguro Social Universitario de Tarija.

## Arquitectura

- **Backend**: ASP.NET Core 8.0 (C#) con API RESTful
- **Frontend**: Flutter (Web y Móvil)
- **Base de Datos**: PostgreSQL 14+
- **Metodología**: Scrum

## Estructura de Directorios

```
Sistema_info_web_gestion/
├── backend/                          # Backend ASP.NET Core
│   ├── Controllers/                 # Controladores API RESTful
│   │   ├── DocumentosController.cs
│   │   ├── MovimientosController.cs
│   │   ├── ReportesController.cs
│   │   ├── QRCodeController.cs
│   │   ├── AreasController.cs
│   │   └── TiposDocumentoController.cs
│   ├── Data/                        # Contexto de base de datos
│   │   └── ApplicationDbContext.cs
│   ├── DTOs/                        # Objetos de transferencia de datos
│   │   ├── DocumentoDTO.cs
│   │   ├── MovimientoDTO.cs
│   │   └── ReporteDTO.cs
│   ├── Models/                      # Entidades del dominio
│   │   ├── Documento.cs
│   │   ├── Movimiento.cs
│   │   ├── Usuario.cs
│   │   ├── Area.cs
│   │   └── TipoDocumento.cs
│   ├── Services/                    # Lógica de negocio
│   │   ├── IDocumentoService.cs
│   │   ├── DocumentoService.cs
│   │   ├── IMovimientoService.cs
│   │   ├── MovimientoService.cs
│   │   ├── IQRCodeService.cs
│   │   ├── QRCodeService.cs
│   │   ├── IReporteService.cs
│   │   └── ReporteService.cs
│   ├── Program.cs                   # Punto de entrada
│   ├── appsettings.json             # Configuración
│   └── SistemaGestionDocumental.csproj
│
├── frontend/                        # Frontend Flutter
│   ├── lib/
│   │   ├── main.dart                # Punto de entrada
│   │   ├── models/                  # Modelos de datos
│   │   │   ├── documento.dart
│   │   │   └── movimiento.dart
│   │   ├── services/                # Servicios de API
│   │   │   ├── api_service.dart
│   │   │   ├── documento_service.dart
│   │   │   ├── movimiento_service.dart
│   │   │   └── reporte_service.dart
│   │   ├── providers/               # Gestión de estado
│   │   │   └── auth_provider.dart
│   │   └── screens/                 # Pantallas de la aplicación
│   │       ├── login_screen.dart
│   │       ├── home_screen.dart
│   │       ├── documentos/
│   │       │   ├── documentos_list_screen.dart
│   │       │   ├── documento_search_screen.dart
│   │       │   └── documento_detail_screen.dart
│   │       ├── movimientos/
│   │       │   └── movimientos_screen.dart
│   │       ├── reportes/
│   │       │   └── reportes_screen.dart
│   │       └── qr/
│   │           └── qr_scanner_screen.dart
│   └── pubspec.yaml                 # Dependencias Flutter
│
├── database/                        # Scripts SQL
│   ├── schema.sql                   # Esquema de base de datos
│   ├── seed_data.sql                # Datos iniciales
│   └── README.md
│
├── README.md                        # Documentación principal
├── INSTALLATION.md                  # Guía de instalación
└── PROJECT_STRUCTURE.md            # Este archivo

```

## Funcionalidades Implementadas

### Backend (API RESTful)

1. **Gestión de Documentos**
   - CRUD completo de documentos
   - Búsqueda avanzada con múltiples filtros
   - Generación automática de códigos únicos
   - Generación de códigos QR

2. **Gestión de Movimientos**
   - Registro de entrada, salida y derivación
   - Historial completo de movimientos por documento
   - Devolución de documentos

3. **Reportes y Estadísticas**
   - Reportes de movimientos por fecha y área
   - Reportes de documentos por gestión y tipo
   - Estadísticas generales del sistema

4. **Códigos QR**
   - Generación de códigos QR para documentos
   - Endpoint para obtener imagen QR

### Frontend (Flutter)

1. **Autenticación**
   - Pantalla de login (simulada, requiere implementación real)

2. **Gestión de Documentos**
   - Lista de documentos
   - Búsqueda simple y avanzada
   - Detalle de documento con historial
   - Visualización de código QR

3. **Movimientos**
   - Lista de movimientos
   - Devolución de documentos desde la interfaz

4. **Reportes**
   - Estadísticas generales
   - Visualización de datos por tipo y área

5. **Escáner QR**
   - Escaneo de códigos QR para búsqueda rápida
   - Integración con cámara del dispositivo

## Endpoints del API

### Documentos
- `GET /api/documentos` - Listar todos los documentos
- `GET /api/documentos/{id}` - Obtener documento por ID
- `GET /api/documentos/codigo/{codigo}` - Obtener por código
- `GET /api/documentos/qr/{codigoQR}` - Obtener por código QR
- `POST /api/documentos/buscar` - Búsqueda avanzada
- `POST /api/documentos` - Crear documento
- `PUT /api/documentos/{id}` - Actualizar documento
- `DELETE /api/documentos/{id}` - Eliminar documento

### Movimientos
- `GET /api/movimientos` - Listar movimientos
- `GET /api/movimientos/{id}` - Obtener movimiento por ID
- `GET /api/movimientos/documento/{documentoId}` - Movimientos de un documento
- `GET /api/movimientos/fecha` - Movimientos por rango de fechas
- `POST /api/movimientos` - Crear movimiento
- `POST /api/movimientos/devolver` - Devolver documento

### Reportes
- `POST /api/reportes/movimientos` - Reporte de movimientos
- `POST /api/reportes/documentos` - Reporte de documentos
- `GET /api/reportes/estadisticas` - Estadísticas generales

### QR Code
- `GET /api/qrcode/imagen/{codigoDocumento}` - Generar imagen QR

### Catálogos
- `GET /api/areas` - Listar áreas
- `GET /api/tiposdocumento` - Listar tipos de documento

## Base de Datos

### Tablas Principales

1. **documentos**: Almacena información de documentos con metadatos
2. **movimientos**: Registra todos los movimientos de documentos
3. **usuarios**: Usuarios del sistema
4. **areas**: Áreas de la institución
5. **tipos_documento**: Tipos de documentos (comprobantes, memorándums, etc.)

### Relaciones

- Documento → TipoDocumento (Muchos a Uno)
- Documento → Area (Muchos a Uno)
- Documento → Usuario/Responsable (Muchos a Uno)
- Movimiento → Documento (Muchos a Uno)
- Movimiento → Area Origen/Destino (Muchos a Uno)
- Movimiento → Usuario (Muchos a Uno)

## Próximos Pasos de Desarrollo

1. **Autenticación Real**
   - Implementar JWT o similar
   - Sistema de roles y permisos

2. **Funcionalidades Adicionales**
   - Registro de nuevo documento desde Flutter
   - Edición de documentos
   - Generación de reportes PDF
   - Exportación de datos

3. **Mejoras**
   - Validaciones adicionales
   - Manejo de errores mejorado
   - Logging y auditoría
   - Optimizaciones de rendimiento

4. **Testing**
   - Unit tests
   - Integration tests
   - UI tests

## Notas Técnicas

- El backend utiliza Entity Framework Core con PostgreSQL
- El frontend utiliza Provider para gestión de estado
- Los códigos QR se generan usando la librería QRCoder
- El escáner QR utiliza mobile_scanner para Flutter
- CORS está configurado para permitir comunicación entre frontend y backend

