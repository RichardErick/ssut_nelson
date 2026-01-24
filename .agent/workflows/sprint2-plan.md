---
description: Plan de implementación Sprint 2 - Gestión Documental
---

# Sprint 2: Gestión Documental Básica
**Meta:** Entregar funcionalidades críticas (02/01/2026 – 06/01/2026)

## Problema Actual: Borrado de Usuarios
**Estado:** Los usuarios "eliminados" reaparecen porque se muestran todos (activos e inactivos)

### Solución:
1. Modificar `UsuariosController.GetAll()` para filtrar solo usuarios activos por defecto
2. Agregar parámetro opcional `?incluirInactivos=true` para administradores
3. Actualizar frontend para mostrar solo usuarios activos

---

## Tareas del Sprint 2

### T2.1 - Diseñar esquema de datos y migraciones (2 hrs)
**Responsable:** Nelson B. Cortez Soliz
**Estado:** Pendiente

#### Acciones:
- [x] Revisar tabla `documentos` existente en schema.sql
- [ ] Agregar campos faltantes para metadatos completos
- [ ] Crear tablas para clasificación (carpetas, subcarpetas)
- [ ] Crear índices para búsqueda optimizada
- [ ] Migración para estructura de carpetas

#### Campos necesarios en `documentos`:
```sql
- id_documento (único, generado automáticamente)
- palabras_clave (array o tabla relacionada)
- carpeta_id (FK a tabla carpetas)
- subcarpeta_id (FK a tabla subcarpetas)
- gestion (año)
```

---

### T2.2 - Implementar API y modelos CRUD para Documentos (6 hrs)
**Responsable:** Nelson B. Cortez Soliz
**Estado:** Pendiente

#### Acciones:
- [ ] Crear `DocumentosController.cs` con endpoints CRUD
- [ ] Implementar validaciones de negocio
- [ ] Generar `id_documento` único automáticamente
- [ ] Implementar DTOs para crear/actualizar documentos
- [ ] Agregar auditoría de cambios

#### Endpoints necesarios:
```
GET    /api/documentos              - Listar con paginación
GET    /api/documentos/{id}         - Obtener por ID
POST   /api/documentos              - Crear documento
PUT    /api/documentos/{id}         - Actualizar documento
DELETE /api/documentos/{id}         - Eliminar (lógico)
GET    /api/documentos/search       - Búsqueda avanzada
```

---

### T2.3 - Interfaz frontend para registro y edición (2 hrs)
**Responsable:** Nelson B. Cortez Soliz
**Estado:** Pendiente

#### Acciones:
- [ ] Crear `documento_form_screen.dart`
- [ ] Implementar validaciones del lado del cliente
- [ ] Formulario con campos: tipo, área, gestión, descripción, responsable
- [ ] Selector de carpetas/subcarpetas
- [ ] Campo de palabras clave (tags)

---

### T2.4 - Implementar generador de QR (5 hrs)
**Responsable:** Nelson B. Cortez Soliz
**Estado:** Pendiente

#### Acciones:
- [ ] Instalar librería QR en backend (QRCoder o similar)
- [ ] Crear servicio `QRService.cs`
- [ ] Endpoint para generar QR: `POST /api/documentos/{id}/qr`
- [ ] QR debe apuntar a URL: `{baseUrl}/documentos/ficha/{id_documento}`
- [ ] Almacenar código QR en campo `codigo_qr`
- [ ] Opción de descargar QR como imagen PNG

---

### T2.5 - Endpoint seguro para resolver QR (3 hrs)
**Responsable:** Nelson B. Cortez Soliz
**Estado:** Pendiente

#### Acciones:
- [ ] Crear endpoint público: `GET /api/documentos/ficha/{id_documento}`
- [ ] Validar permisos de usuario (si está autenticado)
- [ ] Retornar ficha documental completa
- [ ] Manejo de errores: 404 (no existe), 403 (sin permisos)
- [ ] Registrar acceso en auditoría

---

### T2.6 - Implementar clasificación (5 hrs)
**Responsable:** Nelson B. Cortez Soliz
**Estado:** Pendiente

#### Acciones:
- [ ] Crear tablas: `carpetas`, `subcarpetas`
- [ ] Modelo jerárquico: Gestión → Carpeta → Subcarpeta
- [ ] CRUD de carpetas en backend
- [ ] UI para crear/editar carpetas
- [ ] Asignar documentos a carpetas
- [ ] Vista de árbol de carpetas en frontend

#### Estructura de carpetas:
```
Gestión 2026
├── Comprobantes
│   ├── Ingresos
│   └── Egresos
├── Correspondencia
│   ├── Oficios
│   └── Memorándums
└── Resoluciones
```

---

### T2.7 - Mover documentos en lote (3 hrs)
**Responsable:** Nelson B. Cortez Soliz
**Estado:** Pendiente

#### Acciones:
- [ ] Endpoint: `POST /api/documentos/mover-lote`
- [ ] Recibir array de IDs de documentos
- [ ] Carpeta/subcarpeta destino
- [ ] Validar permisos del usuario
- [ ] Registrar en `historial_documento` cada movimiento
- [ ] Auditoría: quién, cuándo, de dónde a dónde

---

### T2.8 - Búsqueda avanzada backend (6 hrs)
**Responsable:** Nelson B. Cortez Soliz
**Estado:** Pendiente

#### Acciones:
- [ ] Endpoint: `GET /api/documentos/buscar`
- [ ] Filtros combinables:
  - `tipo_documento_id`
  - `fecha_desde` / `fecha_hasta`
  - `responsable_id`
  - `gestion`
  - `palabras_clave`
  - `area_origen_id`
  - `carpeta_id`
  - `estado`
- [ ] Paginación: `page`, `pageSize`
- [ ] Ordenamiento: `orderBy`, `orderDirection`
- [ ] Filtrar por permisos de usuario (solo documentos que puede ver)
- [ ] Retornar metadatos: total de resultados, páginas

---

### T2.9 - Frontend búsqueda avanzada (2 hrs)
**Responsable:** Nelson B. Cortez Soliz
**Estado:** Pendiente

#### Acciones:
- [ ] Crear `busqueda_documentos_screen.dart`
- [ ] UI de filtros con chips/dropdowns
- [ ] Paginación con botones anterior/siguiente
- [ ] Mostrar resultados en tabla/lista
- [ ] Respetar permisos de usuario
- [ ] Exportar resultados (opcional)
- [ ] Pruebas funcionales de combinaciones

---

## Orden de Implementación Recomendado

### Día 1 (02/01/2026): Base de Datos y Backend Core
1. **Arreglar problema de usuarios** (30 min)
2. **T2.1** - Esquema de datos (2 hrs)
3. **T2.2** - API CRUD Documentos (6 hrs)

### Día 2 (03/01/2026): QR y Frontend Básico
1. **T2.3** - Interfaz formulario (2 hrs)
2. **T2.4** - Generador QR (5 hrs)
3. **T2.5** - Endpoint ficha documental (3 hrs)

### Día 3 (04/01/2026): Clasificación
1. **T2.6** - Sistema de carpetas (5 hrs)
2. **T2.7** - Movimiento en lote (3 hrs)

### Día 4-5 (05-06/01/2026): Búsqueda Avanzada
1. **T2.8** - Backend búsqueda (6 hrs)
2. **T2.9** - Frontend búsqueda (2 hrs)
3. **Pruebas integrales** (4 hrs)

---

## Notas Importantes

### Permisos de Usuario
- **Administrador**: Acceso total
- **AdministradorDocumentos**: CRUD de documentos, mover, clasificar
- **Usuario**: Solo lectura de documentos de su área

### Auditoría
Registrar en tabla `auditoria`:
- Creación de documentos
- Modificación de documentos
- Movimiento de documentos
- Acceso a fichas documentales vía QR
- Eliminación de documentos

### Validaciones Críticas
- ID de documento único
- Fechas válidas
- Responsable debe existir
- Área debe existir
- Tipo de documento debe existir
- Carpeta/subcarpeta deben existir
