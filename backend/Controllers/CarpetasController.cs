using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SistemaGestionDocumental.Data;
using SistemaGestionDocumental.Models;

namespace SistemaGestionDocumental.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CarpetasController : ControllerBase
{
    private readonly ApplicationDbContext _context;

    public CarpetasController(ApplicationDbContext context)
    {
        _context = context;
    }

    // GET: api/carpetas
    [HttpGet]
    public async Task<ActionResult> GetAll(
        [FromQuery] string? gestion = null,
        [FromQuery] bool incluirInactivas = false)
    {
        var query = _context.Carpetas
            .Include(c => c.CarpetaPadre)
            .Include(c => c.Subcarpetas)
            .Include(c => c.UsuarioCreacion)
            .AsQueryable();

        if (!incluirInactivas)
        {
            query = query.Where(c => c.Activo);
        }

        if (!string.IsNullOrWhiteSpace(gestion))
        {
            query = query.Where(c => c.Gestion == gestion);
        }

        var carpetas = await query
            .OrderBy(c => c.Gestion)
            .ThenBy(c => c.CarpetaPadreId)
            .ThenBy(c => c.Nombre)
            .Select(c => new
            {
                c.Id,
                c.Nombre,
                c.Codigo,
                c.Gestion,
                c.Descripcion,
                c.CarpetaPadreId,
                CarpetaPadreNombre = c.CarpetaPadre != null ? c.CarpetaPadre.Nombre : null,
                c.Activo,
                c.FechaCreacion,
                UsuarioCreacionNombre = c.UsuarioCreacion != null ? c.UsuarioCreacion.NombreCompleto : null,
                NumeroSubcarpetas = c.Subcarpetas.Count,
                NumeroDocumentos = c.Documentos.Count
            })
            .ToListAsync();

        return Ok(carpetas);
    }

    // GET: api/carpetas/{id}
    [HttpGet("{id}")]
    public async Task<ActionResult> GetById(int id)
    {
        var carpeta = await _context.Carpetas
            .Include(c => c.CarpetaPadre)
            .Include(c => c.Subcarpetas)
            .Include(c => c.UsuarioCreacion)
            .Where(c => c.Id == id)
            .Select(c => new
            {
                c.Id,
                c.Nombre,
                c.Codigo,
                c.Gestion,
                c.Descripcion,
                c.CarpetaPadreId,
                CarpetaPadreNombre = c.CarpetaPadre != null ? c.CarpetaPadre.Nombre : null,
                c.Activo,
                c.FechaCreacion,
                c.UsuarioCreacionId,
                UsuarioCreacionNombre = c.UsuarioCreacion != null ? c.UsuarioCreacion.NombreCompleto : null,
                Subcarpetas = c.Subcarpetas.Select(sc => new
                {
                    sc.Id,
                    sc.Nombre,
                    sc.Codigo,
                    sc.Activo
                }).ToList(),
                NumeroDocumentos = c.Documentos.Count
            })
            .FirstOrDefaultAsync();

        if (carpeta == null)
            return NotFound(new { message = "Carpeta no encontrada" });

        return Ok(carpeta);
    }

    // GET: api/carpetas/arbol/{gestion}
    [HttpGet("arbol/{gestion}")]
    public async Task<ActionResult> GetArbol(string gestion)
    {
        var carpetas = await _context.Carpetas
            .Where(c => c.Gestion == gestion && c.Activo)
            .Include(c => c.Subcarpetas.Where(sc => sc.Activo))
            .Where(c => c.CarpetaPadreId == null) // Solo carpetas raíz
            .Select(c => new
            {
                c.Id,
                c.Nombre,
                c.Codigo,
                c.Gestion,
                c.Descripcion,
                NumeroDocumentos = c.Documentos.Count,
                Subcarpetas = c.Subcarpetas.Select(sc => new
                {
                    sc.Id,
                    sc.Nombre,
                    sc.Codigo,
                    NumeroDocumentos = sc.Documentos.Count
                }).ToList()
            })
            .ToListAsync();

        return Ok(carpetas);
    }

    // POST: api/carpetas
    [HttpPost]
    public async Task<ActionResult> Create([FromBody] CreateCarpetaDTO dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Nombre))
            return BadRequest(new { message = "El nombre es obligatorio" });

        if (string.IsNullOrWhiteSpace(dto.Gestion) || dto.Gestion.Length != 4)
            return BadRequest(new { message = "La gestión debe tener 4 dígitos" });

        // Verificar carpeta padre si se proporciona
        if (dto.CarpetaPadreId.HasValue)
        {
            var carpetaPadre = await _context.Carpetas.FindAsync(dto.CarpetaPadreId.Value);
            if (carpetaPadre == null)
                return BadRequest(new { message = "Carpeta padre no encontrada" });

            if (carpetaPadre.Gestion != dto.Gestion)
                return BadRequest(new { message = "La carpeta padre debe ser de la misma gestión" });
        }

        // Verificar que no exista una carpeta con el mismo nombre, gestión y padre
        var exists = await _context.Carpetas.AnyAsync(c =>
            c.Nombre == dto.Nombre &&
            c.Gestion == dto.Gestion &&
            c.CarpetaPadreId == dto.CarpetaPadreId);

        if (exists)
            return BadRequest(new { message = "Ya existe una carpeta con ese nombre en esta ubicación" });

        var carpeta = new Carpeta
        {
            Nombre = dto.Nombre,
            Codigo = dto.Codigo,
            Gestion = dto.Gestion,
            Descripcion = dto.Descripcion,
            CarpetaPadreId = dto.CarpetaPadreId,
            Activo = true,
            FechaCreacion = DateTime.UtcNow
            // TODO: UsuarioCreacionId = obtener del contexto de autenticación
        };

        _context.Carpetas.Add(carpeta);
        await _context.SaveChangesAsync();

        return CreatedAtAction(nameof(GetById), new { id = carpeta.Id }, new
        {
            carpeta.Id,
            carpeta.Nombre,
            carpeta.Codigo,
            carpeta.Gestion,
            carpeta.FechaCreacion
        });
    }

    // PUT: api/carpetas/{id}
    [HttpPut("{id}")]
    public async Task<ActionResult> Update(int id, [FromBody] UpdateCarpetaDTO dto)
    {
        var carpeta = await _context.Carpetas.FindAsync(id);
        if (carpeta == null)
            return NotFound(new { message = "Carpeta no encontrada" });

        if (!string.IsNullOrWhiteSpace(dto.Nombre))
            carpeta.Nombre = dto.Nombre;

        if (dto.Codigo != null)
            carpeta.Codigo = dto.Codigo;

        if (dto.Descripcion != null)
            carpeta.Descripcion = dto.Descripcion;

        if (dto.Activo.HasValue)
            carpeta.Activo = dto.Activo.Value;

        await _context.SaveChangesAsync();

        return Ok(new
        {
            carpeta.Id,
            carpeta.Nombre,
            carpeta.Codigo,
            message = "Carpeta actualizada exitosamente"
        });
    }

    // DELETE: api/carpetas/{id}
    [HttpDelete("{id}")]
    public async Task<ActionResult> Delete(int id, [FromQuery] bool hard = false)
    {
        var carpeta = await _context.Carpetas
            .Include(c => c.Subcarpetas)
            .Include(c => c.Documentos)
            .FirstOrDefaultAsync(c => c.Id == id);

        if (carpeta == null)
            return NotFound(new { message = "Carpeta no encontrada" });

        if (carpeta.Subcarpetas.Any())
            return BadRequest(new { message = "No se puede eliminar una carpeta con subcarpetas" });

        if (carpeta.Documentos.Any())
            return BadRequest(new { message = "No se puede eliminar una carpeta con documentos" });

        if (!hard)
        {
            carpeta.Activo = false;
            await _context.SaveChangesAsync();
            return Ok(new { message = "Carpeta desactivada" });
        }

        _context.Carpetas.Remove(carpeta);
        await _context.SaveChangesAsync();

        return NoContent();
    }
}

public class CreateCarpetaDTO
{
    public string Nombre { get; set; } = string.Empty;
    public string? Codigo { get; set; }
    public string Gestion { get; set; } = string.Empty;
    public string? Descripcion { get; set; }
    public int? CarpetaPadreId { get; set; }
}

public class UpdateCarpetaDTO
{
    public string? Nombre { get; set; }
    public string? Codigo { get; set; }
    public string? Descripcion { get; set; }
    public bool? Activo { get; set; }
}
