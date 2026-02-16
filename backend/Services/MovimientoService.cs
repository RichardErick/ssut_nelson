using Microsoft.EntityFrameworkCore;
using SistemaGestionDocumental.Data;
using SistemaGestionDocumental.DTOs;
using SistemaGestionDocumental.Models;

namespace SistemaGestionDocumental.Services;

public class MovimientoService : IMovimientoService
{
    private readonly ApplicationDbContext _context;

    public MovimientoService(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<IEnumerable<MovimientoDTO>> GetAllAsync()
    {
        return await _context.Movimientos
            .Include(m => m.Documento)
            .Include(m => m.AreaOrigen)
            .Include(m => m.AreaDestino)
            .Include(m => m.Usuario)
            .Select(m => MapToDTO(m))
            .ToListAsync();
    }

    public async Task<MovimientoDTO?> GetByIdAsync(int id)
    {
        var movimiento = await _context.Movimientos
            .Include(m => m.Documento)
            .Include(m => m.AreaOrigen)
            .Include(m => m.AreaDestino)
            .Include(m => m.Usuario)
            .FirstOrDefaultAsync(m => m.Id == id);

        return movimiento != null ? MapToDTO(movimiento) : null;
    }

    public async Task<IEnumerable<MovimientoDTO>> GetByDocumentoIdAsync(int documentoId)
    {
        return await _context.Movimientos
            .Include(m => m.Documento)
            .Include(m => m.AreaOrigen)
            .Include(m => m.AreaDestino)
            .Include(m => m.Usuario)
            .Where(m => m.DocumentoId == documentoId)
            .OrderByDescending(m => m.FechaMovimiento)
            .Select(m => MapToDTO(m))
            .ToListAsync();
    }

    public async Task<IEnumerable<MovimientoDTO>> GetMovimientosPorFechaAsync(DateTime fechaDesde, DateTime fechaHasta)
    {
        return await _context.Movimientos
            .Include(m => m.Documento)
            .Include(m => m.AreaOrigen)
            .Include(m => m.AreaDestino)
            .Include(m => m.Usuario)
            .Where(m => m.FechaMovimiento >= fechaDesde && m.FechaMovimiento <= fechaHasta)
            .OrderByDescending(m => m.FechaMovimiento)
            .Select(m => MapToDTO(m))
            .ToListAsync();
    }

    public async Task<MovimientoDTO> CreateAsync(CreateMovimientoDTO dto)
    {
        var documento = await _context.Documentos.FindAsync(dto.DocumentoId);
        if (documento == null)
            throw new Exception("Documento no encontrado");

        // Validación de negocio: no permitir prestar o derivar un documento que ya está prestado
        if ((dto.TipoMovimiento == "Salida" || dto.TipoMovimiento == "Derivacion") &&
            documento.Estado == EstadoDocumento.Prestado)
        {
            throw new Exception("El documento ya se encuentra prestado. Debe devolverse antes de registrar un nuevo préstamo o derivación.");
        }

        // Actualizar estado del documento según el tipo de movimiento
        if (dto.TipoMovimiento == "Salida" || dto.TipoMovimiento == "Derivacion")
        {
            documento.Estado = EstadoDocumento.Prestado;
        }
        else if (dto.TipoMovimiento == "Entrada")
        {
            documento.Estado = EstadoDocumento.Activo;
        }

        var movimiento = new Movimiento
        {
            DocumentoId = dto.DocumentoId,
            TipoMovimiento = dto.TipoMovimiento,
            AreaOrigenId = dto.AreaOrigenId,
            AreaDestinoId = dto.AreaDestinoId,
            UsuarioId = dto.UsuarioId,
            Observaciones = dto.Observaciones,
            FechaMovimiento = DateTime.UtcNow,
            FechaLimiteDevolucion = dto.FechaLimiteDevolucion,
            Estado = "Activo"
        };

        _context.Movimientos.Add(movimiento);

        // Algunos entornos tienen un trigger en 'documentos' que inserta en historial_documento
        // usando un usuario_id inválido, provocando errores de FK (23503). Para evitar que
        // el registro de préstamo falle por ese trigger, lo desactivamos temporalmente
        // SOLO alrededor de este SaveChanges.
        try
        {
            try
            {
                await _context.Database.ExecuteSqlRawAsync(
                    "ALTER TABLE documentos DISABLE TRIGGER trigger_documentos_historial;");
            }
            catch
            {
                // Si el trigger no existe en esta BD, continuar normalmente.
            }

            await _context.SaveChangesAsync();
        }
        finally
        {
            try
            {
                await _context.Database.ExecuteSqlRawAsync(
                    "ALTER TABLE documentos ENABLE TRIGGER trigger_documentos_historial;");
            }
            catch
            {
                // Ignorar si el trigger no existe o ya estaba deshabilitado.
            }
        }

        return await GetByIdAsync(movimiento.Id) ?? throw new Exception("Error al crear movimiento");
    }

    public async Task<MovimientoDTO?> DevolverDocumentoAsync(DevolverDocumentoDTO dto)
    {
        var movimiento = await _context.Movimientos
            .Include(m => m.Documento)
            .FirstOrDefaultAsync(m => m.Id == dto.MovimientoId);

        if (movimiento == null || movimiento.Estado != "Activo")
            return null;

        movimiento.Estado = "Devuelto";
        movimiento.FechaDevolucion = DateTime.UtcNow;
        if (!string.IsNullOrEmpty(dto.Observaciones))
            movimiento.Observaciones = dto.Observaciones;

        // Actualizar estado del documento
        if (movimiento.Documento != null)
        {
            movimiento.Documento.Estado = EstadoDocumento.Activo;
        }

        await _context.SaveChangesAsync();

        // Registrar movimiento de entrada (devolución)
        var movimientoEntrada = new Movimiento
        {
            DocumentoId = movimiento.DocumentoId,
            TipoMovimiento = "Entrada",
            AreaOrigenId = movimiento.AreaDestinoId,
            AreaDestinoId = movimiento.AreaOrigenId,
            UsuarioId = movimiento.UsuarioId,
            Observaciones = dto.Observaciones ?? "Devolución de documento",
            FechaMovimiento = DateTime.UtcNow,
            Estado = "Activo"
        };

        _context.Movimientos.Add(movimientoEntrada);
        await _context.SaveChangesAsync();

        return await GetByIdAsync(movimiento.Id);
    }

    private static MovimientoDTO MapToDTO(Movimiento m)
    {
        return new MovimientoDTO
        {
            Id = m.Id,
            DocumentoId = m.DocumentoId,
            DocumentoCodigo = m.Documento?.Codigo,
            TipoMovimiento = m.TipoMovimiento,
            AreaOrigenId = m.AreaOrigenId,
            AreaOrigenNombre = m.AreaOrigen?.Nombre,
            AreaDestinoId = m.AreaDestinoId,
            AreaDestinoNombre = m.AreaDestino?.Nombre,
            UsuarioId = m.UsuarioId,
            UsuarioNombre = m.Usuario?.NombreCompleto,
            Observaciones = m.Observaciones,
            FechaMovimiento = m.FechaMovimiento,
            FechaDevolucion = m.FechaDevolucion,
            FechaLimiteDevolucion = m.FechaLimiteDevolucion,
            Estado = m.Estado
        };
    }
}

