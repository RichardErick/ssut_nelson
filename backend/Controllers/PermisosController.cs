using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using SistemaGestionDocumental.Data;
using SistemaGestionDocumental.Models;

namespace SistemaGestionDocumental.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class PermisosController : ControllerBase
{
    private readonly ApplicationDbContext _context;

    public PermisosController(ApplicationDbContext context)
    {
        _context = context;
    }

    // GET: api/permisos
    [HttpGet]
    [Authorize(Roles = "AdministradorSistema,Administrador")]
    public async Task<ActionResult<IEnumerable<object>>> GetAll()
    {
        try
        {
            var permisos = await _context.Permisos
                .Where(p => p.Activo)
                .OrderBy(p => p.Modulo)
                .ThenBy(p => p.Nombre)
                .Select(p => new
                {
                    p.Id,
                    p.Codigo,
                    p.Nombre,
                    p.Descripcion,
                    p.Modulo,
                    p.Activo
                })
                .ToListAsync();

            return Ok(permisos);
        }
        catch
        {
            return Ok(new List<object>());
        }
    }

    // GET: api/permisos/usuario
    [HttpGet("usuario")]
    public async Task<ActionResult<object>> GetPermisosUsuario()
    {
        try
        {
            var usuarioIdClaim = User.FindFirst("sub")?.Value;
            if (string.IsNullOrEmpty(usuarioIdClaim) || !int.TryParse(usuarioIdClaim, out var usuarioId))
            {
                return Unauthorized(new { message = "Usuario no autenticado" });
            }

            var usuario = await _context.Usuarios.FindAsync(usuarioId);
            if (usuario == null)
            {
                return NotFound(new { message = "Usuario no encontrado" });
            }

            // Obtener el rol del usuario (normalizar AdministradorSistema)
            var rol = usuario.Rol.ToString();
            if (rol == "Administrador")
            {
                rol = "AdministradorSistema";
            }

            var permisos = await _context.RolPermisos
                .Where(rp => rp.Rol == rol && rp.Activo)
                .Include(rp => rp.Permiso)
                .Where(rp => rp.Permiso.Activo)
                .Select(rp => new
                {
                    rp.Permiso.Id,
                    rp.Permiso.Codigo,
                    rp.Permiso.Nombre,
                    rp.Permiso.Descripcion,
                    rp.Permiso.Modulo
                })
                .ToListAsync();

            return Ok(new { permisos });
        }
        catch
        {
            return Ok(new { permisos = new List<object>() });
        }
    }

    // GET: api/permisos/roles
    [HttpGet("roles")]
    [Authorize(Roles = "AdministradorSistema,Administrador")]
    public ActionResult<object> GetRolesPermisos()
    {
        var roles = new[] { "AdministradorSistema", "AdministradorDocumentos", "Contador", "Gerente" };
        
        // Respuesta vacía por defecto
        var emptyResponse = new 
        { 
            roles, 
            permisos = new List<object>(), 
            matriz = roles.Select(rol => new
            {
                rol,
                permisos = new List<object>()
            }).ToList()
        };

        // Envolver TODO en try-catch para asegurar respuesta siempre
        try
        {
            // Verificar conexión
            if (!_context.Database.CanConnect())
            {
                return Ok(emptyResponse);
            }

            // Intentar obtener datos
            var result = Task.Run(async () =>
            {
                try
                {
                    var permisos = await _context.Permisos
                        .Where(p => p.Activo)
                        .OrderBy(p => p.Modulo)
                        .ThenBy(p => p.Nombre)
                        .ToListAsync();

                    var rolPermisos = await _context.RolPermisos
                        .Where(rp => rp.Activo)
                        .Include(rp => rp.Permiso)
                        .ToListAsync();

                    var matriz = roles.Select(rol => new
                    {
                        rol,
                        permisos = permisos.Select(permiso => new
                        {
                            permiso.Id,
                            permiso.Codigo,
                            permiso.Nombre,
                            tienePermiso = rolPermisos.Any(rp => rp.Rol == rol && rp.PermisoId == permiso.Id && rp.Activo)
                        }).ToList()
                    }).ToList();

                    return new { roles, permisos, matriz };
                }
                catch
                {
                    return emptyResponse;
                }
            }).GetAwaiter().GetResult();

            return Ok(result);
        }
        catch
        {
            return Ok(emptyResponse);
        }
    }

    // POST: api/permisos/asignar
    [HttpPost("asignar")]
    [Authorize(Roles = "AdministradorSistema,Administrador")]
    public async Task<ActionResult> AsignarPermiso([FromBody] AsignarPermisoDTO dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Rol) || dto.PermisoId <= 0)
        {
            return BadRequest(new { message = "Rol y PermisoId son requeridos" });
        }

        try
        {
            var permiso = await _context.Permisos.FindAsync(dto.PermisoId);
            if (permiso == null)
            {
                return NotFound(new { message = "Permiso no encontrado" });
            }

            var rolPermiso = await _context.RolPermisos
                .FirstOrDefaultAsync(rp => rp.Rol == dto.Rol && rp.PermisoId == dto.PermisoId);

            if (rolPermiso == null)
            {
                rolPermiso = new RolPermiso
                {
                    Rol = dto.Rol,
                    PermisoId = dto.PermisoId,
                    Activo = true,
                    FechaAsignacion = DateTime.UtcNow
                };
                _context.RolPermisos.Add(rolPermiso);
            }
            else
            {
                rolPermiso.Activo = true;
                _context.RolPermisos.Update(rolPermiso);
            }

            await _context.SaveChangesAsync();

            return Ok(new { message = "Permiso asignado correctamente", rolPermiso });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { message = $"Error al asignar permiso: {ex.Message}" });
        }
    }

    // POST: api/permisos/revocar
    [HttpPost("revocar")]
    [Authorize(Roles = "AdministradorSistema,Administrador")]
    public async Task<ActionResult> RevocarPermiso([FromBody] AsignarPermisoDTO dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Rol) || dto.PermisoId <= 0)
        {
            return BadRequest(new { message = "Rol y PermisoId son requeridos" });
        }

        try
        {
            var rolPermiso = await _context.RolPermisos
                .FirstOrDefaultAsync(rp => rp.Rol == dto.Rol && rp.PermisoId == dto.PermisoId);

            if (rolPermiso == null)
            {
                return NotFound(new { message = "Permiso no asignado a este rol" });
            }

            rolPermiso.Activo = false;
            _context.RolPermisos.Update(rolPermiso);
            await _context.SaveChangesAsync();

            return Ok(new { message = "Permiso revocado correctamente" });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { message = $"Error al revocar permiso: {ex.Message}" });
        }
    }

    // POST: api/permisos/bulk-asignar
    [HttpPost("bulk-asignar")]
    [Authorize(Roles = "AdministradorSistema,Administrador")]
    public async Task<ActionResult> BulkAsignarPermisos([FromBody] BulkAsignarPermisosDTO dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Rol) || dto.PermisoIds == null || !dto.PermisoIds.Any())
        {
            return BadRequest(new { message = "Rol y lista de PermisoIds son requeridos" });
        }

        try
        {
            // Obtener permisos existentes para este rol
            var permisosExistentes = await _context.RolPermisos
                .Where(rp => rp.Rol == dto.Rol)
                .ToListAsync();

            // Desactivar todos los permisos actuales
            foreach (var permisoExistente in permisosExistentes)
            {
                permisoExistente.Activo = false;
            }

            // Activar o crear los nuevos permisos
            foreach (var permisoId in dto.PermisoIds)
            {
                var permisoExistente = permisosExistentes.FirstOrDefault(rp => rp.PermisoId == permisoId);
                
                if (permisoExistente != null)
                {
                    permisoExistente.Activo = true;
                    permisoExistente.FechaAsignacion = DateTime.UtcNow;
                }
                else
                {
                    var nuevoRolPermiso = new RolPermiso
                    {
                        Rol = dto.Rol,
                        PermisoId = permisoId,
                        Activo = true,
                        FechaAsignacion = DateTime.UtcNow
                    };
                    _context.RolPermisos.Add(nuevoRolPermiso);
                }
            }

            await _context.SaveChangesAsync();

            return Ok(new { message = "Permisos actualizados correctamente" });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { message = $"Error al actualizar permisos: {ex.Message}" });
        }
    }
}

// DTOs
public class AsignarPermisoDTO
{
    public string Rol { get; set; } = string.Empty;
    public int PermisoId { get; set; }
}

public class BulkAsignarPermisosDTO
{
    public string Rol { get; set; } = string.Empty;
    public List<int> PermisoIds { get; set; } = new();
}
