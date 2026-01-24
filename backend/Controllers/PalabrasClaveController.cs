using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SistemaGestionDocumental.Data;
using SistemaGestionDocumental.Models;

namespace SistemaGestionDocumental.Controllers;

[ApiController]
[Route("api/[controller]")]
public class PalabrasClaveController : ControllerBase
{
    private readonly ApplicationDbContext _context;

    public PalabrasClaveController(ApplicationDbContext context)
    {
        _context = context;
    }

    // GET: api/palabrasclave
    [HttpGet]
    public async Task<ActionResult> GetAll([FromQuery] bool incluirInactivas = false)
    {
        var query = _context.PalabrasClaves.AsQueryable();

        if (!incluirInactivas)
        {
            query = query.Where(pc => pc.Activo);
        }

        var palabrasClave = await query
            .OrderBy(pc => pc.Palabra)
            .Select(pc => new
            {
                pc.Id,
                pc.Palabra,
                pc.Descripcion,
                pc.Activo,
                NumeroDocumentos = pc.DocumentoPalabrasClaves.Count
            })
            .ToListAsync();

        return Ok(palabrasClave);
    }

    // GET: api/palabrasclave/{id}
    [HttpGet("{id}")]
    public async Task<ActionResult> GetById(int id)
    {
        var palabraClave = await _context.PalabrasClaves
            .Where(pc => pc.Id == id)
            .Select(pc => new
            {
                pc.Id,
                pc.Palabra,
                pc.Descripcion,
                pc.Activo,
                NumeroDocumentos = pc.DocumentoPalabrasClaves.Count
            })
            .FirstOrDefaultAsync();

        if (palabraClave == null)
            return NotFound(new { message = "Palabra clave no encontrada" });

        return Ok(palabraClave);
    }

    // POST: api/palabrasclave
    [HttpPost]
    public async Task<ActionResult> Create([FromBody] CreatePalabraClaveDTO dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Palabra))
            return BadRequest(new { message = "La palabra es obligatoria" });

        var palabra = dto.Palabra.Trim().ToLower();

        // Verificar que no exista
        var exists = await _context.PalabrasClaves.AnyAsync(pc => pc.Palabra == palabra);
        if (exists)
            return BadRequest(new { message = "Ya existe esa palabra clave" });

        var palabraClave = new PalabraClave
        {
            Palabra = palabra,
            Descripcion = dto.Descripcion,
            Activo = true
        };

        _context.PalabrasClaves.Add(palabraClave);
        await _context.SaveChangesAsync();

        return CreatedAtAction(nameof(GetById), new { id = palabraClave.Id }, new
        {
            palabraClave.Id,
            palabraClave.Palabra,
            palabraClave.Descripcion
        });
    }

    // PUT: api/palabrasclave/{id}
    [HttpPut("{id}")]
    public async Task<ActionResult> Update(int id, [FromBody] UpdatePalabraClaveDTO dto)
    {
        var palabraClave = await _context.PalabrasClaves.FindAsync(id);
        if (palabraClave == null)
            return NotFound(new { message = "Palabra clave no encontrada" });

        if (!string.IsNullOrWhiteSpace(dto.Palabra))
        {
            var palabra = dto.Palabra.Trim().ToLower();
            var exists = await _context.PalabrasClaves.AnyAsync(pc => pc.Palabra == palabra && pc.Id != id);
            if (exists)
                return BadRequest(new { message = "Ya existe esa palabra clave" });

            palabraClave.Palabra = palabra;
        }

        if (dto.Descripcion != null)
            palabraClave.Descripcion = dto.Descripcion;

        if (dto.Activo.HasValue)
            palabraClave.Activo = dto.Activo.Value;

        await _context.SaveChangesAsync();

        return Ok(new
        {
            palabraClave.Id,
            palabraClave.Palabra,
            message = "Palabra clave actualizada exitosamente"
        });
    }

    // DELETE: api/palabrasclave/{id}
    [HttpDelete("{id}")]
    public async Task<ActionResult> Delete(int id, [FromQuery] bool hard = false)
    {
        var palabraClave = await _context.PalabrasClaves
            .Include(pc => pc.DocumentoPalabrasClaves)
            .FirstOrDefaultAsync(pc => pc.Id == id);

        if (palabraClave == null)
            return NotFound(new { message = "Palabra clave no encontrada" });

        if (palabraClave.DocumentoPalabrasClaves.Any() && hard)
            return BadRequest(new { message = "No se puede eliminar una palabra clave con documentos asociados" });

        if (!hard)
        {
            palabraClave.Activo = false;
            await _context.SaveChangesAsync();
            return Ok(new { message = "Palabra clave desactivada" });
        }

        _context.PalabrasClaves.Remove(palabraClave);
        await _context.SaveChangesAsync();

        return NoContent();
    }

    // POST: api/palabrasclave/batch
    [HttpPost("batch")]
    public async Task<ActionResult> CreateBatch([FromBody] List<string> palabras)
    {
        if (palabras == null || !palabras.Any())
            return BadRequest(new { message = "Debe proporcionar al menos una palabra" });

        var palabrasCreadas = 0;
        var palabrasExistentes = 0;

        foreach (var palabra in palabras)
        {
            if (string.IsNullOrWhiteSpace(palabra))
                continue;

            var palabraNormalizada = palabra.Trim().ToLower();
            var exists = await _context.PalabrasClaves.AnyAsync(pc => pc.Palabra == palabraNormalizada);

            if (!exists)
            {
                _context.PalabrasClaves.Add(new PalabraClave
                {
                    Palabra = palabraNormalizada,
                    Activo = true
                });
                palabrasCreadas++;
            }
            else
            {
                palabrasExistentes++;
            }
        }

        await _context.SaveChangesAsync();

        return Ok(new
        {
            palabrasCreadas,
            palabrasExistentes,
            message = $"{palabrasCreadas} palabra(s) clave creada(s), {palabrasExistentes} ya existían"
        });
    }
}

public class CreatePalabraClaveDTO
{
    public string Palabra { get; set; } = string.Empty;
    public string? Descripcion { get; set; }
}

public class UpdatePalabraClaveDTO
{
    public string? Palabra { get; set; }
    public string? Descripcion { get; set; }
    public bool? Activo { get; set; }
}
