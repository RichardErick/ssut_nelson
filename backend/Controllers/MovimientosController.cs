using Microsoft.AspNetCore.Mvc;
using SistemaGestionDocumental.DTOs;
using SistemaGestionDocumental.Services;

namespace SistemaGestionDocumental.Controllers;

[ApiController]
[Route("api/[controller]")]
public class MovimientosController : ControllerBase
{
    private readonly IMovimientoService _movimientoService;

    public MovimientosController(IMovimientoService movimientoService)
    {
        _movimientoService = movimientoService;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<MovimientoDTO>>> GetAll()
    {
        var movimientos = await _movimientoService.GetAllAsync();
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
            var movimiento = await _movimientoService.CreateAsync(dto);
            return CreatedAtAction(nameof(GetById), new { id = movimiento.Id }, movimiento);
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
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

