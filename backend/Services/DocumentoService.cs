using Microsoft.EntityFrameworkCore;
using SistemaGestionDocumental.Data;
using SistemaGestionDocumental.DTOs;
using SistemaGestionDocumental.Models;

namespace SistemaGestionDocumental.Services;

public class DocumentoService : IDocumentoService
{
    private readonly ApplicationDbContext _context;
    private readonly IQRCodeService _qrCodeService;

    public DocumentoService(ApplicationDbContext context, IQRCodeService qrCodeService)
    {
        _context = context;
        _qrCodeService = qrCodeService;
    }

    public async Task<IEnumerable<DocumentoDTO>> GetAllAsync()
    {
        return await _context.Documentos
            .Include(d => d.TipoDocumento)
            .Include(d => d.AreaOrigen)
            .Include(d => d.Responsable)
            .Select(d => MapToDTO(d))
            .ToListAsync();
    }

    public async Task<DocumentoDTO?> GetByIdAsync(int id)
    {
        var documento = await _context.Documentos
            .Include(d => d.TipoDocumento)
            .Include(d => d.AreaOrigen)
            .Include(d => d.Responsable)
            .FirstOrDefaultAsync(d => d.Id == id);

        return documento != null ? MapToDTO(documento) : null;
    }

    public async Task<DocumentoDTO?> GetByCodigoAsync(string codigo)
    {
        var documento = await _context.Documentos
            .Include(d => d.TipoDocumento)
            .Include(d => d.AreaOrigen)
            .Include(d => d.Responsable)
            .FirstOrDefaultAsync(d => d.Codigo == codigo);

        return documento != null ? MapToDTO(documento) : null;
    }

    public async Task<DocumentoDTO?> GetByQRCodeAsync(string codigoQR)
    {
        var documento = await _context.Documentos
            .Include(d => d.TipoDocumento)
            .Include(d => d.AreaOrigen)
            .Include(d => d.Responsable)
            .FirstOrDefaultAsync(d => d.CodigoQR == codigoQR);

        return documento != null ? MapToDTO(documento) : null;
    }

    public async Task<IEnumerable<DocumentoDTO>> BuscarAsync(BusquedaDocumentoDTO busqueda)
    {
        var query = _context.Documentos
            .Include(d => d.TipoDocumento)
            .Include(d => d.AreaOrigen)
            .Include(d => d.Responsable)
            .AsQueryable();

        if (!string.IsNullOrEmpty(busqueda.Codigo))
            query = query.Where(d => d.Codigo.Contains(busqueda.Codigo));

        if (!string.IsNullOrEmpty(busqueda.NumeroCorrelativo))
            query = query.Where(d => d.NumeroCorrelativo.Contains(busqueda.NumeroCorrelativo));

        if (busqueda.TipoDocumentoId.HasValue)
            query = query.Where(d => d.TipoDocumentoId == busqueda.TipoDocumentoId.Value);

        if (busqueda.AreaOrigenId.HasValue)
            query = query.Where(d => d.AreaOrigenId == busqueda.AreaOrigenId.Value);

        if (!string.IsNullOrEmpty(busqueda.Gestion))
            query = query.Where(d => d.Gestion == busqueda.Gestion);

        if (busqueda.FechaDesde.HasValue)
            query = query.Where(d => d.FechaDocumento >= busqueda.FechaDesde.Value);

        if (busqueda.FechaHasta.HasValue)
            query = query.Where(d => d.FechaDocumento <= busqueda.FechaHasta.Value);

        if (!string.IsNullOrEmpty(busqueda.Estado))
            query = query.Where(d => d.Estado == busqueda.Estado);

        if (!string.IsNullOrEmpty(busqueda.CodigoQR))
            query = query.Where(d => d.CodigoQR == busqueda.CodigoQR);

        return await query.Select(d => MapToDTO(d)).ToListAsync();
    }

    public async Task<DocumentoDTO> CreateAsync(CreateDocumentoDTO dto)
    {
        // Generar código único
        var codigo = await GenerarCodigoUnicoAsync(dto.Gestion, dto.TipoDocumentoId);

        // Generar código QR
        var codigoQR = await _qrCodeService.GenerarCodigoQRAsync(codigo);

        var documento = new Documento
        {
            Codigo = codigo,
            NumeroCorrelativo = dto.NumeroCorrelativo,
            TipoDocumentoId = dto.TipoDocumentoId,
            AreaOrigenId = dto.AreaOrigenId,
            Gestion = dto.Gestion,
            FechaDocumento = dto.FechaDocumento,
            Descripcion = dto.Descripcion,
            ResponsableId = dto.ResponsableId,
            UbicacionFisica = dto.UbicacionFisica,
            CodigoQR = codigoQR,
            Estado = "Activo",
            FechaRegistro = DateTime.UtcNow,
            FechaActualizacion = DateTime.UtcNow,
        };

        _context.Documentos.Add(documento);
        await _context.SaveChangesAsync();

        // Registrar movimiento de entrada inicial
        var movimiento = new Movimiento
        {
            DocumentoId = documento.Id,
            TipoMovimiento = "Entrada",
            AreaOrigenId = dto.AreaOrigenId,
            FechaMovimiento = DateTime.UtcNow,
            Estado = "Activo"
        };

        _context.Movimientos.Add(movimiento);
        await _context.SaveChangesAsync();

        return await GetByIdAsync(documento.Id) ?? throw new Exception("Error al crear documento");
    }

    public async Task<DocumentoDTO?> UpdateAsync(int id, UpdateDocumentoDTO dto)
    {
        var documento = await _context.Documentos.FindAsync(id);
        if (documento == null) return null;

        if (!string.IsNullOrEmpty(dto.Descripcion))
            documento.Descripcion = dto.Descripcion;

        if (dto.ResponsableId.HasValue)
            documento.ResponsableId = dto.ResponsableId.Value;

        if (!string.IsNullOrEmpty(dto.UbicacionFisica))
            documento.UbicacionFisica = dto.UbicacionFisica;

        if (!string.IsNullOrEmpty(dto.Estado))
            documento.Estado = dto.Estado;

        documento.FechaActualizacion = DateTime.UtcNow;

        await _context.SaveChangesAsync();
        return await GetByIdAsync(id);
    }

    public async Task<bool> DeleteAsync(int id)
    {
        var documento = await _context.Documentos.FindAsync(id);
        if (documento == null) return false;

        _context.Documentos.Remove(documento);
        await _context.SaveChangesAsync();
        return true;
    }

    private async Task<string> GenerarCodigoUnicoAsync(string gestion, int tipoDocumentoId)
    {
        var tipoDoc = await _context.TiposDocumento.FindAsync(tipoDocumentoId);
        var prefijo = tipoDoc?.Codigo ?? "DOC";
        var contador = await _context.Documentos
            .CountAsync(d => d.Gestion == gestion && d.TipoDocumentoId == tipoDocumentoId);

        return $"{prefijo}-{gestion}-{contador + 1:D6}";
    }

    public async Task<IEnumerable<MovimientoDTO>> GetDocumentoHistorialAsync(int documentoId)
    {
        // Verificar que el documento exista
        var documentoExiste = await _context.Documentos.AnyAsync(d => d.Id == documentoId);
        if (!documentoExiste)
        {
            throw new KeyNotFoundException($"No se encontró un documento con el ID {documentoId}");
        }

        var movimientos = await _context.Movimientos
            .Where(m => m.DocumentoId == documentoId)
            .Include(m => m.AreaOrigen)
            .Include(m => m.AreaDestino)
            .Include(m => m.Usuario)
            .OrderByDescending(m => m.FechaMovimiento)
            .Select(m => new MovimientoDTO
            {
                Id = m.Id,
                DocumentoId = m.DocumentoId,
                TipoMovimiento = m.TipoMovimiento,
                AreaOrigenId = m.AreaOrigenId,
                AreaOrigenNombre = m.AreaOrigen != null ? m.AreaOrigen.Nombre : null,
                AreaDestinoId = m.AreaDestinoId,
                AreaDestinoNombre = m.AreaDestino != null ? m.AreaDestino.Nombre : null,
                UsuarioId = m.UsuarioId,
                UsuarioNombre = m.Usuario != null ? m.Usuario.NombreCompleto : null,
                Observaciones = m.Observaciones,
                FechaMovimiento = m.FechaMovimiento,
                FechaDevolucion = m.FechaDevolucion,
                Estado = m.Estado
            })
            .ToListAsync();

        return movimientos;
    }

    private static DocumentoDTO MapToDTO(Documento d)
    {
        return new DocumentoDTO
        {
            Id = d.Id,
            Codigo = d.Codigo,
            NumeroCorrelativo = d.NumeroCorrelativo,
            TipoDocumentoId = d.TipoDocumentoId,
            TipoDocumentoNombre = d.TipoDocumento?.Nombre,
            AreaOrigenId = d.AreaOrigenId,
            AreaOrigenNombre = d.AreaOrigen?.Nombre,
            Gestion = d.Gestion,
            FechaDocumento = d.FechaDocumento,
            Descripcion = d.Descripcion,
            ResponsableId = d.ResponsableId,
            ResponsableNombre = d.Responsable?.NombreCompleto,
            CodigoQR = d.CodigoQR,
            UbicacionFisica = d.UbicacionFisica,
            Estado = d.Estado,
            FechaRegistro = d.FechaRegistro
        };
    }
}

