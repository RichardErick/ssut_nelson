# Recuperación de contraseña por correo

**Si el backend muestra el error "no existe la columna u.reset_token"**, debes ejecutar la migración 009 en PostgreSQL (añade las columnas `reset_token` y `reset_token_expiry` en `usuarios`). Ver `database/EJECUTAR_MIGRACION_009.md` o la sección 1 más abajo.

La recuperación de contraseña por correo está implementada. **El correo se envía al buzón del usuario** (la dirección que ingresó en "¿Olvidaste tu contraseña?"); el usuario lo recibe en Gmail, Outlook, etc. como cualquier otro mensaje.

Para que el backend pueda **enviar** ese correo hace falta configurar un servidor SMTP (Gmail, Outlook, SendGrid, o el correo corporativo). Es la forma estándar de enviar emails: sin SMTP la aplicación no puede "poner" el mensaje en la bandeja del cliente. Una vez configurado, el flujo es: usuario pide recuperar → backend envía el correo al cliente → el cliente recibe el enlace en su correo y restablece la contraseña.

Para **habilitar** el envío hay que configurar la sección Email en el backend (ver más abajo).

## 1. Base de datos

Asegúrate de tener aplicada la migración que añade los campos de reseteo en `usuarios`:

```bash
# En PostgreSQL, ejecutar:
psql -U postgres -d ssut_gestion_documental -f database/migrations/009_add_password_reset.sql
```

O desde tu cliente SQL: ejecutar el contenido de `database/migrations/009_add_password_reset.sql`.

## 2. Configuración de correo (backend)

En `backend/appsettings.json` (o `appsettings.Development.json`) añade la sección **Email**:

```json
{
  "Email": {
    "SmtpHost": "smtp.tu-servidor.com",
    "SmtpPort": 587,
    "SmtpUser": "tu-usuario@dominio.com",
    "SmtpPassword": "tu-password-app",
    "FromAddress": "noreply@tu-dominio.com",
    "FromName": "SSUT Gestión Documental",
    "FrontendBaseUrl": "https://tu-app-web.com"
  }
}
```

- **SmtpHost**: servidor SMTP (ej. Gmail: `smtp.gmail.com`, Outlook: `smtp.office365.com`).
- **SmtpPort**: normalmente 587 (TLS) o 465 (SSL).
- **SmtpUser / SmtpPassword**: credenciales del buzón que envía los correos.
- **FromAddress / FromName**: remitente que verá el usuario.
- **FrontendBaseUrl**: URL base de la app web (Flutter). El enlace de restablecer será `{FrontendBaseUrl}/reset-password?token=...`. Si está vacío, el backend devuelve un enlace relativo y el correo se envía igual (el usuario puede pegar la URL en el navegador).

Si **no** configuras `Email:SmtpHost` (o lo dejas vacío), el backend sigue respondiendo OK a "Olvidé mi contraseña" pero **no envía el correo** (por seguridad no se indica si el email existe o no).

## 3. Métodos de recuperación (dentro de "Olvidé mi contraseña")

En la pantalla de recuperación el usuario puede elegir:

1. **Enlace por correo**  
   Recibe un enlace en su correo; al abrirlo entra en "Nueva contraseña" y define la nueva contraseña.

2. **Código por correo**  
   Recibe un código de 6 dígitos en su correo; en la misma app ingresa correo + código + nueva contraseña (no necesita abrir el correo en otro dispositivo).

3. **Contactar administrador**  
   Mensaje informativo: si no tiene acceso al correo, un administrador puede restablecer la contraseña desde la sección de usuarios.

## 4. Flujo en la app

- **Método enlace:** El usuario elige "Enlace por correo", escribe su correo y envía. El backend genera un token (válido 1 h), lo guarda y envía el correo con el enlace si SMTP está configurado. El usuario abre el enlace (ej. `https://tu-app-web.com/reset-password?token=...`), introduce y confirma la nueva contraseña.
- **Método código:** El usuario elige "Código por correo", escribe su correo y envía. Recibe un código de 6 dígitos por correo. La app le lleva a una pantalla donde ingresa el código y la nueva contraseña; no necesita abrir el enlace en el correo.
- **Contactar administrador:** Solo se muestra texto indicando que un administrador puede restablecer la contraseña desde la gestión de usuarios.

## 5. Seguridad

- El token es de un solo uso y expira en 1 hora.
- La respuesta de "olvidé mi contraseña" es siempre la misma mensaje, aunque el correo no exista, para no revelar si un email está registrado.
