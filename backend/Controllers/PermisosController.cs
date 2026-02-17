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
    [Authorize(Roles = "AdministradorSistema")]
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

            var permisosRolIds = await _context.RolPermisos
                .Where(rp => rp.Rol == rol && rp.Activo)
                .Select(rp => rp.PermisoId)
                .ToListAsync();

            // Asignaciones explícitas al usuario (solo grants, no denegados)
            var permisosUsuarioGrantedIds = await _context.UsuarioPermisos
                .Where(up => up.UsuarioId == usuarioId && up.Activo && !up.Denegado)
                .Select(up => up.PermisoId)
                .ToListAsync();

            // Permisos denegados explícitamente (revocados desde admin)
            var permisosUsuarioDeniedIds = await _context.UsuarioPermisos
                .Where(up => up.UsuarioId == usuarioId && up.Activo && up.Denegado)
                .Select(up => up.PermisoId)
                .ToListAsync();

            var deniedSet = new HashSet<int>(permisosUsuarioDeniedIds);

            // El usuario tiene el permiso si: (lo tiene por rol O asignado explícitamente) Y NO está denegado
            var permisoIds = permisosRolIds
                .Union(permisosUsuarioGrantedIds)
                .Where(id => !deniedSet.Contains(id))
                .Distinct()
                .ToList();

            var permisos = await _context.Permisos
                .Where(p => p.Activo && permisoIds.Contains(p.Id))
                .Select(p => new
                {
                    p.Id,
                    p.Codigo,
                    p.Nombre,
                    p.Descripcion,
                    p.Modulo
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
    [Authorize(Roles = "AdministradorSistema")]
    public async Task<ActionResult<object>> GetRolesPermisos()
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

                return Ok(new { roles, permisos, matriz });
            }
            catch
            {
                return Ok(emptyResponse);
            }
        }
        catch
        {
            return Ok(emptyResponse);
        }
    }

    // GET: api/permisos/usuarios/{id}
    [HttpGet("usuarios/{id}")]
    [Authorize(Roles = "AdministradorSistema")]
    public async Task<ActionResult<object>> GetPermisosUsuarioAdmin(int id)
    {
        try
        {
            var usuario = await _context.Usuarios.FindAsync(id);
            if (usuario == null)
            {
                return NotFound(new { message = "Usuario no encontrado" });
            }

            var rol = usuario.Rol.ToString();
            if (rol == "Administrador")
            {
                rol = "AdministradorSistema";
            }

            var permisosRolIds = await _context.RolPermisos
                .Where(rp => rp.Rol == rol && rp.Activo)
                .Select(rp => rp.PermisoId)
                .ToListAsync();

            // Incluir permisos denegados en la consulta
            var permisosUsuario = await _context.UsuarioPermisos
                .Where(up => up.UsuarioId == id && up.Activo)
                .Select(up => new { up.PermisoId, up.Denegado })
                .ToListAsync();

            var permisosUsuarioGrantedIds = permisosUsuario.Where(p => !p.Denegado).Select(p => p.PermisoId).ToList();
            var permisosUsuarioDeniedIds = permisosUsuario.Where(p => p.Denegado).Select(p => p.PermisoId).ToList();

            var rolSet = new HashSet<int>(permisosRolIds);
            var usuarioGrantedSet = new HashSet<int>(permisosUsuarioGrantedIds);
            var usuarioDeniedSet = new HashSet<int>(permisosUsuarioDeniedIds);

            // Mostrar TODOS los permisos activos del catálogo
            var permisos = await _context.Permisos
                .Where(p => p.Activo)
                .OrderBy(p => p.Modulo)
                .ThenBy(p => p.Nombre)
                .ToListAsync();
 
            var response = permisos.Select(p => new
            {
                p.Id,
                p.Codigo,
                p.Nombre,
                p.Descripcion,
                p.Modulo,
                p.Activo,
                roleHas = rolSet.Contains(p.Id),
                // Tiene el permiso si: (Lo tiene por rol y NO está denegado) O (Se le asignó explícitamente)
                userHas = (rolSet.Contains(p.Id) && !usuarioDeniedSet.Contains(p.Id)) || usuarioGrantedSet.Contains(p.Id),
                isDenied = usuarioDeniedSet.Contains(p.Id)
            }).ToList();
 
            return Ok(new { usuarioId = id, rol, permisos = response });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { message = $"Error al obtener permisos: {ex.Message}" });
        }
    }

    // ... (AsignarPermiso and RevocarPermiso for ROLES remain unchanged) ...

    // POST: api/permisos/usuarios/asignar
    [HttpPost("usuarios/asignar")]
    [Authorize(Roles = "AdministradorSistema")]
    public async Task<ActionResult> AsignarPermisoUsuario([FromBody] AsignarPermisoUsuarioDTO dto)
    {
        if (dto.UsuarioId <= 0 || dto.PermisoId <= 0)
        {
            return BadRequest(new { message = "UsuarioId y PermisoId son requeridos" });
        }

        try
        {
            var usuarioPermiso = await _context.UsuarioPermisos
                .FirstOrDefaultAsync(up => up.UsuarioId == dto.UsuarioId && up.PermisoId == dto.PermisoId);

            if (usuarioPermiso == null)
            {
                usuarioPermiso = new UsuarioPermiso
                {
                    UsuarioId = dto.UsuarioId,
                    PermisoId = dto.PermisoId,
                    Activo = true,
                    Denegado = false, // Grant
                    FechaAsignacion = DateTime.UtcNow
                };
                _context.UsuarioPermisos.Add(usuarioPermiso);
            }
            else
            {
                usuarioPermiso.Activo = true;
                usuarioPermiso.Denegado = false; // Ensure it's not denied
                usuarioPermiso.FechaAsignacion = DateTime.UtcNow;
                _context.UsuarioPermisos.Update(usuarioPermiso);
            }

            await _context.SaveChangesAsync();

            return Ok(new { message = "Permiso asignado al usuario correctamente" });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { message = $"Error al asignar permiso: {ex.Message}" });
        }
    }

    // POST: api/permisos/usuarios/revocar
    [HttpPost("usuarios/revocar")]
    [Authorize(Roles = "AdministradorSistema")]
    public async Task<ActionResult> RevocarPermisoUsuario([FromBody] AsignarPermisoUsuarioDTO dto)
    {
        if (dto.UsuarioId <= 0 || dto.PermisoId <= 0)
        {
            return BadRequest(new { message = "UsuarioId y PermisoId son requeridos" });
        }

        try
        {
            var usuario = await _context.Usuarios.FindAsync(dto.UsuarioId);
            if (usuario == null) return NotFound("Usuario no encontrado");

            // Check if user has permission via ROLE
            var rol = usuario.Rol.ToString();
            if (rol == "Administrador") rol = "AdministradorSistema";

            var hasRolePermission = await _context.RolPermisos
                .AnyAsync(rp => rp.Rol == rol && rp.PermisoId == dto.PermisoId && rp.Activo);

            var usuarioPermiso = await _context.UsuarioPermisos
                .FirstOrDefaultAsync(up => up.UsuarioId == dto.UsuarioId && up.PermisoId == dto.PermisoId);

            if (hasRolePermission)
            {
                // If they have it via role, we must EXPLICITLY DENY it
                if (usuarioPermiso == null)
                {
                    usuarioPermiso = new UsuarioPermiso
                    {
                        UsuarioId = dto.UsuarioId,
                        PermisoId = dto.PermisoId,
                        Activo = true,
                        Denegado = true, // Explicit Deny
                        FechaAsignacion = DateTime.UtcNow
                    };
                    _context.UsuarioPermisos.Add(usuarioPermiso);
                }
                else
                {
                    usuarioPermiso.Activo = true;
                    usuarioPermiso.Denegado = true; // Turn into Deny
                    _context.UsuarioPermisos.Update(usuarioPermiso);
                }
                await _context.SaveChangesAsync();
                return Ok(new { message = "Permiso denegado explícitamente (sobreescribe rol)" });
            }
            else
            {
                // If they only have it via user assignment, just deactivate it
                if (usuarioPermiso == null)
                {
                    return Ok(new { message = "El permiso ya se encuentra revocado o no estaba asignado" });
                }

                usuarioPermiso.Activo = false; // Soft delete
                usuarioPermiso.Denegado = false; // Reset Deny status just in case
                _context.UsuarioPermisos.Update(usuarioPermiso);
                await _context.SaveChangesAsync();
                return Ok(new { message = "Permiso revocado correctamente" });
            }
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { message = $"Error al revocar permiso: {ex.Message}" });
        }
    }
    // GET: api/permisos/global/movimientos
    [HttpGet("global/movimientos")]
    [Authorize(Roles = "AdministradorSistema")]
    public async Task<ActionResult<bool>> GetMovimientosGlobalStatus()
    {
        var permiso = await _context.Permisos.FirstOrDefaultAsync(p => p.Codigo == "ver_movimientos");
        if (permiso == null) return Ok(false); 
        
        // Verifica si el rol 'Gerente' (rol base de menor privilegio) tiene acceso.
        var hasPermission = await _context.RolPermisos
            .AnyAsync(rp => rp.Rol == "Gerente" && rp.PermisoId == permiso.Id && rp.Activo);
            
        return Ok(hasPermission);
    }

    // POST: api/permisos/global/movimientos/toggle
    [HttpPost("global/movimientos/toggle")]
    [Authorize(Roles = "AdministradorSistema")]
    public async Task<ActionResult> ToggleMovimientosGlobal([FromBody] ToggleGlobalDTO dto)
    {
        try 
        {
            var permiso = await _context.Permisos.FirstOrDefaultAsync(p => p.Codigo == "ver_movimientos");
            if (permiso == null) 
            {
               permiso = new Permiso { 
                   Codigo = "ver_movimientos", 
                   Nombre = "Ver Movimientos", 
                   Descripcion = "Permite ver el historial de movimientos de documentos",
                   Modulo = "Movimientos",
                   Activo = true 
               };
               _context.Permisos.Add(permiso);
               await _context.SaveChangesAsync();
            }

            var rolesTarget = new[] { "AdministradorDocumentos", "Contador", "Gerente" };
            
            var rolPermisos = await _context.RolPermisos
                .Where(rp => rolesTarget.Contains(rp.Rol) && rp.PermisoId == permiso.Id)
                .ToListAsync();

            if (dto.Habilitar)
            {
                foreach (var rol in rolesTarget)
                {
                    var rp = rolPermisos.FirstOrDefault(x => x.Rol == rol);
                    if (rp == null)
                    {
                        _context.RolPermisos.Add(new RolPermiso { Rol = rol, PermisoId = permiso.Id, Activo = true });
                    }
                    else
                    {
                         rp.Activo = true;
                         _context.RolPermisos.Update(rp);
                    }
                }
            }
            else
            {
                foreach(var rp in rolPermisos)
                {
                    rp.Activo = false;
                    _context.RolPermisos.Update(rp);
                }
            }
            
            var adminRp = await _context.RolPermisos.FirstOrDefaultAsync(rp => rp.Rol == "AdministradorSistema" && rp.PermisoId == permiso.Id);
            if (adminRp == null)
            {
                 _context.RolPermisos.Add(new RolPermiso { Rol = "AdministradorSistema", PermisoId = permiso.Id, Activo = true });
            }
            else if (!adminRp.Activo)
            {
                adminRp.Activo = true;
                _context.RolPermisos.Update(adminRp);
            }

            await _context.SaveChangesAsync();
            return Ok(new { message = $"Permiso de movimientos global {(dto.Habilitar ? "habilitado" : "deshabilitado")}" });
        }
        catch (Exception ex)
        {
             return StatusCode(500, new { message = $"Error: {ex.Message}" });
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

public class AsignarPermisoUsuarioDTO
{
    public int UsuarioId { get; set; }
    public int PermisoId { get; set; }
}

public class ToggleGlobalDTO
{
    public bool Habilitar { get; set; }
}
