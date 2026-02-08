using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using SistemaGestionDocumental.Data;
using SistemaGestionDocumental.Models;
using SistemaGestionDocumental.Services;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;

namespace SistemaGestionDocumental.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly ApplicationDbContext _context;
    private readonly IConfiguration _configuration;
    private readonly IEmailSender _emailSender;
    private readonly ILogger<AuthController> _logger;

    public AuthController(ApplicationDbContext context, IConfiguration configuration, IEmailSender emailSender, ILogger<AuthController> logger)
    {
        _context = context;
        _configuration = configuration;
        _emailSender = emailSender;
        _logger = logger;
    }

    /// <summary>Lista de preguntas de seguridad para registro y recuperación de contraseña.</summary>
    private static readonly IReadOnlyList<(int Id, string Texto)> PreguntasSecretas = new List<(int, string)>
    {
        (1, "¿Cuál es el nombre de tu madre?"),
        (2, "¿Cuál es el nombre de tu primera mascota?"),
        (3, "¿En qué ciudad naciste?"),
        (4, "¿Cuál es tu color favorito?"),
        (5, "¿Nombre de tu mejor amigo de la infancia?"),
        (6, "¿Cuál fue tu primer trabajo?"),
        (7, "¿Cuál es el segundo nombre de tu padre?"),
        (8, "¿En qué colegio estudiaste la primaria?"),
        (9, "¿Cuál es tu película favorita?"),
        (10, "¿Cuál es tu comida favorita?"),
    };

    /// <summary>Devuelve la lista de preguntas de seguridad (para registro y recuperación).</summary>
    [HttpGet("preguntas-secretas")]
    public ActionResult PreguntasSecretasList()
    {
        var list = PreguntasSecretas.Select(p => new { id = p.Id, texto = p.Texto }).ToList();
        return Ok(list);
    }

    [HttpPost("register")]
    public async Task<ActionResult> Register([FromBody] RegisterRequest dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Username) ||
            string.IsNullOrWhiteSpace(dto.Password) ||
            string.IsNullOrWhiteSpace(dto.NombreCompleto) ||
            string.IsNullOrWhiteSpace(dto.Email))
            return BadRequest(new { message = "Todos los campos son obligatorios" });

        if (dto.PreguntaSecretaId <= 0 || dto.PreguntaSecretaId > PreguntasSecretas.Count)
            return BadRequest(new { message = "Elige una pregunta de seguridad válida." });
        if (string.IsNullOrWhiteSpace(dto.RespuestaSecreta))
            return BadRequest(new { message = "La respuesta de seguridad es obligatoria." });

        var username = dto.Username.Trim();
        var email = dto.Email.Trim();

        if (await _context.Usuarios.AnyAsync(u => u.NombreUsuario == username))
            return BadRequest(new { message = "El nombre de usuario ya está en uso" });

        if (await _context.Usuarios.AnyAsync(u => u.Email == email))
            return BadRequest(new { message = "El email ya está en uso" });

        if (!Enum.TryParse<UsuarioRol>(dto.Rol, true, out var rolEnum))
        {
            rolEnum = UsuarioRol.Contador; // Default fallback
        }

        var newUser = new SistemaGestionDocumental.Models.Usuario
        {
            NombreUsuario = username,
            NombreCompleto = dto.NombreCompleto.Trim(),
            Email = email,
            PasswordHash = HashPassword(dto.Password),
            Rol = rolEnum,
            Activo = false,
            PreguntaSecretaId = dto.PreguntaSecretaId,
            RespuestaSecretaHash = HashPassword(dto.RespuestaSecreta!.Trim()),
            FechaRegistro = DateTime.UtcNow,
            FechaActualizacion = DateTime.UtcNow
        };

        _context.Usuarios.Add(newUser);
        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException ex)
        {
            return StatusCode(StatusCodes.Status500InternalServerError, new
            {
                message = "Error guardando usuario en BD. Verifica que la tabla 'usuarios' tenga los campos y restricciones esperadas.",
                error = ex.Message
            });
        }

        var alertsError = false;
        var alertsCreated = 0;

        try
        {
            // Notify Admins
            // We search for users with roles that can manage users
            var admins = await _context.Usuarios
                .Where(u => u.Activo)
                .Where(u => u.Rol == UsuarioRol.Administrador || u.Rol == UsuarioRol.AdministradorDocumentos)
                .ToListAsync();

            foreach (var admin in admins)
            {
                _context.Alertas.Add(new Alerta
                {
                    UsuarioId = admin.Id,
                    Titulo = "Nuevo Registro de Usuario",
                    Mensaje = $"El usuario {newUser.NombreCompleto} ({newUser.NombreUsuario}) se ha registrado y requiere aprobación para ingresar. (UsuarioId: {newUser.Id})",
                    TipoAlerta = "warning",
                    FechaCreacion = DateTime.UtcNow,
                    Leida = false
                });
                alertsCreated++;
            }

            if (admins.Any()) await _context.SaveChangesAsync();
        }
        catch (Exception)
        {
            alertsError = true;
        }

        var responseMessage = alertsError
            ? "Registro exitoso. No se pudo notificar a los administradores."
            : "Registro exitoso. Pendiente de aprobación por parte de un administrador.";

        return Ok(new { message = responseMessage, alertsCreated, alertsError });
    }

    private string HashPassword(string password)
    {
        const int iterations = 100_000;
        Span<byte> salt = stackalloc byte[16];
        RandomNumberGenerator.Fill(salt);
        using var pbkdf2 = new Rfc2898DeriveBytes(password, salt.ToArray(), iterations, HashAlgorithmName.SHA256);
        var hash = pbkdf2.GetBytes(32);
        return $"pbkdf2${iterations}${Convert.ToBase64String(salt)}${Convert.ToBase64String(hash)}";
    }

    /// <summary>
    /// Reinicia el contador de intentos fallidos al abrir/reiniciar la app. La app llama con el usuario del formulario (p. ej. Recordarme).
    /// </summary>
    [HttpPost("reset-intentos")]
    public async Task<ActionResult> ResetIntentos([FromBody] ResetIntentosRequest dto)
    {
        if (string.IsNullOrWhiteSpace(dto?.Username))
            return Ok(new { reset = false, message = "Sin usuario" });

        var usernameOrEmail = dto.Username.Trim();
        var usuario = await _context.Usuarios
            .FirstOrDefaultAsync(u => u.NombreUsuario == usernameOrEmail || u.Email == usernameOrEmail);
        if (usuario == null)
            return Ok(new { reset = false });

        usuario.IntentosFallidos = 0;
        usuario.FechaActualizacion = DateTime.UtcNow;
        try
        {
            await _context.SaveChangesAsync();
            return Ok(new { reset = true });
        }
        catch (DbUpdateException)
        {
            return Ok(new { reset = false });
        }
    }

    /// <summary>
    /// Solicitud de recuperación de contraseña. method: "link" = enlace por correo, "code" = código de 6 dígitos por correo.
    /// Siempre devuelve el mismo mensaje para no revelar si el email está registrado.
    /// </summary>
    [HttpPost("forgot-password")]
    public async Task<ActionResult> ForgotPassword([FromBody] ForgotPasswordRequest dto)
    {
        if (string.IsNullOrWhiteSpace(dto?.Email))
            return BadRequest(new { message = "El correo es obligatorio" });

        var email = dto.Email.Trim();
        var method = (dto.Method ?? "link").Trim().ToLowerInvariant();
        if (method != "link" && method != "code")
            method = "link";

        var usuario = await _context.Usuarios.FirstOrDefaultAsync(u => u.Email == email);
        var genericMessage = method == "code"
            ? "Si el correo está registrado, recibirás un código de 6 dígitos. Revisa tu bandeja de entrada y spam."
            : "Si el correo está registrado, recibirás un enlace para restablecer la contraseña. Revisa tu bandeja de entrada y spam.";

        if (usuario != null)
        {
            var expiry = DateTime.UtcNow.AddHours(1);
            string token;

            if (method == "code")
            {
                var rnd = RandomNumberGenerator.GetInt32(0, 1_000_000);
                token = rnd.ToString("D6");
            }
            else
            {
                var tokenBytes = new byte[32];
                RandomNumberGenerator.Fill(tokenBytes);
                token = Convert.ToBase64String(tokenBytes).Replace("+", "-").Replace("/", "_").TrimEnd('=');
            }

            usuario.ResetToken = token;
            usuario.ResetTokenExpiry = expiry;
            usuario.FechaActualizacion = DateTime.UtcNow;

            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateException)
            {
                return Ok(new { message = genericMessage });
            }

            if (method == "code")
            {
                var sent = await _emailSender.SendPasswordResetCodeAsync(usuario.Email, usuario.NombreUsuario, token);
                if (!sent)
                    return Ok(new { message = genericMessage, emailNotSent = true });
            }
            else
            {
                var frontendBase = _configuration["Email:FrontendBaseUrl"]?.TrimEnd('/') ?? "";
                var tokenEncoded = Uri.EscapeDataString(token);
                var resetLink = string.IsNullOrEmpty(frontendBase)
                    ? $"/reset-password?token={tokenEncoded}"
                    : $"{frontendBase}/reset-password?token={tokenEncoded}";
                var sent = await _emailSender.SendPasswordResetAsync(usuario.Email, usuario.NombreUsuario, resetLink);
                if (!sent)
                    return Ok(new { message = genericMessage, emailNotSent = true });
            }
        }

        return Ok(new { message = genericMessage });
    }

    /// <summary>
    /// Restablece la contraseña usando token (enlace) o código + email (método código).
    /// </summary>
    [HttpPost("reset-password")]
    public async Task<ActionResult> ResetPassword([FromBody] ResetPasswordRequest dto)
    {
        if (string.IsNullOrWhiteSpace(dto?.NewPassword) || dto.NewPassword.Length < 6)
            return BadRequest(new { message = "La nueva contraseña debe tener al menos 6 caracteres" });

        Usuario? usuario = null;
        var token = (dto.Token ?? "").Trim();
        var code = (dto.Code ?? "").Trim();
        var email = (dto.Email ?? "").Trim();

        if (!string.IsNullOrEmpty(token))
        {
            usuario = await _context.Usuarios
                .FirstOrDefaultAsync(u => u.ResetToken == token && u.ResetTokenExpiry.HasValue && u.ResetTokenExpiry.Value > DateTime.UtcNow);
            if (usuario == null)
                return BadRequest(new { message = "El enlace ha expirado o no es válido. Solicita uno nuevo desde '¿Olvidaste tu contraseña?'." });
        }
        else if (!string.IsNullOrEmpty(code) && !string.IsNullOrEmpty(email))
        {
            var emailNorm = email.Trim();
            usuario = await _context.Usuarios
                .FirstOrDefaultAsync(u => u.Email == emailNorm && u.ResetToken == code && u.ResetTokenExpiry.HasValue && u.ResetTokenExpiry.Value > DateTime.UtcNow);
            if (usuario == null)
                return BadRequest(new { message = "Código o correo incorrectos, o el código ha expirado. Solicita uno nuevo desde '¿Olvidaste tu contraseña?'." });
        }
        else
            return BadRequest(new { message = "Indica el token del enlace o el código y el correo." });

        try
        {
            await ApplyPasswordReset(usuario, dto.NewPassword!);
            return Ok(new { message = "Contraseña actualizada. Ya puedes iniciar sesión." });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { message = "Error al guardar. Intenta de nuevo.", error = ex.Message });
        }
    }

    /// <summary>
    /// Restablece la contraseña usando nombre de usuario + pin de 4 dígitos (sin correo).
    /// El pin lo genera un administrador desde Gestión de Usuarios.
    /// </summary>
    [HttpPost("reset-password-by-code")]
    public async Task<ActionResult> ResetPasswordByCode([FromBody] ResetPasswordByCodeRequest dto)
    {
        if (string.IsNullOrWhiteSpace(dto?.Username) || string.IsNullOrWhiteSpace(dto?.Code) || string.IsNullOrWhiteSpace(dto?.NewPassword))
            return BadRequest(new { message = "Usuario, código y nueva contraseña son obligatorios." });
        if (dto.NewPassword!.Length < 6)
            return BadRequest(new { message = "La nueva contraseña debe tener al menos 6 caracteres." });

        var username = dto.Username.Trim();
        var code = dto.Code.Trim();

        var usuario = await _context.Usuarios
            .FirstOrDefaultAsync(u => u.NombreUsuario == username && u.ResetToken == code && u.ResetTokenExpiry.HasValue && u.ResetTokenExpiry.Value > DateTime.UtcNow);
        if (usuario == null)
            return BadRequest(new { message = "Usuario o código incorrectos, o el código ha expirado. Pide un nuevo código a tu administrador." });

        try
        {
            await ApplyPasswordReset(usuario, dto.NewPassword);
            return Ok(new { message = "Contraseña actualizada. Ya puedes iniciar sesión." });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { message = "Error al guardar. Intenta de nuevo.", error = ex.Message });
        }
    }

    /// <summary>
    /// Restablece la contraseña usando usuario + pregunta de seguridad + respuesta. No requiere autenticación.
    /// </summary>
    [HttpPost("reset-password-by-pregunta")]
    public async Task<ActionResult> ResetPasswordByPregunta([FromBody] ResetPasswordByPreguntaRequest dto)
    {
        var now = DateTime.Now;
        if (now.Hour < 8 || now.Hour > 18)
            return BadRequest(new { message = "La recuperación de contraseña solo está disponible de 8:00 a 18:00." });

        if (string.IsNullOrWhiteSpace(dto?.Username) || dto.PreguntaSecretaId <= 0 ||
            string.IsNullOrWhiteSpace(dto?.Respuesta) || string.IsNullOrWhiteSpace(dto?.NewPassword))
            return BadRequest(new { message = "Usuario, pregunta, respuesta y nueva contraseña son obligatorios." });
        if (dto.NewPassword!.Length < 6)
            return BadRequest(new { message = "La nueva contraseña debe tener al menos 6 caracteres." });

        var usuario = await _context.Usuarios
            .FirstOrDefaultAsync(u => u.NombreUsuario == dto.Username!.Trim());
        if (usuario == null)
            return BadRequest(new { message = "Usuario o respuesta incorrectos. Vuelve a intentar." });

        if (usuario.PreguntaSecretaId != dto.PreguntaSecretaId || string.IsNullOrEmpty(usuario.RespuestaSecretaHash))
            return BadRequest(new { message = "Usuario o respuesta incorrectos. Vuelve a intentar." });

        if (!VerifyPassword(dto.Respuesta!.Trim(), usuario.RespuestaSecretaHash!))
            return BadRequest(new { message = "Usuario o respuesta incorrectos. Vuelve a intentar." });

        try
        {
            await ApplyPasswordReset(usuario, dto.NewPassword);
            return Ok(new { message = "Contraseña actualizada. Ya puedes iniciar sesión." });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { message = "Error al guardar. Intenta de nuevo.", error = ex.Message });
        }
    }

    /// <summary>
    /// Verifica que la respuesta secreta sea correcta antes de permitir cambiar la contraseña.
    /// No cambia la contraseña; solo valida usuario + pregunta + respuesta. Mismo horario 8:00–18:00.
    /// </summary>
    [HttpPost("verificar-respuesta-secreta")]
    public async Task<ActionResult> VerificarRespuestaSecreta([FromBody] VerificarRespuestaSecretaRequest dto)
    {
        var now = DateTime.Now;
        if (now.Hour < 8 || now.Hour > 18)
            return BadRequest(new { message = "La recuperación de contraseña solo está disponible de 8:00 a 18:00." });

        if (string.IsNullOrWhiteSpace(dto?.Username) || dto.PreguntaSecretaId <= 0 || string.IsNullOrWhiteSpace(dto?.RespuestaSecreta))
            return BadRequest(new { message = "Usuario, pregunta y respuesta son obligatorios." });

        var usuario = await _context.Usuarios
            .FirstOrDefaultAsync(u => u.NombreUsuario == dto.Username!.Trim());
        if (usuario == null)
            return BadRequest(new { message = "Usuario o respuesta incorrectos. Vuelve a intentar." });

        if (usuario.PreguntaSecretaId != dto.PreguntaSecretaId || string.IsNullOrEmpty(usuario.RespuestaSecretaHash))
            return BadRequest(new { message = "Usuario o respuesta incorrectos. Vuelve a intentar." });

        if (!VerifyPassword(dto.RespuestaSecreta!.Trim(), usuario.RespuestaSecretaHash!))
            return BadRequest(new { message = "Usuario o respuesta incorrectos. Vuelve a intentar." });

        return Ok(new { verified = true, message = "Respuesta correcta. Ahora puedes definir tu nueva contraseña." });
    }

    /// <summary>
    /// Crea una solicitud de recuperación y notifica a los administradores (para que generen un código o contacten al usuario).
    /// No requiere autenticación. No revela si el email/usuario existe.
    /// </summary>
    [HttpPost("solicitud-recuperacion")]
    public async Task<ActionResult> SolicitudRecuperacion([FromBody] SolicitudRecuperacionRequest dto)
    {
        var tipo = (dto?.Tipo ?? "").Trim().ToLowerInvariant();
        if (tipo != "password" && tipo != "username")
            return BadRequest(new { message = "Tipo debe ser 'password' o 'username'." });

        var email = dto?.Email?.Trim();
        var username = dto?.Username?.Trim();
        if (tipo == "username" && string.IsNullOrWhiteSpace(email))
            return BadRequest(new { message = "Para recuperar usuario se requiere el correo." });
        if (tipo == "password" && string.IsNullOrWhiteSpace(email) && string.IsNullOrWhiteSpace(username))
            return BadRequest(new { message = "Indica tu correo o tu usuario para que el administrador pueda ayudarte." });

        Usuario? usuario = null;
        var emailNorm = email?.Trim().ToLowerInvariant();
        var usernameNorm = username?.Trim().ToLowerInvariant();
        if (!string.IsNullOrWhiteSpace(emailNorm))
            usuario = await _context.Usuarios.FirstOrDefaultAsync(u => u.Email != null && u.Email.ToLower() == emailNorm);
        if (usuario == null && !string.IsNullOrWhiteSpace(usernameNorm))
            usuario = await _context.Usuarios.FirstOrDefaultAsync(u => u.NombreUsuario.ToLower() == usernameNorm);

        var admins = await _context.Usuarios
            .Where(u => u.Activo && (u.Rol == UsuarioRol.Administrador || u.Rol == UsuarioRol.AdministradorDocumentos))
            .ToListAsync();

        if (admins.Count > 0)
        {
            var titulo = tipo == "username"
                ? "Solicitud: recuperar usuario (olvidó su usuario)"
                : "Solicitud: recuperación de contraseña";
            string mensaje;
            if (tipo == "password")
            {
                var datosUsuario = usuario != null
                    ? $"{usuario.NombreCompleto} ({usuario.NombreUsuario}), Email: {usuario.Email}"
                    : string.Join(", ", new[] { !string.IsNullOrWhiteSpace(username) ? $"usuario: {username}" : null, !string.IsNullOrWhiteSpace(email) ? $"email: {email}" : null }.Where(x => x != null));
                if (usuario == null && string.IsNullOrEmpty(datosUsuario)) datosUsuario = "(sin datos)";
                mensaje = $"El usuario {datosUsuario} está intentando recuperar contraseña, visualizar contraseña o asignar nueva. Revisa en Gestión de Usuarios y restablece la contraseña o genera un código." + (usuario != null ? $" (UsuarioId: {usuario.Id})" : "");
            }
            else
            {
                if (usuario != null)
                    mensaje = $"El usuario {usuario.NombreCompleto} ({usuario.NombreUsuario}), Email: {usuario.Email} está intentando recuperar su usuario. Revisa en Gestión de Usuarios y genera un código si corresponde. (UsuarioId: {usuario.Id})";
                else
                    mensaje = $"Alguien está intentando recuperar su usuario. Datos indicados: Email: {email ?? "(no indicado)"}. Revisa en Gestión de Usuarios si existe y genera un código si corresponde.";
            }

            foreach (var admin in admins)
            {
                _context.Alertas.Add(new Alerta
                {
                    UsuarioId = admin.Id,
                    Titulo = titulo,
                    Mensaje = mensaje,
                    TipoAlerta = "warning",
                    FechaCreacion = DateTime.UtcNow,
                    Leida = false
                });
            }
            try { await _context.SaveChangesAsync(); }
            catch (Exception ex)
            {
                _logger.LogError(ex, "SolicitudRecuperacion: no se pudieron guardar las alertas para los administradores. Revisa que la tabla alertas exista y tenga las columnas correctas.");
            }
        }

        return Ok(new
        {
            message = tipo == "username"
                ? "Si tu correo está registrado, un administrador recibirá la solicitud y te contactará o generará un código de recuperación."
                : "Tu solicitud ha sido registrada. Un administrador la revisará y podrá generarte un código de recuperación desde Gestión de Usuarios."
        });
    }

    private async Task ApplyPasswordReset(Usuario usuario, string newPassword)
    {
        usuario.PasswordHash = HashPassword(newPassword);
        usuario.ResetToken = null;
        usuario.ResetTokenExpiry = null;
        usuario.FechaActualizacion = DateTime.UtcNow;

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException ex)
        {
            throw new InvalidOperationException("Error al guardar.", ex);
        }
    }

    [HttpPost("login")]
    public async Task<ActionResult> Login([FromBody] LoginRequest dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Username) || string.IsNullOrWhiteSpace(dto.Password))
            return BadRequest(new { message = "Username y Password son obligatorios" });

        var usernameOrEmail = dto.Username.Trim();

        var usuario = await _context.Usuarios
            .FirstOrDefaultAsync(u => u.NombreUsuario == usernameOrEmail || u.Email == usernameOrEmail);

        if (usuario == null)
            return Unauthorized(new { message = "Credenciales inválidas" });

        // Usuarios inactivos no pueden acceder (salvo Administrador del sistema).
        // Inactivo = pendiente de aprobación o desactivado por un admin; solo un admin puede reactivarlos.
        if (!usuario.Activo &&
            usuario.Rol != UsuarioRol.Administrador)
        {
            var mensaje = usuario.SolicitudRechazada
                ? "Su solicitud de registro fue rechazada. Contacte al administrador."
                : "Su cuenta no está activa. Contacte al administrador para que la reactive.";
            return Unauthorized(new { message = mensaje });
        }

        // Verificar si el usuario está bloqueado
        if (usuario.BloqueadoHasta.HasValue && usuario.BloqueadoHasta.Value > DateTime.UtcNow)
        {
            var tiempoRestante = usuario.BloqueadoHasta.Value - DateTime.UtcNow;
            return StatusCode(423, new 
            { 
                message = $"Su cuenta está bloqueada. Intente de nuevo en {Math.Ceiling(tiempoRestante.TotalMinutes)} minutos.",
                remainingSeconds = (int)tiempoRestante.TotalSeconds
            });
        }

        if (!VerifyPassword(dto.Password, usuario.PasswordHash))
        {
            const int maxAttempts = 3;
            const int lockoutMinutes = 10;
            var now = DateTime.UtcNow;
            var userId = usuario.Id;

            // Si el bloqueo ya expiró, dar 3 intentos nuevos (reiniciar contador)
            if (usuario.BloqueadoHasta.HasValue && usuario.BloqueadoHasta.Value <= now)
            {
                await _context.Database.ExecuteSqlRawAsync(
                    "UPDATE usuarios SET intentos_fallidos = 0, bloqueado_hasta = NULL, fecha_actualizacion = {0} WHERE id = {1}",
                    now, userId);
            }

            // Incremento atómico en BD para que los intentos se persistan correctamente
            await _context.Database.ExecuteSqlRawAsync(
                "UPDATE usuarios SET intentos_fallidos = intentos_fallidos + 1, fecha_actualizacion = {0} WHERE id = {1}",
                now, userId);

            // Recargar usuario desde BD para obtener el valor actualizado de intentos_fallidos
            var usuarioActualizado = await _context.Usuarios.AsNoTracking().FirstOrDefaultAsync(u => u.Id == userId);
            var intentosActuales = usuarioActualizado?.IntentosFallidos ?? 1;

            if (intentosActuales >= maxAttempts)
            {
                var bloqueadoHasta = now.AddMinutes(lockoutMinutes);
                await _context.Database.ExecuteSqlRawAsync(
                    "UPDATE usuarios SET bloqueado_hasta = {0}, fecha_actualizacion = {1} WHERE id = {2}",
                    bloqueadoHasta, now, userId);

                return StatusCode(423, new
                {
                    message = $"Se ha excedido el número máximo de intentos. Cuenta bloqueada temporalmente por {lockoutMinutes} minutos.",
                    remainingSeconds = lockoutMinutes * 60
                });
            }

            var remaining = maxAttempts - intentosActuales;
            string message = remaining == 1
                ? "Credenciales inválidas. Le queda 1 intento antes del bloqueo temporal. ¡Precaución!"
                : $"Credenciales inválidas. Le quedan {remaining} intentos antes del bloqueo temporal.";
            return Unauthorized(new
            {
                message,
                failedAttempts = intentosActuales,
                remainingAttempts = remaining
            });
        }

        usuario.IntentosFallidos = 0;
        usuario.BloqueadoHasta = null;
        usuario.UltimoAcceso = DateTime.UtcNow;
        usuario.FechaActualizacion = DateTime.UtcNow;
        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException ex)
        {
            return StatusCode(StatusCodes.Status500InternalServerError, new
            {
                message = "Error actualizando último acceso en BD. Verifica que la tabla 'usuarios' tenga columnas: ultimo_acceso, intentos_fallidos, bloqueado_hasta, fecha_actualizacion.",
                error = ex.Message
            });
        }

        var token = GenerateJwt(usuario);

        // Obtener permisos efectivos
        var roleName = usuario.Rol.ToString();
        var normalizedRole = roleName == "Administrador" ? "AdministradorSistema" : roleName;

        var permisosRol = await _context.RolPermisos
            .Where(rp => rp.Rol == normalizedRole && rp.Activo)
            .Select(rp => rp.Permiso.Codigo)
            .ToListAsync();

        var permisosUsuario = await _context.UsuarioPermisos
            .Where(up => up.UsuarioId == usuario.Id && up.Activo)
            .Select(up => new { up.Permiso.Codigo, up.Denegado })
            .ToListAsync();

        var granted = permisosUsuario.Where(p => !p.Denegado).Select(p => p.Codigo);
        var denied = permisosUsuario.Where(p => p.Denegado).Select(p => p.Codigo).ToHashSet();

        var effectivePermissions = permisosRol
            .Where(p => !denied.Contains(p))
            .Union(granted)
            .Distinct()
            .ToList();

        var tienePreguntaSecreta = usuario.PreguntaSecretaId.HasValue && !string.IsNullOrEmpty(usuario.RespuestaSecretaHash);

        if (!tienePreguntaSecreta)
        {
            var yaTieneAlerta = await _context.Alertas.AnyAsync(a =>
                a.UsuarioId == usuario.Id && !a.Leida &&
                (a.Titulo == "Pregunta secreta pendiente" || a.Mensaje.Contains("pregunta secreta")));
            if (!yaTieneAlerta)
            {
                _context.Alertas.Add(new Alerta
                {
                    UsuarioId = usuario.Id,
                    Titulo = "Pregunta secreta pendiente",
                    Mensaje = "Por normas de seguridad es necesario que configures tu pregunta secreta por si olvidas la contraseña. Podrás elegir la pregunta y tu respuesta.",
                    TipoAlerta = "warning",
                    FechaCreacion = DateTime.UtcNow,
                    Leida = false
                });
                try { await _context.SaveChangesAsync(); } catch { /* no fallar login */ }
            }
        }

        return Ok(new
        {
            token,
            user = new
            {
                usuario.Id,
                usuario.NombreUsuario,
                usuario.NombreCompleto,
                usuario.Email,
                usuario.Rol,
                usuario.AreaId,
                usuario.Activo,
                tienePreguntaSecreta
            },
            permisos = effectivePermissions
        });
    }

    [Authorize]
    [HttpGet("me")]
    public async Task<ActionResult> Me()
    {
        var idClaim = User.FindFirstValue(JwtRegisteredClaimNames.Sub)
            ?? User.FindFirstValue(ClaimTypes.NameIdentifier);

        if (int.TryParse(idClaim, out var userId))
        {
            var usuarioById = await _context.Usuarios
                .AsNoTracking()
                .Include(u => u.Area)
                .FirstOrDefaultAsync(u => u.Id == userId);

            if (usuarioById == null)
                return Unauthorized(new { message = "Sesión inválida" });

            return Ok(new
            {
                usuarioById.Id,
                usuarioById.NombreUsuario,
                usuarioById.NombreCompleto,
                usuarioById.Email,
                usuarioById.Rol,
                usuarioById.AreaId,
                AreaNombre = usuarioById.Area != null ? usuarioById.Area.Nombre : null,
                usuarioById.Activo,
                usuarioById.UltimoAcceso,
                usuarioById.FechaRegistro,
                usuarioById.FechaActualizacion,
                tienePreguntaSecreta = usuarioById.PreguntaSecretaId.HasValue && !string.IsNullOrEmpty(usuarioById.RespuestaSecretaHash)
            });
        }

        var username = User.FindFirstValue(JwtRegisteredClaimNames.UniqueName)
            ?? User.Identity?.Name;

        if (string.IsNullOrWhiteSpace(username))
            return Unauthorized(new { message = "Sesión inválida" });

        var usuario = await _context.Usuarios
            .AsNoTracking()
            .Include(u => u.Area)
            .FirstOrDefaultAsync(u => u.NombreUsuario == username || u.Email == username);

        if (usuario == null)
            return Unauthorized(new { message = "Sesión inválida" });

        return Ok(new
        {
            usuario.Id,
            usuario.NombreUsuario,
            usuario.NombreCompleto,
            usuario.Email,
            usuario.Rol,
            usuario.AreaId,
            AreaNombre = usuario.Area != null ? usuario.Area.Nombre : null,
            usuario.Activo,
            tienePreguntaSecreta = usuario.PreguntaSecretaId.HasValue && !string.IsNullOrEmpty(usuario.RespuestaSecretaHash),
            usuario.UltimoAcceso,
            usuario.FechaRegistro,
            usuario.FechaActualizacion,
        });
    }

    /// <summary>Permite al usuario autenticado configurar su pregunta y respuesta de seguridad (usuarios antiguos sin pregunta).</summary>
    [Authorize]
    [HttpPut("mi-pregunta-secreta")]
    public async Task<ActionResult> MiPreguntaSecreta([FromBody] MiPreguntaSecretaRequest dto)
    {
        if (dto == null || dto.PreguntaSecretaId <= 0 || dto.PreguntaSecretaId > PreguntasSecretas.Count)
            return BadRequest(new { message = "Elige una pregunta de seguridad válida." });
        if (string.IsNullOrWhiteSpace(dto.RespuestaSecreta))
            return BadRequest(new { message = "La respuesta de seguridad es obligatoria." });

        var idClaim = User.FindFirstValue(JwtRegisteredClaimNames.Sub) ?? User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!int.TryParse(idClaim, out var userId))
            return Unauthorized(new { message = "Sesión inválida" });

        var usuario = await _context.Usuarios.FindAsync(userId);
        if (usuario == null)
            return Unauthorized(new { message = "Usuario no encontrado" });

        usuario.PreguntaSecretaId = dto.PreguntaSecretaId;
        usuario.RespuestaSecretaHash = HashPassword(dto.RespuestaSecreta!.Trim());
        usuario.FechaActualizacion = DateTime.UtcNow;

        var alertaPendiente = await _context.Alertas
            .FirstOrDefaultAsync(a => a.UsuarioId == userId && !a.Leida &&
                (a.Titulo == "Pregunta secreta pendiente" || a.Mensaje.Contains("pregunta secreta")));
        if (alertaPendiente != null)
        {
            alertaPendiente.Leida = true;
            alertaPendiente.FechaLectura = DateTime.UtcNow;
        }

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException ex)
        {
            return StatusCode(500, new { message = "Error al guardar.", error = ex.Message });
        }

        return Ok(new { message = "Pregunta secreta configurada correctamente.", tienePreguntaSecreta = true });
    }

    private string GenerateJwt(SistemaGestionDocumental.Models.Usuario usuario)
    {
        var issuer = _configuration["Jwt:Issuer"];
        var audience = _configuration["Jwt:Audience"];
        var key = _configuration["Jwt:Key"];
        var expiresMinutes = int.TryParse(_configuration["Jwt:ExpiresMinutes"], out var m) ? m : 480;

        if (string.IsNullOrWhiteSpace(issuer) || string.IsNullOrWhiteSpace(audience) || string.IsNullOrWhiteSpace(key))
            throw new InvalidOperationException("JWT configuration missing. Configure Jwt:Issuer, Jwt:Audience and Jwt:Key in appsettings.");

        var roleName = usuario.Rol.ToString();
        var role = string.Equals(roleName, "Administrador", StringComparison.Ordinal)
            ? "AdministradorSistema"
            : roleName;

        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, usuario.Id.ToString()),
            new(JwtRegisteredClaimNames.UniqueName, usuario.NombreUsuario),
            new(ClaimTypes.Role, role),
        };

        var signingKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key));
        var creds = new SigningCredentials(signingKey, SecurityAlgorithms.HmacSha256);

        var jwt = new JwtSecurityToken(
            issuer: issuer,
            audience: audience,
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(expiresMinutes),
            signingCredentials: creds
        );

        return new JwtSecurityTokenHandler().WriteToken(jwt);
    }

    private static bool VerifyPassword(string password, string stored)
    {
        if (string.IsNullOrWhiteSpace(stored))
            return false;

        // bcrypt (commonly starts with $2a$, $2b$, $2y$)
        if (stored.StartsWith("$2", StringComparison.Ordinal))
        {
            try
            {
                return BCrypt.Net.BCrypt.Verify(password, stored);
            }
            catch
            {
                return false;
            }
        }

        // Expected format: pbkdf2$iterations$saltBase64$hashBase64
        if (stored.StartsWith("pbkdf2$", StringComparison.OrdinalIgnoreCase))
        {
            var parts = stored.Split('$');
            if (parts.Length != 4)
                return false;

            if (!int.TryParse(parts[1], out var iterations))
                return false;

            byte[] salt;
            byte[] expectedHash;

            try
            {
                salt = Convert.FromBase64String(parts[2]);
                expectedHash = Convert.FromBase64String(parts[3]);
            }
            catch
            {
                return false;
            }

            using var pbkdf2 = new Rfc2898DeriveBytes(password, salt, iterations, HashAlgorithmName.SHA256);
            var actualHash = pbkdf2.GetBytes(expectedHash.Length);
            return CryptographicOperations.FixedTimeEquals(actualHash, expectedHash);
        }

        // Fallback (legacy): treat stored as plain text
        return string.Equals(password, stored, StringComparison.Ordinal);
    }
}

public class RegisterRequest
{
    public string Username { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string NombreCompleto { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Rol { get; set; } = "Contador";
    /// <summary>ID de la pregunta de seguridad (1-10). Obligatorio.</summary>
    public int PreguntaSecretaId { get; set; }
    /// <summary>Respuesta de seguridad. Obligatoria.</summary>
    public string? RespuestaSecreta { get; set; }
}

public class VerificarRespuestaSecretaRequest
{
    public string? Username { get; set; }
    public int PreguntaSecretaId { get; set; }
    public string? RespuestaSecreta { get; set; }
}

public class ResetPasswordByPreguntaRequest
{
    public string? Username { get; set; }
    public int PreguntaSecretaId { get; set; }
    public string? Respuesta { get; set; }
    public string? NewPassword { get; set; }
}

public class MiPreguntaSecretaRequest
{
    public int PreguntaSecretaId { get; set; }
    public string? RespuestaSecreta { get; set; }
}

public class LoginRequest
{
    public string Username { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
}

public class ResetIntentosRequest
{
    public string? Username { get; set; }
}

public class ForgotPasswordRequest
{
    public string? Email { get; set; }
    /// <summary>"link" = enlace por correo (por defecto), "code" = código de 6 dígitos por correo.</summary>
    public string? Method { get; set; }
}

public class ResetPasswordRequest
{
    /// <summary>Token del enlace (método link).</summary>
    public string? Token { get; set; }
    /// <summary>Código de 6 dígitos (método code); requiere también Email.</summary>
    public string? Code { get; set; }
    /// <summary>Correo del usuario (obligatorio cuando se usa Code).</summary>
    public string? Email { get; set; }
    public string? NewPassword { get; set; }
}

public class ResetPasswordByCodeRequest
{
    public string? Username { get; set; }
    public string? Code { get; set; }
    public string? NewPassword { get; set; }
}

public class SolicitudRecuperacionRequest
{
    /// <summary>"password" = solicitud de recuperación de contraseña; "username" = solicitud porque olvidó su usuario.</summary>
    public string? Tipo { get; set; }
    public string? Email { get; set; }
    public string? Username { get; set; }
}
