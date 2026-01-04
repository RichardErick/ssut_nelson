using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SistemaGestionDocumental.Data;
using SistemaGestionDocumental.Models;

namespace SistemaGestionDocumental.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuditoriaController : ControllerBase
{
    private readonly ApplicationDbContext _context;

    public AuditoriaController(ApplicationDbContext context)
    {
        _context = context;
    }

    [HttpPost]
    public async Task<ActionResult> Create([FromBody] CreateAuditoriaDTO dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Accion) || string.IsNullOrWhiteSpace(dto.Modulo))
            return BadRequest(new { message = "accion y modulo son obligatorios" });

        int? usuarioId = null;
        if (!string.IsNullOrWhiteSpace(dto.Usuario))
        {
            var usuario = await _context.Usuarios
                .AsNoTracking()
                .FirstOrDefaultAsync(u => u.NombreUsuario == dto.Usuario);
            usuarioId = usuario?.Id;
        }

        var auditoria = new Auditoria
        {
            UsuarioId = usuarioId,
            Accion = $"{dto.Modulo}:{dto.Accion}",
            TablaAfectada = dto.TablaAfectada,
            RegistroId = dto.RegistroId,
            Detalle = dto.Detalles,
            IpAddress = dto.Ip,
            FechaAccion = NormalizeToUtc(dto.Fecha) ?? DateTime.UtcNow,
        };

        try
        {
            _context.Auditoria.Add(auditoria);
            await _context.SaveChangesAsync();
            return Ok(new { auditoria.Id });
        }
        catch (DbUpdateException ex)
        {
            return Ok(new { message = "Auditoría no persistida", error = ex.Message });
        }
        catch (Exception ex)
        {
            return Ok(new { message = "Auditoría no persistida", error = ex.Message });
        }
    }

    private static DateTime? NormalizeToUtc(DateTime? value)
    {
        if (value == null)
            return null;

        return value.Value.Kind switch
        {
            DateTimeKind.Utc => value.Value,
            DateTimeKind.Local => value.Value.ToUniversalTime(),
            _ => DateTime.SpecifyKind(value.Value, DateTimeKind.Local).ToUniversalTime(),
        };
    }
}

public class CreateAuditoriaDTO
{
    public string Accion { get; set; } = string.Empty;
    public string Modulo { get; set; } = string.Empty;
    public string Detalles { get; set; } = string.Empty;
    public string? Usuario { get; set; }
    public DateTime? Fecha { get; set; }
    public string? Ip { get; set; }
    public string? TablaAfectada { get; set; }
    public int? RegistroId { get; set; }
}
