using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using SistemaGestionDocumental.Data;
using SistemaGestionDocumental.Models;
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

    public AuthController(ApplicationDbContext context, IConfiguration configuration)
    {
        _context = context;
        _configuration = configuration;
    }

    [HttpPost("register")]
    public async Task<ActionResult> Register([FromBody] RegisterRequest dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Username) ||
            string.IsNullOrWhiteSpace(dto.Password) ||
            string.IsNullOrWhiteSpace(dto.NombreCompleto) ||
            string.IsNullOrWhiteSpace(dto.Email))
            return BadRequest(new { message = "Todos los campos son obligatorios" });

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

        try
        {
            // Notify Admins
            // We search for users with roles that can manage users
            var admins = await _context.Usuarios
                .Where(u => u.Rol == UsuarioRol.Administrador || u.Rol == UsuarioRol.AdministradorDocumentos)
                .ToListAsync();

            foreach (var admin in admins)
            {
                _context.Alertas.Add(new Alerta
                {
                    UsuarioId = admin.Id,
                    Titulo = "Nuevo Registro de Usuario",
                    Mensaje = $"El usuario {newUser.NombreCompleto} ({newUser.NombreUsuario}) se ha registrado y requiere aprobación para ingresar.",
                    TipoAlerta = "warning",
                    FechaCreacion = DateTime.UtcNow,
                    Leida = false
                });
            }

            if (admins.Any())
            {
                await _context.SaveChangesAsync();
            }
        }
        catch (Exception)
        {
            alertsError = true;
        }

        var responseMessage = alertsError
            ? "Registro exitoso. No se pudo notificar a los administradores."
            : "Registro exitoso. Pendiente de aprobación por parte de un administrador.";

        return Ok(new { message = responseMessage });
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

        // Bloquear usuarios que aún no fueron aprobados por un administrador,
        // EXCEPTO el Administrador del sistema (puede entrar siempre)
        if (!usuario.Activo &&
            usuario.Rol != UsuarioRol.Administrador)
        {
            return Unauthorized(new { message = "Su cuenta está pendiente de aprobación por un administrador." });
        }

        if (usuario.BloqueadoHasta.HasValue && usuario.BloqueadoHasta.Value > DateTime.UtcNow)
        {
            var remaining = (int)Math.Ceiling((usuario.BloqueadoHasta.Value - DateTime.UtcNow).TotalSeconds);
            return StatusCode(StatusCodes.Status423Locked, new { message = $"Cuenta bloqueada temporalmente. Intente en {remaining} segundos." });
        }

        if (!VerifyPassword(dto.Password, usuario.PasswordHash))
        {
            usuario.IntentosFallidos += 1;

            // Política de bloqueo escalonado:
            // - A partir de 3 intentos fallidos: bloqueo de 30 segundos
            // - Si se sigue equivocando y llega a 10 intentos o más: bloqueo de 1 hora
            const int softThreshold = 3;
            const int hardThreshold = 10;

            if (usuario.IntentosFallidos >= hardThreshold)
            {
                usuario.BloqueadoHasta = DateTime.UtcNow.AddHours(1);
            }
            else if (usuario.IntentosFallidos >= softThreshold)
            {
                usuario.BloqueadoHasta = DateTime.UtcNow.AddSeconds(30);
            }

            usuario.FechaActualizacion = DateTime.UtcNow;
            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateException ex)
            {
                return StatusCode(StatusCodes.Status500InternalServerError, new
                {
                    message = "Error actualizando intentos fallidos en BD. Verifica que la tabla 'usuarios' tenga columnas: intentos_fallidos, bloqueado_hasta, fecha_actualizacion.",
                    error = ex.Message
                });
            }

            return Unauthorized(new { message = "Credenciales inválidas" });
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
                usuario.Activo
            }
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
            usuario.UltimoAcceso,
            usuario.FechaRegistro,
            usuario.FechaActualizacion,
        });
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
}

public class LoginRequest
{
    public string Username { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
}
