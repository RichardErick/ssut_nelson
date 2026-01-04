using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SistemaGestionDocumental.Data;
using SistemaGestionDocumental.Models;
using Npgsql;
using System.Security.Cryptography;

namespace SistemaGestionDocumental.Controllers;

[ApiController]
[Route("api/[controller]")]
public class UsuariosController : ControllerBase
{
    private readonly ApplicationDbContext _context;
    private readonly IConfiguration _configuration;

    private static readonly string[] RolesValidos =
    [
        "AdministradorSistema",
        nameof(UsuarioRol.Administrador),
        nameof(UsuarioRol.AdministradorDocumentos),
        nameof(UsuarioRol.ArchivoCentral),
        nameof(UsuarioRol.TramiteDocumentario),
        nameof(UsuarioRol.Supervisor),
        nameof(UsuarioRol.Usuario),
    ];

    public UsuariosController(ApplicationDbContext context, IConfiguration configuration)
    {
        _context = context;
        _configuration = configuration;
    }

    private static UsuarioRol? ParseRolOrNull(string? role)
    {
        if (string.IsNullOrWhiteSpace(role))
            return null;

        var normalized = role.Trim();

        // Alias usado solo para permisos (JWT), lo persistimos como Administrador
        if (string.Equals(normalized, "AdministradorSistema", StringComparison.Ordinal))
            normalized = nameof(UsuarioRol.Administrador);

        return Enum.TryParse<UsuarioRol>(normalized, ignoreCase: false, out var parsed)
            ? parsed
            : null;
    }

    [HttpGet]
    public async Task<ActionResult> GetAll()
    {
        var usuarios = await _context.Usuarios
            .Include(u => u.Area)
            .Select(u => new
            {
                u.Id,
                u.NombreUsuario,
                u.NombreCompleto,
                u.Email,
                Rol = u.Rol.ToString(),
                u.AreaId,
                AreaNombre = u.Area != null ? u.Area.Nombre : null,
                u.Activo,
                u.UltimoAcceso,
                u.FechaRegistro,
                u.FechaActualizacion
            })
            .OrderBy(u => u.NombreCompleto)
            .ToListAsync();

        return Ok(usuarios);
    }

    [HttpPost]
    public async Task<ActionResult> Create([FromBody] CreateUsuarioDTO dto)
    {
        if (string.IsNullOrWhiteSpace(dto.NombreUsuario) ||
            string.IsNullOrWhiteSpace(dto.NombreCompleto) ||
            string.IsNullOrWhiteSpace(dto.Email) ||
            string.IsNullOrWhiteSpace(dto.Password))
        {
            return BadRequest(new { message = "NombreUsuario, NombreCompleto, Email y Password son obligatorios" });
        }

        var rolInput = string.IsNullOrWhiteSpace(dto.Rol) ? nameof(UsuarioRol.Usuario) : dto.Rol.Trim();
        if (!RolesValidos.Contains(rolInput))
            return BadRequest(new { message = $"Rol inválido. Roles permitidos: {string.Join(", ", RolesValidos)}" });

        var rolParsed = ParseRolOrNull(rolInput);
        if (rolParsed == null)
            return BadRequest(new { message = $"Rol inválido. Roles permitidos: {string.Join(", ", RolesValidos)}" });

        var nombreUsuario = dto.NombreUsuario.Trim();
        var email = dto.Email.Trim();

        var usernameExists = await _context.Usuarios.AnyAsync(u => u.NombreUsuario == nombreUsuario);
        if (usernameExists)
            return BadRequest(new { message = "El nombre de usuario ya está en uso" });

        var emailExists = await _context.Usuarios.AnyAsync(u => u.Email == email);
        if (emailExists)
            return BadRequest(new { message = "El email ya está en uso" });

        if (dto.AreaId.HasValue)
        {
            var areaExists = await _context.Areas.AnyAsync(a => a.Id == dto.AreaId.Value);
            if (!areaExists)
                return BadRequest(new { message = "El área especificada no existe" });
        }

        var usuario = new Usuario
        {
            NombreUsuario = nombreUsuario,
            NombreCompleto = dto.NombreCompleto.Trim(),
            Email = email,
            PasswordHash = HashPassword(dto.Password),
            Rol = rolParsed.Value,
            AreaId = dto.AreaId,
            Activo = dto.Activo ?? true,
            FechaRegistro = DateTime.UtcNow,
            FechaActualizacion = DateTime.UtcNow,
        };

        _context.Usuarios.Add(usuario);
        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException ex)
        {
            return StatusCode(StatusCodes.Status500InternalServerError, new
            {
                message = "Error guardando usuario en BD. Verifica que tu tabla 'usuarios' tenga las columnas esperadas por el backend (uuid, ultimo_acceso, intentos_fallidos, bloqueado_hasta, fecha_actualizacion).",
                error = ex.Message
            });
        }

        return CreatedAtAction(nameof(GetById), new { id = usuario.Id }, new
        {
            usuario.Id,
            usuario.NombreUsuario,
            usuario.NombreCompleto,
            usuario.Email,
            Rol = usuario.Rol.ToString(),
            usuario.AreaId,
            usuario.Activo,
            usuario.FechaRegistro,
            usuario.FechaActualizacion
        });
    }

    [HttpGet("{id}")]
    public async Task<ActionResult> GetById(int id)
    {
        var usuario = await _context.Usuarios
            .Include(u => u.Area)
            .Where(u => u.Id == id)
            .Select(u => new
            {
                u.Id,
                u.NombreUsuario,
                u.NombreCompleto,
                u.Email,
                Rol = u.Rol.ToString(),
                u.AreaId,
                AreaNombre = u.Area != null ? u.Area.Nombre : null,
                u.Activo,
                u.UltimoAcceso,
                u.IntentosFallidos,
                u.BloqueadoHasta,
                u.FechaRegistro,
                u.FechaActualizacion
            })
            .FirstOrDefaultAsync();

        if (usuario == null)
            return NotFound();

        return Ok(usuario);
    }

    [HttpPut("{id}/rol")]
    public async Task<ActionResult> UpdateRol(int id, [FromBody] UpdateRolDTO dto)
    {
        var usuario = await _context.Usuarios.FindAsync(id);
        if (usuario == null)
            return NotFound();

        if (!RolesValidos.Contains(dto.Rol))
            return BadRequest(new { message = $"Rol inválido. Roles permitidos: {string.Join(", ", RolesValidos)}" });

        var parsed = ParseRolOrNull(dto.Rol);
        if (parsed == null)
            return BadRequest(new { message = $"Rol inválido. Roles permitidos: {string.Join(", ", RolesValidos)}" });

        usuario.Rol = parsed.Value;
        usuario.FechaActualizacion = DateTime.UtcNow;

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException ex)
        {
            return StatusCode(StatusCodes.Status500InternalServerError, new
            {
                message = "Error actualizando usuario en BD. Verifica esquema de tabla 'usuarios' (fecha_actualizacion/ultimo_acceso/intentos_fallidos/bloqueado_hasta).",
                error = ex.Message
            });
        }

        return Ok(new
        {
            usuario.Id,
            usuario.NombreUsuario,
            usuario.NombreCompleto,
            Rol = usuario.Rol.ToString(),
            usuario.FechaActualizacion
        });
    }

    [HttpPut("{id}/estado")]
    public async Task<ActionResult> UpdateEstado(int id, [FromBody] UpdateEstadoDTO dto)
    {
        var usuario = await _context.Usuarios.FindAsync(id);
        if (usuario == null)
            return NotFound();

        usuario.Activo = dto.Activo;
        usuario.FechaActualizacion = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        return Ok(new
        {
            usuario.Id,
            usuario.NombreUsuario,
            usuario.NombreCompleto,
            usuario.Activo,
            usuario.FechaActualizacion
        });
    }

    [HttpPut("{id}")]
    public async Task<ActionResult> UpdateUsuario(int id, [FromBody] UpdateUsuarioDTO dto)
    {
        var usuario = await _context.Usuarios.FindAsync(id);
        if (usuario == null)
            return NotFound();

        if (!string.IsNullOrEmpty(dto.NombreCompleto))
            usuario.NombreCompleto = dto.NombreCompleto;

        if (!string.IsNullOrEmpty(dto.Email))
        {
            // Verificar que el email no esté en uso por otro usuario
            var emailExists = await _context.Usuarios
                .AnyAsync(u => u.Email == dto.Email && u.Id != id);
            if (emailExists)
                return BadRequest(new { message = "El email ya está en uso" });

            usuario.Email = dto.Email;
        }

        if (dto.Rol != null)
        {
            if (!RolesValidos.Contains(dto.Rol))
                return BadRequest(new { message = $"Rol inválido. Roles permitidos: {string.Join(", ", RolesValidos)}" });

            var parsed = ParseRolOrNull(dto.Rol);
            if (parsed == null)
                return BadRequest(new { message = $"Rol inválido. Roles permitidos: {string.Join(", ", RolesValidos)}" });

            usuario.Rol = parsed.Value;
        }

        if (dto.AreaId.HasValue)
        {
            var areaExists = await _context.Areas.AnyAsync(a => a.Id == dto.AreaId.Value);
            if (!areaExists)
                return BadRequest(new { message = "El área especificada no existe" });
            usuario.AreaId = dto.AreaId.Value;
        }

        if (dto.Activo.HasValue)
            usuario.Activo = dto.Activo.Value;

        if (!string.IsNullOrWhiteSpace(dto.Password))
        {
            usuario.PasswordHash = HashPassword(dto.Password);
        }

        usuario.FechaActualizacion = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        return Ok(new
        {
            usuario.Id,
            usuario.NombreUsuario,
            usuario.NombreCompleto,
            usuario.Email,
            Rol = usuario.Rol.ToString(),
            usuario.AreaId,
            usuario.Activo,
            usuario.FechaActualizacion
        });
    }

    [HttpDelete("{id}")]
    public async Task<ActionResult> DeleteUsuario(int id, [FromQuery] bool hard = false)
    {
        var usuario = await _context.Usuarios.FindAsync(id);
        if (usuario == null)
            return NotFound();

        if (!hard)
        {
            usuario.Activo = false;
            usuario.FechaActualizacion = DateTime.UtcNow;
            await _context.SaveChangesAsync();
            return Ok(new { usuario.Id, usuario.Activo, usuario.FechaActualizacion });
        }

        _context.Usuarios.Remove(usuario);
        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException)
        {
            return BadRequest(new
            {
                message = "No se pudo eliminar el usuario (tiene relaciones). Usa eliminación lógica (hard=false) o desvincula sus registros primero."
            });
        }

        return NoContent();
    }

    [Authorize(Roles = "AdministradorSistema,Administrador")]
    [HttpPost("sincronizar")]
    public async Task<ActionResult> SincronizarUsuarios(CancellationToken cancellationToken)
    {
        var startedAt = DateTime.UtcNow;
        var institutionalConnection = _configuration.GetConnectionString("InstitutionalConnection")
            ?? _configuration.GetConnectionString("DefaultConnection");

        if (string.IsNullOrWhiteSpace(institutionalConnection))
        {
            return StatusCode(StatusCodes.Status500InternalServerError, new
            {
                message = "No hay connection string configurado para InstitutionalConnection/DefaultConnection"
            });
        }

        var usuariosProcesados = 0;
        var usuariosActualizados = 0;
        var errores = 0;

        try
        {
            var sourceUsers = new Dictionary<string, SourceUsuario>(StringComparer.Ordinal);
            await using (var conn = new NpgsqlConnection(institutionalConnection))
            {
                await conn.OpenAsync(cancellationToken);

                const string sql = @"
SELECT
  nombre_usuario,
  nombre_completo,
  email,
  rol,
  area_id,
  activo
FROM usuarios";

                await using var cmd = new NpgsqlCommand(sql, conn);
                await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);

                while (await reader.ReadAsync(cancellationToken))
                {
                    var nombreUsuario = reader.GetString(0);
                    var nombreCompleto = reader.IsDBNull(1) ? string.Empty : reader.GetString(1);
                    var email = reader.IsDBNull(2) ? string.Empty : reader.GetString(2);
                    var rol = reader.IsDBNull(3) ? "Usuario" : reader.GetString(3);
                    var areaId = reader.IsDBNull(4) ? (int?)null : reader.GetInt32(4);
                    var activo = !reader.IsDBNull(5) && reader.GetBoolean(5);

                    if (string.IsNullOrWhiteSpace(nombreUsuario))
                        continue;

                    sourceUsers[nombreUsuario.Trim()] = new SourceUsuario
                    {
                        NombreUsuario = nombreUsuario.Trim(),
                        NombreCompleto = nombreCompleto?.Trim() ?? string.Empty,
                        Email = email?.Trim() ?? string.Empty,
                        Rol = string.IsNullOrWhiteSpace(rol) ? "Usuario" : rol.Trim(),
                        AreaId = areaId,
                        Activo = activo,
                    };
                }
            }

            usuariosProcesados = sourceUsers.Count;

            var localUsers = await _context.Usuarios.ToListAsync(cancellationToken);
            var localByUsername = localUsers
                .Where(u => !string.IsNullOrWhiteSpace(u.NombreUsuario))
                .ToDictionary(u => u.NombreUsuario, u => u, StringComparer.Ordinal);

            // Upsert from source
            foreach (var kvp in sourceUsers)
            {
                var src = kvp.Value;

                if (!RolesValidos.Contains(src.Rol))
                {
                    // Si el rol no está en el catálogo del sistema, lo degradamos a Usuario
                    src.Rol = nameof(UsuarioRol.Usuario);
                }

                var srcRol = ParseRolOrNull(src.Rol) ?? UsuarioRol.Usuario;

                if (localByUsername.TryGetValue(src.NombreUsuario, out var local))
                {
                    var changed = false;
                    if (!string.Equals(local.NombreCompleto ?? string.Empty, src.NombreCompleto, StringComparison.Ordinal))
                    {
                        local.NombreCompleto = src.NombreCompleto;
                        changed = true;
                    }
                    if (!string.Equals(local.Email ?? string.Empty, src.Email, StringComparison.Ordinal))
                    {
                        local.Email = src.Email;
                        changed = true;
                    }
                    if (!string.Equals(local.Rol.ToString(), srcRol.ToString(), StringComparison.Ordinal))
                    {
                        local.Rol = srcRol;
                        changed = true;
                    }
                    if (local.AreaId != src.AreaId)
                    {
                        local.AreaId = src.AreaId;
                        changed = true;
                    }
                    if (local.Activo != src.Activo)
                    {
                        local.Activo = src.Activo;
                        changed = true;
                    }

                    if (changed)
                    {
                        local.FechaActualizacion = DateTime.UtcNow;
                        usuariosActualizados++;
                    }
                }
                else
                {
                    // Crear usuario si no existe localmente.
                    // Password: random (admin debe asignar luego si quiere que inicie sesión).
                    var randomPassword = Guid.NewGuid().ToString("N");
                    var newUser = new Usuario
                    {
                        NombreUsuario = src.NombreUsuario,
                        NombreCompleto = string.IsNullOrWhiteSpace(src.NombreCompleto) ? src.NombreUsuario : src.NombreCompleto,
                        Email = string.IsNullOrWhiteSpace(src.Email) ? $"{src.NombreUsuario}@local" : src.Email,
                        Rol = srcRol,
                        AreaId = src.AreaId,
                        Activo = src.Activo,
                        PasswordHash = HashPassword(randomPassword),
                        FechaRegistro = DateTime.UtcNow,
                        FechaActualizacion = DateTime.UtcNow,
                    };
                    _context.Usuarios.Add(newUser);
                    usuariosActualizados++;
                }
            }

            // Deactivate local users missing in source (keep visible)
            foreach (var local in localUsers)
            {
                if (string.IsNullOrWhiteSpace(local.NombreUsuario))
                    continue;

                if (!sourceUsers.ContainsKey(local.NombreUsuario) && local.Activo)
                {
                    local.Activo = false;
                    local.FechaActualizacion = DateTime.UtcNow;
                    usuariosActualizados++;
                }
            }

            try
            {
                await _context.SaveChangesAsync(cancellationToken);
            }
            catch (DbUpdateException ex)
            {
                errores = 1;
                return StatusCode(StatusCodes.Status500InternalServerError, new
                {
                    id = Guid.NewGuid().ToString("N"),
                    fecha = startedAt.ToString("O"),
                    estado = "fallido",
                    usuariosProcesados,
                    usuariosActualizados,
                    errores,
                    mensaje = $"Error guardando cambios de sincronización en BD: {ex.Message}"
                });
            }

            return Ok(new
            {
                id = Guid.NewGuid().ToString("N"),
                fecha = startedAt.ToString("O"),
                estado = "exitoso",
                usuariosProcesados,
                usuariosActualizados,
                errores,
                mensaje = "Sincronización completada"
            });
        }
        catch (Exception ex)
        {
            errores = 1;
            return StatusCode(StatusCodes.Status500InternalServerError, new
            {
                id = Guid.NewGuid().ToString("N"),
                fecha = startedAt.ToString("O"),
                estado = "fallido",
                usuariosProcesados,
                usuariosActualizados,
                errores,
                mensaje = $"Error en sincronización: {ex.Message}"
            });
        }
    }

    private static string HashPassword(string password)
    {
        const int iterations = 100_000;
        Span<byte> salt = stackalloc byte[16];
        RandomNumberGenerator.Fill(salt);

        using var pbkdf2 = new Rfc2898DeriveBytes(
            password,
            salt.ToArray(),
            iterations,
            HashAlgorithmName.SHA256
        );

        var hash = pbkdf2.GetBytes(32);
        return $"pbkdf2${iterations}${Convert.ToBase64String(salt)}${Convert.ToBase64String(hash)}";
    }

    private sealed class SourceUsuario
    {
        public string NombreUsuario { get; set; } = string.Empty;
        public string NombreCompleto { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string Rol { get; set; } = "Usuario";
        public int? AreaId { get; set; }
        public bool Activo { get; set; }
    }
}

public class UpdateRolDTO
{
    public string Rol { get; set; } = string.Empty;
}

public class UpdateEstadoDTO
{
    public bool Activo { get; set; }
}

public class CreateUsuarioDTO
{
    public string NombreUsuario { get; set; } = string.Empty;
    public string NombreCompleto { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string? Rol { get; set; }
    public int? AreaId { get; set; }
    public bool? Activo { get; set; }
}

public class UpdateUsuarioDTO
{
    public string? NombreCompleto { get; set; }
    public string? Email { get; set; }
    public string? Password { get; set; }
    public string? Rol { get; set; }
    public int? AreaId { get; set; }
    public bool? Activo { get; set; }
}

