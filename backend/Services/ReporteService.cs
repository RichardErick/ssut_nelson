using Microsoft.EntityFrameworkCore;
using SistemaGestionDocumental.Data;
using SistemaGestionDocumental.DTOs;
using SistemaGestionDocumental.Services;
using SistemaGestionDocumental.Models;

namespace SistemaGestionDocumental.Services;

public class ReporteService : IReporteService
{
    private readonly ApplicationDbContext _context;
    private readonly IMovimientoService _movimientoService;
    private readonly IDocumentoService _documentoService;

    public ReporteService(
        ApplicationDbContext context,
        IMovimientoService movimientoService,
        IDocumentoService documentoService)
    {
        _context = context;
        _movimientoService = movimientoService;
        _documentoService = documentoService;
    }

    public async Task<IEnumerable<MovimientoDTO>> GenerarReporteMovimientosAsync(ReporteMovimientosDTO filtros)
    {
        var fechaDesdeUtc = NormalizeToUtc(filtros.FechaDesde);
        var fechaHastaUtc = NormalizeToUtc(filtros.FechaHasta);

        var query = _context.Movimientos
            .Include(m => m.Documento)
            .Include(m => m.AreaOrigen)
            .Include(m => m.AreaDestino)
            .Include(m => m.Usuario)
            .Where(m => m.FechaMovimiento >= fechaDesdeUtc && m.FechaMovimiento <= fechaHastaUtc)
            .AsQueryable();

        if (filtros.AreaId.HasValue)
        {
            query = query.Where(m => m.AreaOrigenId == filtros.AreaId || m.AreaDestinoId == filtros.AreaId);
        }

        if (!string.IsNullOrEmpty(filtros.TipoMovimiento))
        {
            query = query.Where(m => m.TipoMovimiento == filtros.TipoMovimiento);
        }

        var movimientos = await query
            .OrderByDescending(m => m.FechaMovimiento)
            .ToListAsync();

        return movimientos.Select(m => new MovimientoDTO
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
            Estado = m.Estado
        });
    }

    public async Task<IEnumerable<DocumentoDTO>> GenerarReporteDocumentosAsync(ReporteDocumentosDTO filtros)
    {
        var busqueda = new BusquedaDocumentoDTO
        {
            Gestion = filtros.Gestion,
            TipoDocumentoId = filtros.TipoDocumentoId,
            AreaOrigenId = filtros.AreaOrigenId,
            Estado = filtros.Estado
        };

        return await _documentoService.BuscarAsync(busqueda);
    }

    public async Task<EstadisticaDocumentoDTO> ObtenerEstadisticasAsync()
    {
        var totalDocumentos = await _context.Documentos.CountAsync();
        var documentosActivos = await _context.Documentos.CountAsync(d => d.Estado == EstadoDocumento.Activo);
        var documentosPrestados = await _context.Documentos.CountAsync(d => d.Estado == EstadoDocumento.Prestado);
        var documentosArchivados = await _context.Documentos.CountAsync(d => d.Estado == EstadoDocumento.Archivado);

        var nowUtc = DateTime.UtcNow;
        var inicioMes = new DateTime(nowUtc.Year, nowUtc.Month, 1, 0, 0, 0, DateTimeKind.Utc);
        var movimientosMes = await _context.Movimientos
            .CountAsync(m => m.FechaMovimiento >= inicioMes);

        var documentosPorTipo = await _context.Documentos
            .Include(d => d.TipoDocumento)
            .GroupBy(d => d.TipoDocumento!.Nombre)
            .Select(g => new { Tipo = g.Key ?? "Sin tipo", Cantidad = g.Count() })
            .ToDictionaryAsync(x => x.Tipo, x => x.Cantidad);

        var movimientosPorTipo = await _context.Movimientos
            .GroupBy(m => m.TipoMovimiento)
            .Select(g => new { Tipo = g.Key, Cantidad = g.Count() })
            .ToDictionaryAsync(x => x.Tipo, x => x.Cantidad);

        return new EstadisticaDocumentoDTO
        {
            TotalDocumentos = totalDocumentos,
            DocumentosActivos = documentosActivos,
            DocumentosPrestados = documentosPrestados,
            DocumentosArchivados = documentosArchivados,
            MovimientosMes = movimientosMes,
            DocumentosPorTipo = documentosPorTipo,
            MovimientosPorTipo = movimientosPorTipo
        };
    }

    private static DateTime NormalizeToUtc(DateTime value)
    {
        return value.Kind switch
        {
            DateTimeKind.Utc => value,
            DateTimeKind.Local => value.ToUniversalTime(),
            _ => DateTime.SpecifyKind(value, DateTimeKind.Local).ToUniversalTime(),
        };
    }
}

