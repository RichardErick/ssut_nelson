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

        // Para carpetas raíz: total de documentos en la carpeta + todas las subcarpetas
        var raizIds = carpetas.Where(c => c.CarpetaPadreId == null).Select(c => c.Id).ToList();
        var totalDocumentosPorRaiz = await ObtenerTotalDocumentosEnArbolAsync(raizIds);

        var result = carpetas.Select(c =>
        {
            var numeroDocumentos = c.CarpetaPadreId == null && totalDocumentosPorRaiz.TryGetValue(c.Id, out var total)
                ? total
                : c.NumeroDocumentos;
            return new
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
                NumeroDocumentos = numeroDocumentos,
                NumeroCarpeta = numeroMap.TryGetValue(c.Id, out var n) ? n : (int?)null,
                CodigoRomano = numeroMap.TryGetValue(c.Id, out var rn) ? ToRoman(rn) : null,
                RangoInicio = rangoMap.TryGetValue(c.Id, out var r) ? r.Inicio : null,
                RangoFin = rangoMap.TryGetValue(c.Id, out var r2) ? r2.Fin : null
            };
        });

        return Ok(result);
    }

    /// <summary>
    /// Para cada carpeta raíz, devuelve el total de documentos en esa carpeta y en todas sus subcarpetas.
    /// </summary>
    private async Task<Dictionary<int, int>> ObtenerTotalDocumentosEnArbolAsync(List<int> raizIds)
    {
        var result = new Dictionary<int, int>();
        foreach (var raizId in raizIds)
        {
            var idsEnArbol = await ObtenerIdsCarpetaYDescendientesAsync(raizId);
            var total = await _context.Documentos
                .CountAsync(d => d.CarpetaId.HasValue && idsEnArbol.Contains(d.CarpetaId.Value));
            result[raizId] = total;
        }
        return result;
    }

    private async Task<HashSet<int>> ObtenerIdsCarpetaYDescendientesAsync(int carpetaId)
    {
        var ids = new HashSet<int> { carpetaId };
        var frontier = new List<int> { carpetaId };
        while (frontier.Count > 0)
        {
            var children = await _context.Carpetas
                .Where(c => c.CarpetaPadreId.HasValue && frontier.Contains(c.CarpetaPadreId.Value))
                .Select(c => c.Id)
                .ToListAsync();
            frontier.Clear();
            foreach (var id in children)
            {
                if (ids.Add(id))
                    frontier.Add(id);
            }
        }
        return ids;
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
            return BadRequest(new { message = "La gestión debe tener 4 dígitos" });

        // Validar que si hay padre, existe
        if (dto.CarpetaPadreId.HasValue)
        {
            var padreExists = await _context.Carpetas.AnyAsync(c => c.Id == dto.CarpetaPadreId.Value);
            if (!padreExists)
                return BadRequest(new { message = "La carpeta padre no existe" });
        }

        // No puede existir otra carpeta con el mismo rango (misma ubicación y gestión)
        if (dto.RangoInicio.HasValue && dto.RangoFin.HasValue)
        {
            var mismaUbicacion = await _context.Carpetas
                .Where(c => c.CarpetaPadreId == dto.CarpetaPadreId && c.Gestion == dto.Gestion)
                .Where(c => c.RangoInicio.HasValue && c.RangoFin.HasValue)
                .Where(c => c.RangoInicio == dto.RangoInicio && c.RangoFin == dto.RangoFin)
                .AnyAsync();
            if (mismaUbicacion)
            {
                var ultimoRango = await _context.Carpetas
                    .Where(c => c.CarpetaPadreId == dto.CarpetaPadreId && c.Gestion == dto.Gestion && c.RangoFin.HasValue)
                    .Select(c => c.RangoFin)
                    .MaxAsync() ?? 0;
                return BadRequest(new
                {
                    message = $"Ya existe una carpeta con el rango {dto.RangoInicio}-{dto.RangoFin} en esta ubicación y gestión.",
                    ultimoValorRango = ultimoRango
                });
            }
        }

        // Calcular número de carpeta automáticamente
        var numeroCarpeta = await _context.Carpetas
            .Where(c => c.Gestion == dto.Gestion && c.CarpetaPadreId == dto.CarpetaPadreId)
            .CountAsync() + 1;

        // Usar el código romano proporcionado o generar uno automáticamente
        var codigoRomano = !string.IsNullOrWhiteSpace(dto.Codigo) 
            ? dto.Codigo 
            : ToRoman(numeroCarpeta);

        var carpeta = new Carpeta
        {
            Nombre = dto.Nombre.Trim(),
            Codigo = codigoRomano,
            Gestion = dto.Gestion,
            Descripcion = dto.Descripcion,
            CarpetaPadreId = dto.CarpetaPadreId,
            RangoInicio = dto.RangoInicio,
            RangoFin = dto.RangoFin,
            Activo = true,
            FechaCreacion = DateTime.UtcNow
            // TODO: UsuarioCreacionId = obtener del contexto de autenticación
        };

        try
        {
            _context.Carpetas.Add(carpeta);
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException ex)
        {
            if (ex.InnerException != null && ex.InnerException.Message.Contains("23505"))
                return BadRequest(new { message = "Error de duplicado al guardar la carpeta. Verifique que el rango no esté en uso." });
            throw;
        }

        return CreatedAtAction(nameof(GetById), new { id = carpeta.Id }, new
        {
            carpeta.Id,
            carpeta.Nombre,
            carpeta.Codigo,
            carpeta.Gestion,
            carpeta.FechaCreacion,
            NumeroCarpeta = numeroCarpeta,
            CodigoRomano = codigoRomano,
            RangoInicio = carpeta.RangoInicio,
            RangoFin = carpeta.RangoFin
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

        // Borrado normal: eliminar de la BD. Solo bloqueamos si tiene subcarpetas o documentos ACTIVOS.
        // Las inactivas no bloquean; al borrar la carpeta, la BD hace CASCADE en hijas (carpeta_padre_id).
        if (!hard)
        {
            var tieneSubcarpetasActivas = carpeta.Subcarpetas.Any(s => s.Activo);
            var tieneDocumentosActivos = carpeta.Documentos.Any(d => d.Activo);
            if (tieneSubcarpetasActivas)
                return BadRequest(new { message = "No se puede eliminar una carpeta con subcarpetas activas. Elimine primero las subcarpetas o use borrado en cascada." });
            if (tieneDocumentosActivos)
                return BadRequest(new { message = "No se puede eliminar una carpeta con documentos activos. Mueva o elimine los documentos primero." });

            _context.Carpetas.Remove(carpeta);
            await _context.SaveChangesAsync();
            return Ok(new { message = "Carpeta eliminada" });
        }

        // Hard delete (cascada): eliminar subcarpetas y documentos asociados.
        // Importante: Documento->Carpeta tiene OnDelete(SetNull), así que si queremos
        // borrar documentos al eliminar carpeta, debemos eliminarlos explícitamente.
        await using var tx = await _context.Database.BeginTransactionAsync();
        try
        {
            var (idsToDelete, depths) = await GetDescendantCarpetaIdsWithDepthAsync(id);

            var documentos = await _context.Documentos
                .Where(d => d.CarpetaId.HasValue && idsToDelete.Contains(d.CarpetaId.Value))
                .ToListAsync();

            if (documentos.Count > 0)
            {
                var docIds = documentos.Select(d => d.Id).ToList();
                // Eliminar dependencias antes que documentos (por si la BD no tiene ON DELETE CASCADE)
                var anexos = await _context.Anexos.Where(a => docIds.Contains(a.DocumentoId)).ToListAsync();
                var movimientos = await _context.Movimientos.Where(m => docIds.Contains(m.DocumentoId)).ToListAsync();
                var historiales = await _context.HistorialesDocumento.Where(h => docIds.Contains(h.DocumentoId)).ToListAsync();
                var alertasDoc = await _context.Alertas.Where(a => a.DocumentoId.HasValue && docIds.Contains(a.DocumentoId.Value)).ToListAsync();
                var docPalabras = await _context.DocumentoPalabrasClaves.Where(dpc => docIds.Contains(dpc.DocumentoId)).ToListAsync();

                _context.Anexos.RemoveRange(anexos);
                _context.Movimientos.RemoveRange(movimientos);
                _context.HistorialesDocumento.RemoveRange(historiales);
                _context.Alertas.RemoveRange(alertasDoc);
                _context.DocumentoPalabrasClaves.RemoveRange(docPalabras);
                await _context.SaveChangesAsync();

                _context.Documentos.RemoveRange(documentos);
                await _context.SaveChangesAsync();
            }

            // Eliminar carpetas de hojas a raíz (depth descendente) para evitar problemas
            // con FKs cuando la cascada no aplique por configuración/DB.
            var carpetasToDelete = await _context.Carpetas
                .Where(c => idsToDelete.Contains(c.Id))
                .ToListAsync();

            var ordered = carpetasToDelete
                .OrderByDescending(c => depths.TryGetValue(c.Id, out var d) ? d : 0)
                .ToList();

            _context.Carpetas.RemoveRange(ordered);
            await _context.SaveChangesAsync();

            await tx.CommitAsync();
            return Ok(new { message = "Carpeta eliminada (cascada)" });
        }
        catch (Exception ex)
        {
            await tx.RollbackAsync();
            return StatusCode(StatusCodes.Status500InternalServerError, new
            {
                message = "Error eliminando carpeta en cascada",
                error = ex.Message
            });
        }
    }

    private async Task<(HashSet<int> Ids, Dictionary<int, int> Depths)> GetDescendantCarpetaIdsWithDepthAsync(int rootId)
    {
        var ids = new HashSet<int> { rootId };
        var depths = new Dictionary<int, int> { [rootId] = 0 };

        var frontier = new List<int> { rootId };
        var depth = 0;

        while (frontier.Count > 0)
        {
            depth += 1;
            var children = await _context.Carpetas
                .Where(c => c.CarpetaPadreId.HasValue && frontier.Contains(c.CarpetaPadreId.Value))
                .Select(c => new { c.Id, c.CarpetaPadreId })
                .ToListAsync();

            frontier = new List<int>();
            foreach (var child in children)
            {
                if (ids.Add(child.Id))
                {
                    depths[child.Id] = depth;
                    frontier.Add(child.Id);
                }
            }
        }

        return (ids, depths);
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
    public int? RangoInicio { get; set; }
    public int? RangoFin { get; set; }
}

public class UpdateCarpetaDTO
{
    public string? Nombre { get; set; }
    public string? Codigo { get; set; }
    public string? Descripcion { get; set; }
    public bool? Activo { get; set; }
}
