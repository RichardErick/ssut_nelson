using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SistemaGestionDocumental.DTOs;
using SistemaGestionDocumental.Services;

namespace SistemaGestionDocumental.Controllers;

[ApiController]
[Route("api/[controller]")]
[AllowAnonymous] // Permitir acceso sin autenticación a todo el controlador
public class MovimientosController : ControllerBase
{
    private readonly IMovimientoService _movimientoService;

    public MovimientosController(IMovimientoService movimientoService)
    {
        _movimientoService = movimientoService;
    }

    [HttpGet]
    [AllowAnonymous] // Permitir acceso sin autenticación para desarrollo
    public async Task<ActionResult<IEnumerable<MovimientoDTO>>> GetAll()
    {
        var movimientos = await _movimientoService.GetAllAsync();
        
        // Intentar obtener el usuario actual del token JWT para filtrar
        var userIdClaim = User.FindFirst("userId")?.Value;
        var rolClaim = User.FindFirst("rol")?.Value;
        
        // Si tenemos información del usuario, filtrar según el rol
        if (!string.IsNullOrEmpty(userIdClaim) && 
            int.TryParse(userIdClaim, out int userId) &&
            !string.IsNullOrEmpty(rolClaim))
        {
            // Filtrar según el rol:
            // - Contador y Gerente: solo ven sus propios préstamos
            // - Administradores: ven todos
            if (rolClaim == "Contador" || rolClaim == "Gerente")
            {
                movimientos = movimientos.Where(m => m.UsuarioId == userId).ToList();
            }
        }
        
        return Ok(movimientos);
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<MovimientoDTO>> GetById(int id)
    {
        var movimiento = await _movimientoService.GetByIdAsync(id);
        if (movimiento == null)
            return NotFound();

        return Ok(movimiento);
    }

    [HttpGet("documento/{documentoId}")]
    public async Task<ActionResult<IEnumerable<MovimientoDTO>>> GetByDocumentoId(int documentoId)
    {
        var movimientos = await _movimientoService.GetByDocumentoIdAsync(documentoId);
        return Ok(movimientos);
    }

    [HttpGet("fecha")]
    public async Task<ActionResult<IEnumerable<MovimientoDTO>>> GetPorFecha(
        [FromQuery] DateTime fechaDesde,
        [FromQuery] DateTime fechaHasta)
    {
        var desdeUtc = DateTime.SpecifyKind(fechaDesde, DateTimeKind.Utc);
        var hastaUtc = DateTime.SpecifyKind(fechaHasta, DateTimeKind.Utc);
        var movimientos = await _movimientoService.GetMovimientosPorFechaAsync(desdeUtc, hastaUtc);
        return Ok(movimientos);
    }

    [HttpPost]
    public async Task<ActionResult<MovimientoDTO>> Create([FromBody] CreateMovimientoDTO dto)
    {
        try
        {
            // Intentar obtener el usuario actual del token JWT para validaciones
            var userIdClaim = User.FindFirst("userId")?.Value;
            var rolClaim = User.FindFirst("rol")?.Value;
            
            // Solo validar si tenemos información del usuario
            if (!string.IsNullOrEmpty(userIdClaim) && 
                int.TryParse(userIdClaim, out int currentUserId) &&
                !string.IsNullOrEmpty(rolClaim))
            {
                // Validación: Administrador de Documentos no puede prestarse a sí mismo
                if (rolClaim == "AdministradorDocumentos" && dto.UsuarioId == currentUserId)
                {
                    return BadRequest(new { message = "El Administrador de Documentos no puede registrar préstamos para sí mismo. Debe asignar el préstamo a un Contador o Gerente." });
                }
            }

            var movimiento = await _movimientoService.CreateAsync(dto);
            return CreatedAtAction(nameof(GetById), new { id = movimiento.Id }, movimiento);
        }
        catch (Exception ex)
        {
            // Exponer el mensaje interno de EF Core para que el frontend muestre la causa real
            var inner = ex.InnerException?.Message;
            var message = inner != null && inner.Trim().Length > 0
                ? inner
                : ex.Message;
            return BadRequest(new { message });
        }
    }

    [HttpPost("devolver")]
    public async Task<ActionResult<MovimientoDTO>> DevolverDocumento([FromBody] DevolverDocumentoDTO dto)
    {
        if (dto == null || dto.MovimientoId <= 0)
            return BadRequest(new { message = "Movimiento no válido" });

        try
        {
            var movimiento = await _movimientoService.DevolverDocumentoAsync(dto);
            if (movimiento == null)
                return BadRequest(new { message = "No se pudo procesar la devolución. Verifique que el movimiento exista y esté en estado Activo." });

            return Ok(movimiento);
        }
        catch (Exception ex)
        {
            var msg = ex.InnerException?.Message ?? ex.Message;
            return StatusCode(500, new { message = "Error al procesar la devolución.", error = msg });
        }
    }
}

