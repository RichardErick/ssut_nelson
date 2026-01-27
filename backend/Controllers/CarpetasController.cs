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
    private const string NombreCarpetaPermitida = "Comprobante de Egreso";
    private const int TamanoRango = 30;
    private const int RangosIniciales = 3;

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

        var carpetaIds = carpetas.Select(c => c.Id).ToList();
        var rangoMap = await ObtenerRangosCorrelativosAsync(carpetaIds, gestion);
        var numeroMap = await ObtenerNumerosCarpetaAsync(carpetaIds, gestion);

        var result = carpetas.Select(c => new
        {
            c.Id,
            c.Nombre,
            c.Codigo,
            c.Gestion,
            c.Descripcion,
            c.CarpetaPadreId,
            c.CarpetaPadreNombre,
            c.Activo,
            c.FechaCreacion,
            c.UsuarioCreacionNombre,
            c.NumeroSubcarpetas,
            c.NumeroDocumentos,
            NumeroCarpeta = numeroMap.TryGetValue(c.Id, out var n) ? n : (int?)null,
            CodigoRomano = numeroMap.TryGetValue(c.Id, out var rn) ? ToRoman(rn) : null,
            RangoInicio = rangoMap.TryGetValue(c.Id, out var r) ? r.Inicio : null,
            RangoFin = rangoMap.TryGetValue(c.Id, out var r2) ? r2.Fin : null
        });

        return Ok(result);
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

        var rangoMap = await ObtenerRangosCorrelativosAsync(new List<int> { id }, carpeta.Gestion);
        var numeroMap = await ObtenerNumerosCarpetaAsync(new List<int> { id }, carpeta.Gestion);

        return Ok(new
        {
            carpeta.Id,
            carpeta.Nombre,
            carpeta.Codigo,
            carpeta.Gestion,
            carpeta.Descripcion,
            carpeta.CarpetaPadreId,
            carpeta.CarpetaPadreNombre,
            carpeta.Activo,
            carpeta.FechaCreacion,
            carpeta.UsuarioCreacionId,
            carpeta.UsuarioCreacionNombre,
            carpeta.Subcarpetas,
            carpeta.NumeroDocumentos,
            NumeroCarpeta = numeroMap.TryGetValue(id, out var n) ? n : (int?)null,
            CodigoRomano = numeroMap.TryGetValue(id, out var rn) ? ToRoman(rn) : null,
            RangoInicio = rangoMap.TryGetValue(id, out var r) ? r.Inicio : null,
            RangoFin = rangoMap.TryGetValue(id, out var r2) ? r2.Fin : null
        });
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

        var carpetaIds = carpetas.Select(c => c.Id).ToList();
        var rangoMap = await ObtenerRangosCorrelativosAsync(carpetaIds, gestion);
        var numeroMap = await ObtenerNumerosCarpetaAsync(carpetaIds, gestion);

        var result = carpetas.Select(c => new
        {
            c.Id,
            c.Nombre,
            c.Codigo,
            c.Gestion,
            c.Descripcion,
            c.NumeroDocumentos,
            c.Subcarpetas,
            NumeroCarpeta = numeroMap.TryGetValue(c.Id, out var n) ? n : (int?)null,
            CodigoRomano = numeroMap.TryGetValue(c.Id, out var rn) ? ToRoman(rn) : null,
            RangoInicio = rangoMap.TryGetValue(c.Id, out var r) ? r.Inicio : null,
            RangoFin = rangoMap.TryGetValue(c.Id, out var r2) ? r2.Fin : null
        });

        return Ok(result);
    }

    // POST: api/carpetas
    [HttpPost]
    public async Task<ActionResult> Create([FromBody] CreateCarpetaDTO dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Nombre))
            return BadRequest(new { message = "El nombre es obligatorio" });

        if (string.IsNullOrWhiteSpace(dto.Gestion) || dto.Gestion.Length != 4)
            return BadRequest(new { message = "La gesti??n debe tener 4 d??gitos" });

        if (!string.Equals(dto.Nombre.Trim(), NombreCarpetaPermitida, StringComparison.OrdinalIgnoreCase))
            return BadRequest(new { message = $"Solo se permite crear la carpeta {NombreCarpetaPermitida}" });

        if (dto.CarpetaPadreId.HasValue)
            return BadRequest(new { message = $"No se permiten subcarpetas en {NombreCarpetaPermitida}" });

        var exists = await _context.Carpetas.AnyAsync(c =>
            c.Nombre == NombreCarpetaPermitida &&
            c.Gestion == dto.Gestion &&
            c.CarpetaPadreId == null);

        if (exists)
            return BadRequest(new { message = $"Ya existe una carpeta {NombreCarpetaPermitida} para la gesti??n {dto.Gestion}" });

        var numeroCarpeta = await _context.Carpetas
            .Where(c => c.Gestion == dto.Gestion && c.CarpetaPadreId == null)
            .CountAsync() + 1;
        var codigoRomano = ToRoman(numeroCarpeta);

        var carpeta = new Carpeta
        {
            Nombre = NombreCarpetaPermitida,
            Codigo = codigoRomano,
            Gestion = dto.Gestion,
            Descripcion = dto.Descripcion,
            CarpetaPadreId = null,
            Activo = true,
            FechaCreacion = DateTime.UtcNow
            // TODO: UsuarioCreacionId = obtener del contexto de autenticaci??n
        };

        _context.Carpetas.Add(carpeta);
        await _context.SaveChangesAsync();

        // Pre-crear algunos rangos para que el usuario pueda elegirlos desde el inicio
        for (var i = 1; i <= RangosIniciales; i++)
        {
            var rangoInicio = ((i - 1) * TamanoRango) + 1;
            var rangoFin = rangoInicio + TamanoRango - 1;
            var subcarpeta = new Carpeta
            {
                Nombre = $"{rangoInicio} - {rangoFin}",
                Codigo = ToRoman(i),
                Gestion = dto.Gestion,
                CarpetaPadreId = carpeta.Id,
                Activo = true,
                FechaCreacion = DateTime.UtcNow
            };
            _context.Carpetas.Add(subcarpeta);
        }
        await _context.SaveChangesAsync();

        return CreatedAtAction(nameof(GetById), new { id = carpeta.Id }, new
        {
            carpeta.Id,
            carpeta.Nombre,
            carpeta.Codigo,
            carpeta.Gestion,
            carpeta.FechaCreacion,
            NumeroCarpeta = numeroCarpeta,
            CodigoRomano = codigoRomano
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

    private static int? ParseCorrelativo(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
            return null;
        return int.TryParse(value, out var num) ? num : null;
    }

    private async Task<Dictionary<int, (int? Inicio, int? Fin)>> ObtenerRangosCorrelativosAsync(List<int> carpetaIds, string? gestion)
    {
        var result = new Dictionary<int, (int? Inicio, int? Fin)>();
        if (carpetaIds.Count == 0)
            return result;

        var docs = await _context.Documentos
            .Where(d => d.CarpetaId.HasValue && carpetaIds.Contains(d.CarpetaId.Value))
            .Where(d => string.IsNullOrWhiteSpace(gestion) || d.Gestion == gestion)
            .Select(d => new { d.CarpetaId, d.NumeroCorrelativo })
            .ToListAsync();

        var grouped = docs
            .Select(d => new { d.CarpetaId, Valor = ParseCorrelativo(d.NumeroCorrelativo) })
            .Where(d => d.Valor.HasValue)
            .GroupBy(d => d.CarpetaId!.Value);

        foreach (var g in grouped)
        {
            var min = g.Min(x => x.Valor) ?? 0;
            var max = g.Max(x => x.Valor) ?? 0;
            result[g.Key] = (min, max);
        }

        return result;
    }

    private async Task<Dictionary<int, int>> ObtenerNumerosCarpetaAsync(List<int> carpetaIds, string? gestion)
    {
        var result = new Dictionary<int, int>();
        if (carpetaIds.Count == 0)
            return result;

        var roots = await _context.Carpetas
            .Where(c => c.CarpetaPadreId == null && c.Activo)
            .Where(c => string.IsNullOrWhiteSpace(gestion) || c.Gestion == gestion)
            .OrderBy(c => c.Id)
            .Select(c => c.Id)
            .ToListAsync();

        for (var i = 0; i < roots.Count; i++)
        {
            result[roots[i]] = i + 1;
        }

        // Tambien numerar subcarpetas (por ejemplo, rangos dentro de la carpeta general)
        foreach (var rootId in roots)
        {
            var subIds = await _context.Carpetas
                .Where(c => c.CarpetaPadreId == rootId && c.Activo)
                .Where(c => string.IsNullOrWhiteSpace(gestion) || c.Gestion == gestion)
                .OrderBy(c => c.Id)
                .Select(c => c.Id)
                .ToListAsync();

            for (var j = 0; j < subIds.Count; j++)
            {
                result[subIds[j]] = j + 1;
            }
        }

        return result;
    }

    private static string ToRoman(int number)
    {
        if (number <= 0) return string.Empty;
        var map = new[]
        {
            (1000, "M"), (900, "CM"), (500, "D"), (400, "CD"),
            (100, "C"), (90, "XC"), (50, "L"), (40, "XL"),
            (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")
        };
        var result = string.Empty;
        var remaining = number;
        foreach (var (value, roman) in map)
        {
            while (remaining >= value)
            {
                result += roman;
                remaining -= value;
            }
        }
        return result;
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
