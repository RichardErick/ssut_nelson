using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SistemaGestionDocumental.Data;
using SistemaGestionDocumental.Models;
using System.Security.Claims;

namespace SistemaGestionDocumental.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class AlertasController : ControllerBase
{
    private readonly ApplicationDbContext _context;

    public AlertasController(ApplicationDbContext context)
    {
        _context = context;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<Alerta>>> GetMisAlertas()
    {
        var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub");
        if (string.IsNullOrEmpty(userIdStr) || !int.TryParse(userIdStr, out var userId))
            return Unauthorized();

        // 1. Limpieza automática: Eliminar alertas leídas hace más de 2 días
        var fechaLimiteLimpieza = DateTime.UtcNow.AddDays(-2);
        var alertasParaLimpiar = await _context.Alertas
            .Where(a => a.UsuarioId == userId && a.Leida && a.FechaLectura < fechaLimiteLimpieza)
            .ToListAsync();
        if (alertasParaLimpiar.Any())
        {
            _context.Alertas.RemoveRange(alertasParaLimpiar);
            await _context.SaveChangesAsync();
        }

        // 2. Verificar vencimientos de préstamos (pobre man's background job)
        await VerificarVencimientosAsync(userId);

        // Proyectar a un DTO liviano para evitar ciclos de navegación y errores 500 al serializar.
        var alertas = await _context.Alertas
            .Where(a => a.UsuarioId == userId)
            .OrderByDescending(a => a.FechaCreacion)
            .Take(50)
            .Select(a => new
            {
                a.Id,
                a.Titulo,
                a.Mensaje,
                a.TipoAlerta,
                a.Leida,
                a.FechaCreacion,
                a.FechaLectura,
                a.DocumentoId,
                a.MovimientoId
            })
            .ToListAsync();

        return Ok(alertas);
    }

    [HttpDelete("clear-all")]
    public async Task<IActionResult> ClearAll()
    {
        var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub");
        if (string.IsNullOrEmpty(userIdStr) || !int.TryParse(userIdStr, out var userId))
            return Unauthorized();

        var alertas = await _context.Alertas
            .Where(a => a.UsuarioId == userId)
            .ToListAsync();

        if (alertas.Any())
        {
            _context.Alertas.RemoveRange(alertas);
            await _context.SaveChangesAsync();
        }

        return NoContent();
    }

    private async Task VerificarVencimientosAsync(int userId)
    {
        // Buscar préstamos activos del usuario que venzan pronto
        // Solo para el usuario borroer (usuario_id en movimiento)
        var prestamosActivos = await _context.Movimientos
            .Include(m => m.Documento)
            .Where(m => m.UsuarioId == userId && m.TipoMovimiento == "Salida" && m.Estado == "Activo" && m.FechaLimiteDevolucion.HasValue)
            .ToListAsync();

        foreach (var p in prestamosActivos)
        {
            var diasRestantes = (p.FechaLimiteDevolucion.Value.Date - DateTime.UtcNow.Date).Days;
            string titulo = "Recordatorio de préstamo";
            string mensaje = "";
            string tipo = "info";

            if (diasRestantes == 0)
            {
                titulo = "¡Hoy vence el préstamo!";
                mensaje = $"Hoy es el último día para devolver el documento {p.Documento?.Codigo}. Por favor, no olvides devolverlo hoy.";
                tipo = "warning";
            }
            else if (diasRestantes == 1)
            {
                mensaje = $"Te queda 1 día para devolver el documento {p.Documento?.Codigo}. Mañana es la fecha límite.";
                tipo = "info";
            }
            else if (diasRestantes > 0 && diasRestantes <= 3)
            {
                mensaje = $"Te quedan {diasRestantes} días para devolver el documento {p.Documento?.Codigo}.";
                tipo = "info";
            }
            else if (diasRestantes < 0)
            {
                titulo = "Préstamo vencido";
                mensaje = $"El documento {p.Documento?.Codigo} tiene un retraso de {Math.Abs(diasRestantes)} días. Por favor, devuélvelo lo antes posible.";
                tipo = "error";
            }

            if (!string.IsNullOrEmpty(mensaje))
            {
                // Verificar si ya existe una alerta similar hoy
                var hoy = DateTime.UtcNow.Date;
                var existeAlertaHoy = await _context.Alertas
                    .AnyAsync(a => a.UsuarioId == userId && a.MovimientoId == p.Id && a.FechaCreacion >= hoy);

                if (!existeAlertaHoy)
                {
                    _context.Alertas.Add(new Alerta
                    {
                        UsuarioId = userId,
                        MovimientoId = p.Id,
                        DocumentoId = p.DocumentoId,
                        Titulo = titulo,
                        Mensaje = mensaje,
                        TipoAlerta = tipo,
                        FechaCreacion = DateTime.UtcNow
                    });
                }
            }
        }
        await _context.SaveChangesAsync();
    }

    [HttpGet("unread-count")]
    public async Task<ActionResult<int>> GetUnreadCount()
    {
        var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub");
        if (string.IsNullOrEmpty(userIdStr) || !int.TryParse(userIdStr, out int userId))
            return Unauthorized();

        var count = await _context.Alertas
            .Where(a => a.UsuarioId == userId && !a.Leida)
            .CountAsync();

        return Ok(new { count });
    }

    [HttpPut("{id}/leida")]
    public async Task<IActionResult> MarcarComoLeida(int id)
    {
        var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub");
        if (string.IsNullOrEmpty(userIdStr) || !int.TryParse(userIdStr, out int userId))
            return Unauthorized();

        var alerta = await _context.Alertas.FindAsync(id);

        if (alerta == null)
            return NotFound();

        if (alerta.UsuarioId != userId)
            return Forbid();

        alerta.Leida = true;
        alerta.FechaLectura = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        return NoContent();
    }
    
    [HttpDelete("{id}")]
    public async Task<IActionResult> EliminarAlerta(int id)
    {
        var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub");
        if (string.IsNullOrEmpty(userIdStr) || !int.TryParse(userIdStr, out int userId))
            return Unauthorized();
        var alerta = await _context.Alertas.FindAsync(id);

        if (alerta == null) return NotFound();
        if (alerta.UsuarioId != userId) return Forbid();

        _context.Alertas.Remove(alerta);
        await _context.SaveChangesAsync();

        return NoContent();
    }
}
