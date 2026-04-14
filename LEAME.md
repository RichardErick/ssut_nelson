# Sistema de Información Web para la Gestión, Control y Trazabilidad Documental

## Seguro Social Universitario de Tarija (SSUT)

Sistema web desarrollado para optimizar la gestión documental del Seguro Social Universitario de Tarija, permitiendo la clasificación estructurada, localización eficiente y registro sistemático de movimientos de documentos físicos.

**Universidad Domingo Savio** | **Año 2025-2026**

---

## 🚀 Características Principales

### 📁 Gestión Documental
- Registro y clasificación de documentos con metadatos completos
- Organización jerárquica con carpetas y subcarpetas
- Numeración automática e independiente por tipo (Ingreso/Egreso)
- Códigos QR para identificación rápida
- Búsqueda avanzada con múltiples filtros

### 📊 Sistema de Reportes Personalizados
- Generación de reportes con columnas personalizables (13 columnas disponibles)
- Filtros avanzados: texto, estado, tipo, área, rango de fechas
- Ordenamiento dinámico en todas las columnas
- Configuraciones rápidas predefinidas (Básica, Completa, Ubicación, Temporal)
- Exportación a PDF (landscape) y Excel/CSV
- Interfaz moderna con feedback visual

### 🔄 Control de Movimientos
- Registro de préstamos y devoluciones
- Trazabilidad completa de documentos
- Alertas automáticas de vencimiento
- Historial detallado de movimientos
- Validación de permisos por rol

### 👥 Gestión de Usuarios y Permisos
- Sistema de roles (Admin Sistema, Admin Documentos, Contador, Gerente)
- Permisos granulares por usuario
- Autenticación segura con JWT
- Recuperación de contraseña con pregunta secreta

---

## 🛠️ Tecnologías

### Backend
- **Framework**: ASP.NET Core 8.0 (C#)
- **Arquitectura**: MVC + Repository Pattern
- **Base de Datos**: PostgreSQL 14+
- **ORM**: Entity Framework Core
- **Autenticación**: JWT Bearer Tokens

### Frontend
- **Framework**: Flutter 3.0+ (Web y Móvil)
- **Arquitectura**: Provider Pattern (State Management)
- **UI**: Material Design 3
- **Gráficos**: fl_chart
- **Exportación**: pdf, csv

### DevOps
- **Control de Versiones**: Git + GitHub
- **Metodología**: Scrum
- **Documentación**: Markdown

---

## 📂 Estructura del Proyecto

```
Sistema_info_web_gestion/
├── backend/                    # API RESTful en ASP.NET Core
│   ├── Controllers/           # Controladores de API
│   ├── Models/                # Modelos de datos
│   ├── Services/              # Lógica de negocio
│   ├── Data/                  # Contexto de base de datos
│   └── Migrations/            # Migraciones de EF Core
│
├── frontend/                   # Aplicación Flutter
│   ├── lib/
│   │   ├── models/           # Modelos de datos
│   │   ├── providers/        # State management
│   │   ├── screens/          # Pantallas de la app
│   │   ├── services/         # Servicios de API
│   │   ├── widgets/          # Componentes reutilizables
│   │   └── theme/            # Temas y estilos
│   └── pubspec.yaml          # Dependencias Flutter
│
├── database/                   # Scripts SQL
│   └── scripts/              # Scripts de inicialización
│
└── docs/                       # Documentación
    ├── INSTALLATION.md        # Guía de instalación
    ├── ARRANQUE.md           # Instrucciones de arranque
    └── *.md                  # Documentación técnica
```

---

## 🚀 Instalación y Configuración

### Requisitos Previos
- .NET 8.0 SDK
- Flutter SDK 3.0+
- PostgreSQL 14+
- Visual Studio 2022 o VS Code
- Git

### Instalación Rápida

1. **Clonar el repositorio**
```bash
git clone https://github.com/RichardErick/ssut_nelson.git
cd Sistema_info_web_gestion
```

2. **Configurar Backend**
```bash
cd backend
dotnet restore
dotnet ef database update
dotnet run
```

3. **Configurar Frontend**
```bash
cd frontend
flutter pub get
flutter run -d chrome
```

Para instrucciones detalladas, ver [INSTALLATION.md](INSTALLATION.md) y [ARRANQUE.md](ARRANQUE.md).

---

## 📚 Documentación

### Documentación Principal
- [INSTALLATION.md](INSTALLATION.md) - Guía completa de instalación
- [ARRANQUE.md](ARRANQUE.md) - Instrucciones de arranque del sistema
- [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) - Estructura detallada del proyecto
- [DOCUMENTACION_TECNICA_SISTEMA.md](DOCUMENTACION_TECNICA_SISTEMA.md) - Documentación técnica completa

### Documentación de Funcionalidades
- [RESUMEN_COMPLETO_MEJORAS_REPORTES.md](RESUMEN_COMPLETO_MEJORAS_REPORTES.md) - Sistema de reportes personalizados
- [SOLUCION_EXPORTACION_REPORTES.md](SOLUCION_EXPORTACION_REPORTES.md) - Exportación a PDF y Excel
- [SOLUCION_NUMERACION_INDEPENDIENTE_CARPETAS.md](SOLUCION_NUMERACION_INDEPENDIENTE_CARPETAS.md) - Numeración de carpetas

### Documentación de Sprints
- [CAMBIOS_SPRINT_MARZO_2026.md](CAMBIOS_SPRINT_MARZO_2026.md) - Cambios del sprint actual
- [VERIFICACION_SPRINT1_Y_SPRINT2.md](VERIFICACION_SPRINT1_Y_SPRINT2.md) - Verificación de sprints anteriores
- [RESUMEN_SESION_MARZO_2026.md](RESUMEN_SESION_MARZO_2026.md) - Resumen de la última sesión

---

## 🎯 Funcionalidades Destacadas

### Sistema de Reportes Personalizados
- 13 columnas seleccionables
- 5 tipos de filtros avanzados
- Ordenamiento en todas las columnas
- 4 configuraciones rápidas predefinidas
- Exportación funcional a PDF y Excel

### Numeración Inteligente de Carpetas
- Numeración independiente por tipo (Ingreso/Egreso)
- Cada tipo mantiene su propia secuencia
- Códigos romanos automáticos

### Control de Acceso Granular
- Permisos por usuario y por rol
- Validación en frontend y backend
- Auditoría de acciones

---

## 👥 Equipo

**Desarrollador**: Nelson Brayan Cortez Soliz  
**Tutor**: Ing. Yanet Colque Alarcon  
**Institución**: Universidad Domingo Savio  
**Cliente**: Seguro Social Universitario de Tarija (SSUT)

---

## 📝 Licencia

Este proyecto es propiedad de la Universidad Domingo Savio y el Seguro Social Universitario de Tarija.

---

## 🔗 Enlaces

- **Repositorio**: https://github.com/RichardErick/ssut_nelson.git
- **Documentación**: Ver carpeta `docs/`
- **Issues**: GitHub Issues

---

## 📊 Estado del Proyecto

**Versión Actual**: 1.0.0  
**Última Actualización**: Marzo 2026  
**Estado**: ✅ En Desarrollo Activo

### Últimas Mejoras
- ✅ Sistema de reportes personalizados completo
- ✅ Exportación a PDF y Excel funcional
- ✅ Numeración independiente de carpetas por tipo
- ✅ Documentación limpia y organizada

---

**¡Sistema listo para uso en producción!** 🚀✨
