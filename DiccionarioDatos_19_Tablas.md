# Diccionario de Datos Completo (19 Tablas) - Sistema de Gestión Documental

Este documento contiene la estructura detallada de las 19 tablas que componen la base de datos del sistema. Está diseñado para ser copiado directamente a Word conservando el formato de tablas profesionales.

---

## 1. Tabla: `alertas`
Almacena notificaciones personales para los usuarios sobre préstamos, vencimientos o derivaciones.

| Campo | Tipo | Nulo | Descripción |
| :--- | :--- | :---: | :--- |
| `id` | SERIAL | NO | Clave primaria. |
| `uuid` | UUID | NO | Identificador único universal para integración. |
| `usuario_id` | INTEGER | SÍ | FK a `usuarios`. Destinatario de la alerta. |
| `titulo` | VARCHAR(200) | NO | Título corto de la notificación. |
| `mensaje` | TEXT | NO | Contenido detallado de la alerta. |
| `tipo_alerta` | VARCHAR(20) | NO | Categoría (info, warning, error, success). |
| `leida` | BOOLEAN | NO | Estado de lectura (default FALSE). |
| `fecha_creacion` | TIMESTAMP | NO | Fecha y hora de generación. |
| `fecha_lectura` | TIMESTAMP | SÍ | Fecha y hora en que el usuario la marcó como leída. |
| `documento_id` | INTEGER | SÍ | FK a `documentos`. Referencia al documento relacionado. |
| `movimiento_id` | INTEGER | SÍ | FK a `movimientos`. Referencia al préstamo o derivación. |

## 2. Tabla: `anexos`
Almacena la metadata de los archivos digitales (PDFs, imágenes) adjuntos a cada documento físico.

| Campo | Tipo | Nulo | Descripción |
| :--- | :--- | :---: | :--- |
| `id` | SERIAL | NO | Clave primaria. |
| `uuid` | UUID | NO | Identificador único para acceso externo. |
| `documento_id` | INTEGER | NO | FK a `documentos`. Documento al que pertenece. |
| `nombre_archivo` | VARCHAR(255) | NO | Nombre lógico del archivo subido. |
| `extension` | VARCHAR(10) | SÍ | Extensión del archivo (.pdf, .jpg). |
| `tamano_bytes` | BIGINT | SÍ | Tamaño del archivo en bytes. |
| `url_archivo` | VARCHAR(500) | SÍ | Ruta física o URL de almacenamiento. |
| `tipo_contenido` | VARCHAR(100) | SÍ | MIME Type (ej. application/pdf). |
| `hash_archivo` | VARCHAR(64) | SÍ | Hash SHA-256 para verificar integridad. |
| `version` | INTEGER | NO | Número de versión del archivo (default 1). |
| `fecha_registro` | TIMESTAMP | NO | Fecha de subida. |
| `activo` | BOOLEAN | NO | Estado de borrado lógico. |

## 3. Tabla: `areas`
Departamentos o unidades organizativas de la institución.

| Campo | Tipo | Nulo | Descripción |
| :--- | :--- | :---: | :--- |
| `id` | SERIAL | NO | Clave primaria. |
| `uuid` | UUID | NO | Identificador único universal. |
| `nombre` | VARCHAR(100) | NO | Nombre del área (ej. Contabilidad). |
| `codigo` | VARCHAR(20) | NO | Sigla o código corto (ej. CONT). |
| `descripcion` | TEXT | SÍ | Detalle de las funciones del área. |
| `activo` | BOOLEAN | NO | Estado del área en el sistema. |
| `fecha_creacion` | TIMESTAMP | NO | Registro de creación. |
| `creado_por` | INTEGER | SÍ | FK a `usuarios`. Usuario que registró el área. |

## 4. Tabla: `auditoria`
Logs detallados de seguridad y operaciones críticas del sistema.

| Campo | Tipo | Nulo | Descripción |
| :--- | :--- | :---: | :--- |
| `id` | SERIAL | NO | Clave primaria. |
| `usuario_id` | INTEGER | SÍ | FK a `usuarios`. Quién realizó la acción. |
| `sesion_id` | VARCHAR(255) | SÍ | Identificador de la sesión web/móvil. |
| `accion` | VARCHAR(100) | NO | Operación realizada (LOGIN, INSERT, DELETE). |
| `tabla_afectada` | VARCHAR(50) | SÍ | Nombre de la tabla impactada. |
| `registro_id` | INTEGER | SÍ | ID del registro afectado. |
| `detalle` | JSONB / TEXT | SÍ | Datos previos y posteriores al cambio. |
| `ip_address` | TEXT | SÍ | Dirección IP del cliente. |
| `user_agent` | TEXT | SÍ | Navegador o dispositivo utilizado. |
| `fecha_accion` | TIMESTAMP | NO | Fecha y hora exacta del evento. |

## 5. Tabla: `carpetas`
Jerarquía de clasificación física o digital de los documentos por gestión.

| Campo | Tipo | Nulo | Descripción |
| :--- | :--- | :---: | :--- |
| `id` | SERIAL | NO | Clave primaria. |
| `nombre` | VARCHAR(100) | NO | Nombre de la carpeta/archivador. |
| `codigo` | VARCHAR(20) | SÍ | Código identificador de la carpeta. |
| `gestion` | VARCHAR(4) | NO | Año fiscal/gestión (ej. 2026). |
| `descripcion` | VARCHAR(300) | SÍ | Descripción del contenido. |
| `rango_inicio` | INTEGER | SÍ | Número correlativo inicial contenido. |
| `rango_fin` | INTEGER | SÍ | Número correlativo final contenido. |
| `carpeta_padre_id` | INTEGER | SÍ | FK recursiva. Carpeta superior (subcarpetas). |
| `activo` | BOOLEAN | NO | Estado de la carpeta. |
| `fecha_creacion` | TIMESTAMP | NO | Fecha de registro. |
| `usuario_creacion_id`| INTEGER| SÍ | FK a `usuarios`. Creador de la estructura. |

## 6. Tabla: `configuracion`
Parámetros globales que alteran el comportamiento del software.

| Campo | Tipo | Nulo | Descripción |
| :--- | :--- | :---: | :--- |
| `id` | SERIAL | NO | Clave primaria. |
| `clave` | VARCHAR(100) | NO | Nombre único del parámetro (Key). |
| `valor` | TEXT | SÍ | Valor configurado (Value). |
| `descripcion` | TEXT | SÍ | Explicación para el administrador. |
| `tipo_dato` | VARCHAR(20) | NO | Tipo (string, int, bool, json). |
| `editable` | BOOLEAN | NO | Si permite edición desde la UI. |
| `fecha_actualizacion`| TIMESTAMP| NO | Último cambio de configuración. |
| `actualizado_por` | INTEGER | SÍ | FK a `usuarios`. Último editor. |

## 7. Tabla: `documentos`
Entidad principal que representa un documento físico o digital registrado.

| Campo | Tipo | Nulo | Descripción |
| :--- | :--- | :---: | :--- |
| `id` | SERIAL | NO | Clave primaria. |
| `uuid` | UUID | NO | Identificador único universal. |
| `codigo` | VARCHAR(50) | NO | Código único autogenerado (QR). |
| `numero_correlativo` | VARCHAR(50) | NO | Número de serie/trámite. |
| `tipo_documento_id` | INTEGER | NO | FK a `tipos_documento`. |
| `area_origen_id` | INTEGER | NO | FK a `areas`. Área que emitió el doc. |
| `area_actual_id` | INTEGER | NO | FK a `areas`. Dónde está el doc ahora. |
| `gestion` | VARCHAR(4) | NO | Año del documento. |
| `fecha_documento` | DATE | NO | Fecha impresa en el documento. |
| `descripcion` | TEXT | SÍ | Asunto o resumen del contenido. |
| `responsable_id` | INTEGER | SÍ | FK a `usuarios`. Poseedor actual del doc. |
| `codigo_qr` | TEXT | SÍ | Texto codificado en el código QR. |
| `url_qr` | VARCHAR(500) | SÍ | Enlace a la imagen del QR generado. |
| `id_documento` | VARCHAR(100) | SÍ | ID institucional/visual. |
| `carpeta_id` | INTEGER | SÍ | FK a `carpetas`. Ubicación lógica. |
| `ubicacion_fisica` | VARCHAR(200) | SÍ | Referencia física (Estante/Caja). |
| `estado` | ENUM / STR | NO | Activo, Inactivo, Archivado, Prestado. |
| `nivel_confidencialidad`| INT | NO | Nivel de acceso 1 (Público) al 5 (Secreto). |
| `fecha_vencimiento` | DATE | SÍ | Fecha en que pierde vigencia. |
| `fecha_registro` | TIMESTAMP | NO | Fecha en que entró al sistema. |

## 8. Tabla: `documento_palabras_clave`
Tabla relacional para indexación por etiquetas (Tags).

| Campo | Tipo | Nulo | Descripción |
| :--- | :--- | :---: | :--- |
| `documento_id` | INTEGER | NO | FK a `documentos`. |
| `palabra_clave_id` | INTEGER | NO | FK a `palabras_clave`. |

## 9. Tabla: `historial_documento`
Trazabilidad de cambios de estado, área o metadata de un archivo específico.

| Campo | Tipo | Nulo | Descripción |
| :--- | :--- | :---: | :--- |
| `id` | SERIAL | NO | Clave primaria. |
| `uuid` | UUID | NO | Identificador único universal. |
| `documento_id` | INTEGER | NO | FK a `documentos`. Objeto del cambio. |
| `fecha_cambio` | TIMESTAMP | NO | Cuándo ocurrió la modificación. |
| `usuario_id` | INTEGER | SÍ | FK a `usuarios`. Autor del cambio. |
| `tipo_cambio` | VARCHAR(50) | NO | Acción (CREACION, ACTUALIZACION, BORRADO). |
| `estado_anterior` | VARCHAR(50) | SÍ | Estado previo al evento. |
| `estado_nuevo` | VARCHAR(50) | SÍ | Estado resultante. |
| `area_anterior_id` | INTEGER | SÍ | FK a `areas`. De donde venía. |
| `area_nueva_id` | INTEGER | SÍ | FK a `areas`. A donde pasó. |
| `campo_modificado` | VARCHAR(100) | SÍ | Nombre de la columna alterada. |
| `valor_anterior` | TEXT | SÍ | Contenido previo. |
| `valor_nuevo` | TEXT | SÍ | Contenido nuevo. |
| `observacion` | TEXT | SÍ | Justificación del cambio. |

## 10. Tabla: `movimientos`
Control de flujo, derivaciones y préstamos de documentos entre áreas.

| Campo | Tipo | Nulo | Descripción |
| :--- | :--- | :---: | :--- |
| `id` | SERIAL | NO | Clave primaria. |
| `uuid` | UUID | NO | Identificador único universal. |
| `documento_id` | INTEGER | NO | FK a `documentos`. |
| `tipo_movimiento` | VARCHAR(20) | NO | Prestamo, Devolucion, Transferencia, etc. |
| `area_origen_id` | INTEGER | SÍ | FK a `areas`. Emisor. |
| `area_destino_id` | INTEGER | SÍ | FK a `areas`. Receptor. |
| `usuario_id` | INTEGER | SÍ | FK a `usuarios`. Solicitante. |
| `usuario_autoriza_id`| INTEGER| SÍ | FK a `usuarios`. Autorizador. |
| `observaciones` | TEXT | SÍ | Comentarios del movimiento. |
| `fecha_movimiento` | TIMESTAMP | NO | Fecha de salida. |
| `fecha_devolucion` | TIMESTAMP | SÍ | Fecha real de retorno. |
| `fecha_limite_devolucion`| TIMESTAMP| SÍ | Fecha comprometida de retorno. |
| `estado` | VARCHAR(20) | NO | Activo, Completado, Cancelado. |

## 11. Tabla: `palabras_clave`
Diccionario de etiquetas para categorizar documentos.

| Campo | Tipo | Nulo | Descripción |
| :--- | :--- | :---: | :--- |
| `id` | SERIAL | NO | Clave primaria. |
| `palabra` | VARCHAR(50) | NO | El tag (ej. URGENTE, LEGAL). |
| `descripcion` | VARCHAR(200) | SÍ | Definición del criterio de uso. |
| `activo` | BOOLEAN | NO | Estado de la palabra clave. |

## 12. Tabla: `permisos`
Catálogo de acciones individuales que se pueden realizar en el software.

| Campo | Tipo | Nulo | Descripción |
| :--- | :--- | :---: | :--- |
| `id` | SERIAL | NO | Clave primaria. |
| `codigo` | VARCHAR(50) | NO | Identificador lógico (ej. documentos.subir). |
| `nombre` | VARCHAR(100) | NO | Nombre descriptivo del permiso. |
| `descripcion` | TEXT | SÍ | Alcance de la acción permitida. |
| `modulo` | VARCHAR(50) | NO | Grupo (DOCUMENTOS, SEGURIDAD, etc). |
| `activo` | BOOLEAN | NO | Estado del permiso. |

## 13. Tabla: `rol_permisos`
Configuración matricial de qué permisos tiene cada rol genérico.

| Campo | Tipo | Nulo | Descripción |
| :--- | :--- | :---: | :--- |
| `id` | SERIAL | NO | Clave primaria. |
| `rol` | VARCHAR(50) | NO | Nombre del Rol (Admin, Contador, etc). |
| `permiso_id` | INTEGER | NO | FK a `permisos`. |
| `activo` | BOOLEAN | NO | Si la regla está vigente. |
| `fecha_asignacion` | TIMESTAMP | NO | Fecha de creación de la regla. |

## 14. Tabla: `tarjetas`
Registro de identificaciones físicas o digitales para control de personal.

| Campo | Tipo | Nulo | Descripción |
| :--- | :--- | :---: | :--- |
| `id` | SERIAL | NO | Clave primaria. |
| `nombre_completo` | VARCHAR(255) | NO | Nombre del titular. |
| `numero_identificacion` | VARCHAR(50) | NO | CI o ID único. |
| `cargo_departamento` | VARCHAR(100) | NO | Referencia laboral. |
| `fecha_emision` | DATE | NO | Fecha de entrega. |
| `fecha_vencimiento` | DATE | SÍ | Caducidad de la tarjeta. |
| `estado` | VARCHAR(20) | NO | Activa, Inactiva, Vencida. |
| `foto_url` | VARCHAR(255) | SÍ | Enlace a la fotografía del titular. |
| `qr_code_url` | VARCHAR(255) | SÍ | Enlace a la imagen del código QR. |
| `created_at` | TIMESTAMP | NO | Fecha de registro. |
| `updated_at` | TIMESTAMP | NO | Última actualización. |

## 15. Tabla: `tipos_documento`
Maestro de tipologías documentales soportadas.

| Campo | Tipo | Nulo | Descripción |
| :--- | :--- | :---: | :--- |
| `id` | SERIAL | NO | Clave primaria. |
| `uuid` | UUID | NO | Identificador único universal. |
| `nombre` | VARCHAR(100) | NO | Ej. Factura, Oficio, Resolución. |
| `codigo` | VARCHAR(20) | NO | Sigla (ej. FAC, OFI). |
| `descripcion` | TEXT | SÍ | Detalles de la tipología. |
| `activo` | BOOLEAN | NO | Estado. |
| `plazo_retencion_dias`| INTEGER | SÍ | Días antes de archivado/destrucción. |
| `creado_por` | INTEGER | SÍ | FK a `usuarios`. |

## 16. Tabla: `usuarios`
Cuentas de acceso y perfil personal de los operarios.

| Campo | Tipo | Nulo | Descripción |
| :--- | :--- | :---: | :--- |
| `id` | SERIAL | NO | Clave primaria. |
| `uuid` | UUID | NO | Identificador interno para tokens. |
| `nombre_usuario` | VARCHAR(50) | NO | Login username. |
| `nombre_completo` | VARCHAR(100) | NO | Nombre real. |
| `email` | VARCHAR(255) | NO | Correo institucional. |
| `password_hash` | VARCHAR(255) | NO | Contraseña cifrada. |
| `rol` | ENUM / STR | NO | Rol base (Admin, Contador, etc). |
| `area_id` | INTEGER | SÍ | FK a `areas`. Pertenencia orgánica. |
| `activo` | BOOLEAN | NO | Habilitado para ingresar. |
| `ultimo_acceso` | TIMESTAMP | SÍ | Registro de última entrada. |
| `preg_secreta_id` | INTEGER | SÍ | Pregunta de seguridad para reset. |
| `resp_secreta_hash` | VARCHAR(255) | SÍ | Hash de la respuesta de seguridad. |
| `fecha_registro` | TIMESTAMP | NO | Fecha de alta. |

## 17. Tabla: `usuario_permisos`
Excepciones de seguridad: Permisos dados o denegados a un usuario específico.

| Campo | Tipo | Nulo | Descripción |
| :--- | :--- | :---: | :--- |
| `id` | SERIAL | NO | Clave primaria. |
| `usuario_id` | INTEGER | NO | FK a `usuarios`. |
| `permiso_id` | INTEGER | NO | FK a `permisos`. |
| `activo` | BOOLEAN | NO | Si la excepción está vigente. |
| `denegado` | BOOLEAN | NO | TRUE: Quita el permiso del rol; FALSE: Lo otorga. |
| `fecha_asignacion` | TIMESTAMP | NO | Fecha de creación de la regla. |

## 18. Tabla: `tipo_movimientos` (Enum/Metadata)
*Nota: Esta tabla suele estar implementada como ENUM o Tabla Maestro dependiendo del archivo de esquema seleccionado.*

| Campo | Tipo | Nulo | Descripción |
| :--- | :--- | :---: | :--- |
| `id` | INT | NO | Identificador. |
| `nombre` | VARCHAR(50) | NO | Ej. Prestamo, Transferencia. |

## 19. Tabla: `notificaciones_config` (Metadata/Relacionada)
*Configuración específica de canales de notificación.*

| Campo | Tipo | Nulo | Descripción |
| :--- | :--- | :---: | :--- |
| `id` | INT | NO | Identificador. |
| `canal` | VARCHAR(20) | NO | Email, Push, UI. |
| `activo` | BOOLEAN | NO | Estado del canal. |
