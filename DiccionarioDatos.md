# Diccionario de Datos - Sistema de Información Web de Gestión Documental

El siguiente diccionario define la estructura de las tablas creadas en la base de datos junto con sus respectivos tipos de datos, restricciones (nulos) y detalles. 

---

## 1. Tabla: `alertas`
Almacena notificaciones y alertas generadas en el sistema para los usuarios.

| Campo | Tipo de Dato | Longitud | ¿Nulo? | Descripción |
|-------|--------------|:--------:|:------:|-------------|
| `id` | Integer | - | No | Identificador principal (PK) |
| `uuid` | UUID | - | No | Identificador único universal |
| `usuario_id` | Integer | - | Sí | ID del usuario destinatario (FK) |
| `titulo` | Varchar | 200 | No | Título de la alerta |
| `mensaje` | Text/Varchar | - | No | Contenido de la alerta |
| `tipo_alerta` | Varchar | 20 | No | Tipo (ej. info, warning, error) |
| `leida` | Boolean | - | No | Indica si fue leída |
| `fecha_creacion` | Timestamp | - | No | Fecha en la que se generó |
| `fecha_lectura` | Timestamp | - | Sí | Fecha en la que se leyó |
| `documento_id` | Integer | - | Sí | Documento relacionado (FK) |
| `movimiento_id` | Integer | - | Sí | Movimiento relacionado (FK) |

## 2. Tabla: `anexos`
Almacena la información de los archivos adjuntos vinculados a los documentos.

| Campo | Tipo de Dato | Longitud | ¿Nulo? | Descripción |
|-------|--------------|:--------:|:------:|-------------|
| `id` | Integer | - | No | Identificador principal (PK) |
| `documento_id` | Integer | - | No | Documento al que pertenece (FK) |
| `nombre_archivo` | Varchar | 255 | No | Nombre original del archivo |
| `extension` | Varchar | 10 | Sí | Extensión (ej. pdf, docx, png) |
| `tamano_bytes` | Integer | - | Sí | Tamaño del archivo en bytes |
| `url_archivo` | Varchar | 500 | Sí | Ruta o URL de almacenamiento |
| `tipo_contenido` | Varchar | 100 | Sí | MIME type (ej. application/pdf) |
| `fecha_registro` | Timestamp | - | No | Fecha de subida |
| `activo` | Boolean | - | No | Estado de borrado lógico |

## 3. Tabla: `areas`
Listado de áreas o departamentos dentro de la institución.

| Campo | Tipo de Dato | Longitud | ¿Nulo? | Descripción |
|-------|--------------|:--------:|:------:|-------------|
| `id` | Integer | - | No | Identificador principal (PK) |
| `nombre` | Varchar | 100 | No | Nombre completo del área |
| `codigo` | Varchar | 20 | Sí | Código abreviado del área |
| `descripcion` | Varchar | 300 | Sí | Descripción o detalles del área |
| `activo` | Boolean | - | No | Estado del área |

## 4. Tabla: `auditoria`
Registro de todas las acciones sensibles realizadas por los usuarios (Log).

| Campo | Tipo de Dato | Longitud | ¿Nulo? | Descripción |
|-------|--------------|:--------:|:------:|-------------|
| `id` | Integer | - | No | Identificador principal (PK) |
| `usuario_id` | Integer | - | Sí | Usuario que realizó la acción (FK) |
| `accion` | Varchar | 100 | No | Acción (CREAR, ACTUALIZAR, etc.) |
| `tabla_afectada` | Varchar | 50 | Sí | Nombre de la tabla modificada |
| `registro_id` | Integer | - | Sí | Identificador del registro modificado |
| `detalle` | Text | - | Sí | Detalles en formato texto o JSON |
| `ip_address` | Varchar | 50 | Sí | Dirección IP de la solicitud |
| `fecha_accion` | Timestamp | - | No | Fecha y hora de la acción |

## 5. Tabla: `carpetas`
Representa la jerarquía o clasificación física/lógica de los documentos.

| Campo | Tipo de Dato | Longitud | ¿Nulo? | Descripción |
|-------|--------------|:--------:|:------:|-------------|
| `id` | Integer | - | No | Identificador principal (PK) |
| `nombre` | Varchar | 100 | No | Nombre de la carpeta |
| `codigo` | Varchar | 20 | Sí | Código de la carpeta |
| `gestion` | Varchar | 4 | No | Año o gestión de la carpeta (ej. 2026) |
| `descripcion` | Varchar | 300 | Sí | Descripción de la carpeta |
| `rango_inicio` | Integer | - | Sí | Inicio del rango de correlativos |
| `rango_fin` | Integer | - | Sí | Fin del rango de correlativos |
| `tipo` | Varchar | 50 | Sí | Tipo de carpeta |
| `carpeta_padre_id` | Integer | - | Sí | ID de la carpeta superior (FK recursiva)|
| `activo` | Boolean | - | No | Estado de borrado lógico |
| `fecha_creacion` | Timestamp | - | No | Fecha de creación de la carpeta |
| `usuario_creacion_id`| Integer | - | Sí | Usuario que creó la carpeta (FK) |

## 6. Tabla: `configuracion`
Configuraciones y constantes globales configurables del sistema.

| Campo | Tipo de Dato | Longitud | ¿Nulo? | Descripción |
|-------|--------------|:--------:|:------:|-------------|
| `id` | Integer | - | No | Identificador principal (PK) |
| `clave` | Varchar | 100 | No | Clave de configuración (Key) |
| `valor` | Text | - | Sí | Valor de configuración (Value) |
| `descripcion` | Text | - | Sí | Descripción de para qué sirve |
| `tipo_dato` | Varchar | 20 | No | Tipo (string, int, json, etc) |
| `editable` | Boolean | - | No | Si es editable por el usuario |
| `fecha_actualizacion`| Timestamp | - | No | Fecha de última edición |
| `actualizado_por` | Integer | - | Sí | Usuario que editó por última vez (FK)|

## 7. Tabla: `documentos`
Registro central de todos los documentos y su meta-información.

| Campo | Tipo de Dato | Longitud | ¿Nulo? | Descripción |
|-------|--------------|:--------:|:------:|-------------|
| `id` | Integer | - | No | Identificador principal (PK) |
| `uuid` | UUID | - | No | Identificador externo universal |
| `codigo` | Varchar | 50 | No | Código interno |
| `numero_correlativo` | Varchar | 50 | No | Número correlativo del documento |
| `tipo_documento_id` | Integer | - | No | ID del tipo de documento (FK) |
| `area_origen_id` | Integer | - | No | ID del área que emitió (FK) |
| `area_actual_id` | Integer | - | No | ID del área donde se encuentra (FK) |
| `gestion` | Varchar | 4 | No | Gestión / Año |
| `fecha_documento` | Timestamp | - | No | Fecha formal del documento |
| `descripcion` | Text | - | Sí | Descripción / Asunto del documento |
| `responsable_id` | Integer | - | Sí | Usuario responsable actual (FK) |
| `codigo_qr` | Text | - | Sí | Hash o data del código QR |
| `url_qr` | Varchar | 500 | Sí | URL donde se almacena la imagen QR |
| `id_documento` | Varchar | 100 | Sí | Identificador oficial generado |
| `carpeta_id` | Integer | - | Sí | Carpeta donde se archiva (FK) |
| `ubicacion_fisica` | Varchar | 200 | Sí | Texto con la ubicación en archivero |
| `estado` | Integer/Enum | - | No | Estado (Activo, Inactivo, Archivado) |
| `activo` | Boolean | - | No | Estado principal del registro |
| `nivel_confidencialidad`| Integer| - | No | Nivel de acceso (1-5) |
| `fecha_vencimiento` | Timestamp | - | Sí | Fecha en que vence su vigencia |
| `fecha_registro` | Timestamp | - | No | Timestamp de cuando se registró |
| `fecha_actualizacion`| Timestamp | - | No | Timestamp de última modificación |

## 8. Tabla: `documento_palabras_clave`
Tabla intermedia (Muchos a Muchos) entre documentos y palabras clave.

| Campo | Tipo de Dato | Longitud | ¿Nulo? | Descripción |
|-------|--------------|:--------:|:------:|-------------|
| `documento_id` | Integer | - | No | Referencia al documento (FK) |
| `palabra_clave_id` | Integer | - | No | Referencia al tag/palabra clave (FK)|

## 9. Tabla: `historial_documento`
Almacena el registro de los cambios realizados específicamente sobre un documento.

| Campo | Tipo de Dato | Longitud | ¿Nulo? | Descripción |
|-------|--------------|:--------:|:------:|-------------|
| `id` | Integer | - | No | Identificador principal (PK) |
| `uuid` | UUID | - | No | Identificador universal |
| `documento_id` | Integer | - | No | Documento modificado (FK) |
| `fecha_cambio` | Timestamp | - | No | Fecha del cambio |
| `usuario_id` | Integer | - | Sí | Quién hizo el cambio (FK) |
| `tipo_cambio` | Varchar | 50 | No | Naturaleza del cambio |
| `estado_anterior` | Varchar | 255 | Sí | Data antes del cambio |
| `estado_nuevo` | Varchar | 255 | Sí | Data después del cambio |
| `area_anterior_id` | Integer | - | Sí | Área donde estaba (FK) |
| `area_nueva_id` | Integer | - | Sí | Nueva área (FK) |
| `campo_modificado` | Varchar | 100 | Sí | Qué campo de la DB se alteró |
| `valor_anterior` | Text | - | Sí | Valor previo |
| `valor_nuevo` | Text | - | Sí | Valor establecido |
| `observacion` | Text | - | Sí | Observaciones adicionales |

## 10. Tabla: `movimientos`
Flujo lógico de un documento entre distintas áreas o usuarios a través del tiempo.

| Campo | Tipo de Dato | Longitud | ¿Nulo? | Descripción |
|-------|--------------|:--------:|:------:|-------------|
| `id` | Integer | - | No | Identificador principal (PK) |
| `documento_id` | Integer | - | No | Documento en movimiento (FK) |
| `tipo_movimiento` | Varchar | 20 | No | Entrada, Salida, Derivacion, etc |
| `area_origen_id` | Integer | - | Sí | Área de donde sale (FK) |
| `area_destino_id` | Integer | - | Sí | Área hacia donde va (FK) |
| `usuario_id` | Integer | - | Sí | Usuario que recibe o transfiere (FK)|
| `observaciones` | Varchar | 500 | Sí | Notas del movimiento |
| `fecha_movimiento` | Timestamp | - | No | Fecha en la que ocurrió |
| `fecha_devolucion` | Timestamp | - | Sí | Fecha en que fue devuelto (préstamo) |
| `fecha_limite_devolucion`| Timestamp| - | Sí | Plazo máximo asignado (préstamo) |
| `estado` | Varchar | 20 | No | Activo, Devuelto, Cancelado |

## 11. Tabla: `palabras_clave`
Etiquetas o Tags aplicables para clasificar documentos rápidamente.

| Campo | Tipo de Dato | Longitud | ¿Nulo? | Descripción |
|-------|--------------|:--------:|:------:|-------------|
| `id` | Integer | - | No | Identificador principal (PK) |
| `palabra` | Varchar | 50 | No | Tag / Etiqueta |
| `descripcion` | Varchar | 200 | Sí | Detalle o contexto del tag |
| `activo` | Boolean | - | No | Estado del tag |

## 12. Tabla: `permisos`
Catálogo de permisos o capacidades ("Claims") del sistema.

| Campo | Tipo de Dato | Longitud | ¿Nulo? | Descripción |
|-------|--------------|:--------:|:------:|-------------|
| `id` | Integer | - | No | Identificador principal (PK) |
| `codigo` | Varchar | 50 | No | Código del permiso (Ej. DOC_CREATE) |
| `nombre` | Varchar | 100 | No | Nombre legible |
| `descripcion` | Varchar | 500 | Sí | Detalle para qué sirve |
| `modulo` | Varchar | 50 | No | Módulo al que pertenece |
| `activo` | Boolean | - | No | Estado del permiso |

## 13. Tabla: `rol_permisos`
Relación predefinida entre los roles genéricos y los permisos base.

| Campo | Tipo de Dato | Longitud | ¿Nulo? | Descripción |
|-------|--------------|:--------:|:------:|-------------|
| `id` | Integer | - | No | Identificador principal (PK) |
| `rol` | Varchar | 50 | No | Rol del usuario (Enum String) |
| `permiso_id` | Integer | - | No | Permiso dado (FK) |
| `activo` | Boolean | - | No | Indica si esta regla está activa |
| `fecha_asignacion` | Timestamp | - | No | Cuando se le dio el permiso al rol |

## 14. Tabla: `tipos_documento`
Tipologías estándar (Ej. Factura, Resolución, Carta).

| Campo | Tipo de Dato | Longitud | ¿Nulo? | Descripción |
|-------|--------------|:--------:|:------:|-------------|
| `id` | Integer | - | No | Identificador principal (PK) |
| `nombre` | Varchar | 100 | No | Nombre del tipo de documento |
| `codigo` | Varchar | 20 | Sí | Iniciales o código corto |
| `descripcion` | Varchar | 300 | Sí | Descripción detallada |
| `activo` | Boolean | - | No | Estado de este tipo |

## 15. Tabla: `usuarios`
Credenciales y perfil de los miembros del sistema.

| Campo | Tipo de Dato | Longitud | ¿Nulo? | Descripción |
|-------|--------------|:--------:|:------:|-------------|
| `id` | Integer | - | No | Identificador (PK) |
| `uuid` | UUID | - | No | Indentificador universal para tokens |
| `nombre_usuario` | Varchar | 50 | No | Nombre usado para login (username) |
| `nombre_completo` | Varchar | 100 | No | Nombre real del usuario |
| `email` | Varchar | 255 | No | Correo electrónico de contacto |
| `password_hash` | Varchar | 255 | No | Contraseña encriptada |
| `rol` | Enum / Int | - | No | Rol (Admin, Contador, Gerente...) |
| `area_id` | Integer | - | Sí | Departamento al que pertenece (FK) |
| `activo` | Boolean | - | No | Estado habilitado/inhabilitado |
| `solicitud_rechazada`| Boolean | - | No | Si se le denegó registro pendiente |
| `ultimo_acceso` | Timestamp | - | Sí | Fecha de último login exitoso |
| `intentos_fallidos`| Integer | - | No | Número de fallas de login seguidas |
| `bloqueado_hasta` | Timestamp | - | Sí | Tiempo de espera por penalización |
| `fecha_registro` | Timestamp | - | No | Fecha de creación del usuario |
| `fecha_actualizacion`| Timestamp | - | No | Fecha de última modificación |
| `reset_token` | Varchar | 255 | Sí | Token para recuperar contraseña |
| `reset_token_expiry` | Timestamp | - | Sí | Vencimiento del token |
| `pregunta_secreta_id`| Integer | - | Sí | ID pregunta seguridad para reset pwd |
| `respuesta_secreta_hash`| Varchar | 255 | Sí | Hash de la respuesta de seguridad |

## 16. Tabla: `usuario_permisos`
Permisos excepcionales a nivel de usuario (Overrides sobre el Rol predefinido).

| Campo | Tipo de Dato | Longitud | ¿Nulo? | Descripción |
|-------|--------------|:--------:|:------:|-------------|
| `id` | Integer | - | No | Identificador principal (PK) |
| `usuario_id` | Integer | - | No | Usuario al que se aplica la norma (FK)|
| `permiso_id` | Integer | - | No | Permiso regulado (FK) |
| `activo` | Boolean | - | No | Indica si la regla está vigente |
| `denegado` | Boolean | - | No | Si es TRUE, restringe en vez de dar |
| `fecha_asignacion` | Timestamp | - | No | Fecha en la que se aplicó la regla |
