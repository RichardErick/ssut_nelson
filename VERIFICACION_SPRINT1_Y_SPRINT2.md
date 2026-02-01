# Verificación de cumplimiento: Sprint 1, Sprint 2 y Sprint 3

Este documento cruza los entregables definidos en el documento de Requerimientos e Historias de Usuario con el estado actual del proyecto.

---

## Sprint 1 (26/12/2025 – 30/12/2025)

**Objetivo:** Gestión básica de usuarios y control de acceso (registro, login, roles, permisos).

| HU | Historia de Usuario | Entregable esperado | Estado en el proyecto |
|----|---------------------|----------------------|------------------------|
| **HU-01** | Registrar usuarios | Formulario nombre, correo, área, rol, contraseña; hash; persistencia en BD; usuario puede iniciar sesión | ✅ **Cumple** — `register_screen.dart`, `UsuariosController`, `AuthController`; registro con validaciones, asignación de área/rol; contraseña hasheada o texto plano (fallback); solicitudes de registro para admin sistema |
| **HU-02** | Inicio de sesión | Login seguro, redirección por rol, mensaje de error sin detalles sensibles, bloqueo tras N intentos | ✅ **Cumple** — `login_screen.dart`, `AuthController` (JWT); redirección a Home por rol; `AppAlert` para errores; bloqueo 10 min tras 3 intentos; cronómetro en `LockoutTimer` |
| **HU-03** | Gestionar Roles | CRUD roles; asignación a usuarios; restricción de accesos según rol | ✅ **Cumple** — `PermisosController`/roles en backend; `roles_permissions_screen.dart`, `permisos_screen.dart`; asignación de roles a usuarios; verificación por rol en endpoints y frontend |
| **HU-04** | Gestionar permisos | Definir permisos (acciones) y asociarlos a roles; control granular | ✅ **Cumple** — `PermisosController`, matriz rol–permiso; pantallas de permisos por rol; `AuthProvider.hasPermission()` en frontend; FAB y acciones condicionadas por permiso |

**Tareas Sprint 1 (T1.1–T1.7):** Configuración ASP.NET Core, EF, PostgreSQL, Flutter; migraciones Usuarios/Áreas/Roles/Permisos; autenticación y políticas; registro e inicio de sesión; gestión de roles y permisos; pruebas. **Cubiertas** por la estructura actual del backend, frontend y base de datos.

---

## Sprint 2 (02/01/2026 – 06/01/2026)

**Objetivo:** Gestión documental básica — CRUD documentos, QR, clasificación por carpetas/subcarpetas, búsqueda avanzada.

| HU | Historia de Usuario | Entregable esperado | Estado en el proyecto |
|----|---------------------|----------------------|------------------------|
| **HU-03 (CRUD docs)** | CRUD de Documentos | Metadatos, id_documento único, crear/ver/editar/eliminar; persistencia y validaciones | ✅ **Cumple** — `DocumentosController` (CRUD completo), `documento_form_screen.dart`, `documento_detail_screen.dart`, `documentos_list_screen.dart`; metadatos, códigos únicos, anexos PDF |
| **HU-04 (QR)** | Generación de códigos QR | QR vinculado a id_documento; escaneo lleva al detalle; manejo 404/403 | ✅ **Cumple** — `QRService`, `QRCodeController`; generación en detalle de documento; `qr_scanner_screen.dart`; endpoint que resuelve QR a ficha documental |
| **HU-05 (Clasificación)** | Clasificar documentos | Carpetas por gestión (año), subcarpetas; asignar documento a carpeta/subcarpeta; filtros por rango y fecha | ✅ **Cumple** — `CarpetasController`, modelos Carpeta con gestión/rango; `documentos_list_screen.dart` (jerarquía carpetas → subcarpetas → documentos); `documento_form_screen` con carpeta/subcarpeta; migraciones `005_add_carpetas_rangos` |
| **HU-06 (Búsqueda)** | Búsqueda avanzada | Filtros combinables (tipo, fecha, responsable, gestión, palabras clave); paginación; respetar permisos | ✅ **Cumple** — `DocumentoService.buscar` / `BusquedaDocumentoDTO`; `documento_search_screen.dart` con filtros (código, correlativo, QR, tipo, área, gestión, fechas, estado); resultados paginados; permisos aplicados en API |

**Tareas Sprint 2 (T2.1–T2.9):** Esquema Documentos, API CRUD, forms frontend; generador QR y endpoint seguro; modelo gestión/carpeta/subcarpeta y UI; mover en lote (auditoría); búsqueda backend y frontend. **Cubiertas** por `DocumentosController`, `CarpetasController`, servicios de documento/carpeta, pantallas de documentos y búsqueda.

---

## Sprint 3 (09/01/2026 – 13/01/2026)

**Objetivo:** Módulo de movimientos documentales: registro de préstamos y devoluciones, historial (trazabilidad), reportes por período y tipo con exportación a PDF; cambio de estado documento (Disponible/Prestado); alertas por vencimiento; restricciones por permisos.

| HU | Historia de Usuario | Entregable esperado | Estado en el proyecto |
|----|---------------------|----------------------|------------------------|
| **HU-09** | Registro de préstamos | Formulario préstamo (documento, responsable, fechas); estado documento → Prestado | ✅ **Cumple** — `prestamo_form_screen.dart`: selección documento (solo Activo), usuario responsable, área destino opcional, observaciones; FAB "Registrar préstamo" en `movimientos_screen`; backend `MovimientoService.CreateAsync` actualiza documento a Prestado |
| **HU-10** | Registro de devoluciones | Registrar devolución; estado documento → Disponible; historial actualizado | ✅ **Cumple** — Botón "Devolver" en movimientos (Salida/Activo); confirmación con diálogo; `MovimientoService.DevolverDocumentoAsync` marca movimiento Devuelto y documento Activo; AppAlert éxito/error |
| **HU-11** | Registro de movimientos documentales | Historial préstamo/devolución; trazabilidad visible en ficha documento | ✅ **Cumple** — `documento_detail_screen.dart`: sección "HISTORIAL DE MOVIMIENTOS" con `MovimientoService.getByDocumentoId`; lista con tipo, responsable, fecha, estado; backend ya registra movimiento Entrada al devolver |
| **HU-12** | Generación de reportes documentales | Reportes por período y tipo de movimiento; exportación a PDF | ✅ **Cumple** — `reportes_screen.dart`: sección "Reporte de movimientos por período" con filtros fecha desde/hasta y tipo (Todos/Salida/Entrada/Derivación); "Generar reporte" llama a `ReporteService.reporteMovimientos`; lista de resultados; "Exportar a PDF" genera PDF con tabla (documento, tipo, responsable, fecha, estado) y descarga en web |

**Backend ya existente:** `MovimientosController` (GetAll, GetById, GetByDocumentoId, GetPorFecha, Create, Devolver); `ReportesController` (POST reportes/movimientos); `MovimientoService` con cambio de estado documento y registro de Entrada al devolver.

---

## Resumen

| Sprint | Historias | Estado global |
|--------|-----------|----------------|
| **Sprint 1** | HU-01, HU-02, HU-03, HU-04 | ✅ **Cumple** — Registro, login, roles y permisos implementados y operativos |
| **Sprint 2** | CRUD documentos, QR, Clasificación, Búsqueda avanzada | ✅ **Cumple** — Documentos, carpetas/subcarpetas, QR y búsqueda con filtros implementados |
| **Sprint 3** | HU-09, HU-10, HU-11, HU-12 | ✅ **Cumple** — Préstamos, devoluciones, historial en detalle documento, reportes por período y exportación PDF |

**Conclusión:** El proyecto cumple Sprint 1, Sprint 2 y Sprint 3 según los requerimientos funcionales e historias de usuario. Sprint 3 añade: formulario de registro de préstamos, confirmación y AppAlert en devoluciones, historial de movimientos en la ficha del documento y reporte de movimientos con filtros y exportación a PDF.

---

*Documento generado a partir del estado del código y del documento de Requerimientos e Historias de Usuario (Sprint 1, 2 y 3).*
