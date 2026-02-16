using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace SistemaGestionDocumental.Migrations
{
    /// <inheritdoc />
    public partial class InitialBaseline : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // ================================================
            // Crear todas las tablas prerequisito con SQL directo
            // (IF NOT EXISTS evita errores si ya existen)
            // ================================================
            migrationBuilder.Sql(@"
                CREATE EXTENSION IF NOT EXISTS ""uuid-ossp"";

                -- Tabla de Áreas
                CREATE TABLE IF NOT EXISTS areas (
                    id SERIAL PRIMARY KEY,
                    nombre VARCHAR(100) NOT NULL,
                    codigo VARCHAR(20),
                    descripcion VARCHAR(300),
                    activo BOOLEAN DEFAULT TRUE
                );

                -- Tabla de Tipos de Documento
                CREATE TABLE IF NOT EXISTS tipos_documento (
                    id SERIAL PRIMARY KEY,
                    nombre VARCHAR(100) NOT NULL,
                    codigo VARCHAR(20),
                    descripcion VARCHAR(300),
                    activo BOOLEAN DEFAULT TRUE
                );

                -- Tabla de Usuarios
                CREATE TABLE IF NOT EXISTS usuarios (
                    id SERIAL PRIMARY KEY,
                    uuid UUID DEFAULT uuid_generate_v4(),
                    nombre_usuario VARCHAR(50) NOT NULL UNIQUE,
                    nombre_completo VARCHAR(100) NOT NULL,
                    email VARCHAR(255) NOT NULL UNIQUE,
                    password_hash VARCHAR(255) NOT NULL,
                    rol TEXT DEFAULT 'Usuario',
                    area_id INTEGER REFERENCES areas(id),
                    activo BOOLEAN DEFAULT TRUE,
                    ultimo_acceso TIMESTAMPTZ,
                    intentos_fallidos INTEGER DEFAULT 0,
                    bloqueado_hasta TIMESTAMPTZ,
                    solicitud_rechazada BOOLEAN DEFAULT FALSE,
                    reset_token VARCHAR(255),
                    reset_token_expiry TIMESTAMPTZ,
                    pregunta_secreta_id INTEGER,
                    respuesta_secreta_hash VARCHAR(255),
                    fecha_registro TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                    fecha_actualizacion TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
                );

                -- Tabla de Documentos
                CREATE TABLE IF NOT EXISTS documentos (
                    id SERIAL PRIMARY KEY,
                    uuid UUID DEFAULT uuid_generate_v4(),
                    codigo VARCHAR(50) NOT NULL UNIQUE,
                    numero_correlativo VARCHAR(50) NOT NULL,
                    tipo_documento_id INTEGER NOT NULL REFERENCES tipos_documento(id),
                    area_origen_id INTEGER NOT NULL REFERENCES areas(id),
                    area_actual_id INTEGER REFERENCES areas(id),
                    gestion VARCHAR(4) NOT NULL,
                    fecha_documento TIMESTAMP NOT NULL,
                    descripcion TEXT,
                    responsable_id INTEGER REFERENCES usuarios(id),
                    codigo_qr TEXT,
                    ubicacion_fisica VARCHAR(200),
                    estado VARCHAR(50) DEFAULT 'Activo',
                    nivel_confidencialidad INTEGER DEFAULT 1,
                    fecha_vencimiento TIMESTAMP,
                    id_documento VARCHAR(100),
                    url_qr VARCHAR(500),
                    activo BOOLEAN DEFAULT TRUE,
                    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );

                -- Tabla de Movimientos
                CREATE TABLE IF NOT EXISTS movimientos (
                    id SERIAL PRIMARY KEY,
                    documento_id INTEGER NOT NULL REFERENCES documentos(id),
                    tipo_movimiento VARCHAR(20) NOT NULL,
                    area_origen_id INTEGER REFERENCES areas(id),
                    area_destino_id INTEGER REFERENCES areas(id),
                    usuario_id INTEGER REFERENCES usuarios(id),
                    observaciones VARCHAR(500),
                    fecha_movimiento TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    fecha_devolucion TIMESTAMP,
                    estado VARCHAR(20) DEFAULT 'Activo'
                );

                -- Tabla de Anexos
                CREATE TABLE IF NOT EXISTS anexos (
                    id SERIAL PRIMARY KEY,
                    documento_id INTEGER NOT NULL REFERENCES documentos(id),
                    nombre_archivo VARCHAR(255) NOT NULL,
                    extension VARCHAR(10),
                    tamano_bytes INTEGER,
                    url_archivo VARCHAR(500),
                    tipo_contenido VARCHAR(100),
                    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    activo BOOLEAN DEFAULT TRUE
                );

                -- Tabla de Historial de Documentos
                CREATE TABLE IF NOT EXISTS historial_documento (
                    id SERIAL PRIMARY KEY,
                    uuid UUID DEFAULT uuid_generate_v4(),
                    documento_id INTEGER NOT NULL REFERENCES documentos(id),
                    fecha_cambio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    usuario_id INTEGER REFERENCES usuarios(id),
                    tipo_cambio VARCHAR(50) NOT NULL,
                    estado_anterior TEXT,
                    estado_nuevo TEXT,
                    area_anterior_id INTEGER REFERENCES areas(id),
                    area_nueva_id INTEGER REFERENCES areas(id),
                    campo_modificado VARCHAR(100),
                    valor_anterior TEXT,
                    valor_nuevo TEXT,
                    observacion TEXT
                );

                -- Tabla de Auditoría
                CREATE TABLE IF NOT EXISTS auditoria (
                    id SERIAL PRIMARY KEY,
                    usuario_id INTEGER REFERENCES usuarios(id),
                    accion VARCHAR(100) NOT NULL,
                    tabla_afectada VARCHAR(50),
                    registro_id INTEGER,
                    detalle TEXT,
                    ip_address VARCHAR(50),
                    fecha_accion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );

                -- Tabla de Configuración
                CREATE TABLE IF NOT EXISTS configuracion (
                    id SERIAL PRIMARY KEY,
                    clave VARCHAR(100) UNIQUE NOT NULL,
                    valor TEXT,
                    descripcion TEXT,
                    tipo_dato VARCHAR(20) DEFAULT 'string',
                    editable BOOLEAN DEFAULT TRUE,
                    fecha_actualizacion TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                    actualizado_por INTEGER REFERENCES usuarios(id)
                );

                -- Tabla de Alertas
                CREATE TABLE IF NOT EXISTS alertas (
                    id SERIAL PRIMARY KEY,
                    uuid UUID DEFAULT uuid_generate_v4(),
                    usuario_id INTEGER REFERENCES usuarios(id),
                    titulo VARCHAR(200) NOT NULL,
                    mensaje TEXT NOT NULL,
                    tipo_alerta VARCHAR(20) DEFAULT 'info',
                    leida BOOLEAN DEFAULT FALSE,
                    fecha_creacion TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                    fecha_lectura TIMESTAMPTZ,
                    documento_id INTEGER REFERENCES documentos(id),
                    movimiento_id INTEGER REFERENCES movimientos(id)
                );

                -- Tabla de Carpetas
                CREATE TABLE IF NOT EXISTS carpetas (
                    id SERIAL PRIMARY KEY,
                    nombre VARCHAR(100) NOT NULL,
                    codigo VARCHAR(20),
                    gestion VARCHAR(4) NOT NULL,
                    descripcion VARCHAR(300),
                    carpeta_padre_id INTEGER REFERENCES carpetas(id) ON DELETE CASCADE,
                    activo BOOLEAN DEFAULT TRUE,
                    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    usuario_creacion_id INTEGER REFERENCES usuarios(id)
                );

                -- Tabla de Palabras Clave
                CREATE TABLE IF NOT EXISTS palabras_clave (
                    id SERIAL PRIMARY KEY,
                    palabra VARCHAR(50) NOT NULL UNIQUE,
                    descripcion VARCHAR(200),
                    activo BOOLEAN DEFAULT TRUE
                );

                -- Tabla Documento-Palabras Clave
                CREATE TABLE IF NOT EXISTS documento_palabras_clave (
                    documento_id INTEGER NOT NULL REFERENCES documentos(id) ON DELETE CASCADE,
                    palabra_clave_id INTEGER NOT NULL REFERENCES palabras_clave(id) ON DELETE CASCADE,
                    PRIMARY KEY (documento_id, palabra_clave_id)
                );

                -- Tabla de Permisos
                CREATE TABLE IF NOT EXISTS permisos (
                    id SERIAL PRIMARY KEY,
                    codigo VARCHAR(50) UNIQUE NOT NULL,
                    nombre VARCHAR(100) NOT NULL,
                    descripcion VARCHAR(500),
                    modulo VARCHAR(50) DEFAULT 'Documentos',
                    activo BOOLEAN DEFAULT TRUE
                );

                -- Tabla de Rol-Permisos
                CREATE TABLE IF NOT EXISTS rol_permisos (
                    id SERIAL PRIMARY KEY,
                    rol VARCHAR(50) NOT NULL,
                    permiso_id INTEGER NOT NULL REFERENCES permisos(id) ON DELETE CASCADE,
                    activo BOOLEAN DEFAULT TRUE,
                    fecha_asignacion TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE(rol, permiso_id)
                );

                -- Datos iniciales de áreas
                INSERT INTO areas (nombre, codigo, descripcion) VALUES
                ('Administración', 'ADM', 'Área de administración general'),
                ('Contabilidad', 'CONT', 'Área de contabilidad y finanzas'),
                ('Recursos Humanos', 'RH', 'Área de recursos humanos'),
                ('Archivo', 'ARCH', 'Área de archivo documental')
                ON CONFLICT DO NOTHING;

                -- Datos iniciales de tipos de documento
                INSERT INTO tipos_documento (nombre, codigo, descripcion) VALUES
                ('Comprobante de Ingreso', 'CI', 'Comprobantes de ingresos contables'),
                ('Comprobante de Egreso', 'CE', 'Comprobantes de egresos contables'),
                ('Memorándum', 'MEM', 'Memorándums administrativos'),
                ('Oficio', 'OF', 'Oficios institucionales'),
                ('Resolución', 'RES', 'Resoluciones administrativas')
                ON CONFLICT DO NOTHING;

                -- Usuarios por defecto
                INSERT INTO usuarios (nombre_usuario, nombre_completo, email, password_hash, rol, area_id) VALUES
                ('admin', 'Administrador del Sistema', 'admin@ssut.edu.bo', 'admin123', 'Administrador', 1),
                ('doc_admin', 'Administrador de Documentos', 'docadmin@ssut.edu.bo', 'admin', 'AdministradorDocumentos', 4)
                ON CONFLICT DO NOTHING;

                -- Permisos base
                INSERT INTO permisos (codigo, nombre, descripcion, modulo) VALUES
                ('ver_documento', 'Ver Documento', 'Permite visualizar documentos', 'Documentos'),
                ('subir_documento', 'Subir Documento', 'Permite subir/crear nuevos documentos', 'Documentos'),
                ('editar_metadatos', 'Editar Metadatos', 'Permite editar información de documentos', 'Documentos'),
                ('borrar_documento', 'Borrar Documento', 'Permite eliminar documentos', 'Documentos'),
                ('gestionar_seguridad', 'Gestionar Seguridad', 'Permite administrar usuarios, roles y permisos', 'Seguridad')
                ON CONFLICT (codigo) DO NOTHING;

                -- Asignar permisos a roles
                INSERT INTO rol_permisos (rol, permiso_id, activo)
                SELECT 'AdministradorSistema', id, true FROM permisos WHERE codigo IN ('ver_documento', 'gestionar_seguridad')
                ON CONFLICT (rol, permiso_id) DO UPDATE SET activo = true;

                INSERT INTO rol_permisos (rol, permiso_id, activo)
                SELECT 'AdministradorDocumentos', id, true FROM permisos WHERE codigo IN ('ver_documento', 'subir_documento', 'editar_metadatos', 'borrar_documento')
                ON CONFLICT (rol, permiso_id) DO UPDATE SET activo = true;

                INSERT INTO rol_permisos (rol, permiso_id, activo)
                SELECT 'Contador', id, true FROM permisos WHERE codigo IN ('ver_documento', 'subir_documento')
                ON CONFLICT (rol, permiso_id) DO UPDATE SET activo = true;

                INSERT INTO rol_permisos (rol, permiso_id, activo)
                SELECT 'Gerente', id, true FROM permisos WHERE codigo = 'ver_documento'
                ON CONFLICT (rol, permiso_id) DO UPDATE SET activo = true;
            ");

            // Ahora crear usuario_permisos (las tablas referenciadas ya existen)
            migrationBuilder.Sql(@"
                CREATE TABLE IF NOT EXISTS usuario_permisos (
                    id INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
                    usuario_id INTEGER NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
                    permiso_id INTEGER NOT NULL REFERENCES permisos(id) ON DELETE CASCADE,
                    activo BOOLEAN NOT NULL DEFAULT TRUE,
                    denegado BOOLEAN DEFAULT FALSE,
                    fecha_asignacion TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                    CONSTRAINT ""UQ_usuario_permisos_usuario_id_permiso_id"" UNIQUE (usuario_id, permiso_id)
                );

                CREATE INDEX IF NOT EXISTS ""IX_usuario_permisos_permiso_id"" ON usuario_permisos(permiso_id);
                CREATE INDEX IF NOT EXISTS ""IX_usuario_permisos_usuario_id"" ON usuario_permisos(usuario_id);
            ");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "usuario_permisos");
        }
    }
}
