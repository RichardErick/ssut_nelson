using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SistemaGestionDocumental.Data;
using SistemaGestionDocumental.DTOs;
using SistemaGestionDocumental.Models;

using SistemaGestionDocumental.Services;
using System.Text.RegularExpressions;

namespace SistemaGestionDocumental.Controllers;

[ApiController]
[Route("api/[controller]")]
public class DocumentosController : ControllerBase
{
    private readonly ApplicationDbContext _context;
    private readonly ILogger<DocumentosController> _logger;
    private readonly IQRService _qrService;
    private readonly IConfiguration _configuration;

    public DocumentosController(ApplicationDbContext context, ILogger<DocumentosController> logger, IQRService qrService, IConfiguration configuration)
    {
        _context = context;
        _logger = logger;
        _qrService = qrService;
        _configuration = configuration;
    }

    // GET: api/documentos
    [HttpGet]
    public async Task<ActionResult<PaginatedResultDTO<DocumentoDTO>>> GetAll(
        [FromQuery] bool incluirInactivos = false,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20)
    {
        var query = _context.Documentos
            .Include(d => d.TipoDocumento)
            .Include(d => d.AreaOrigen)
            .Include(d => d.Responsable)
            .Include(d => d.Carpeta)
                .ThenInclude(c => c!.CarpetaPadre)
            .Include(d => d.DocumentoPalabrasClaves)
                .ThenInclude(dpc => dpc.PalabraClave)
            .AsQueryable();

        // Filtrar por estado activo
        if (!incluirInactivos)
        {
            query = query.Where(d => d.Activo);
        }

        var totalItems = await query.CountAsync();
        var totalPages = (int)Math.Ceiling(totalItems / (double)pageSize);

        var documentos = await query
            .OrderByDescending(d => d.FechaDocumento)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(d => new DocumentoDTO
            {
                Id = d.Id,
                IdDocumento = d.IdDocumento ?? string.Empty,
                Codigo = d.Codigo,
                NumeroCorrelativo = d.NumeroCorrelativo,
                Gestion = d.Gestion,
                FechaDocumento = d.FechaDocumento,
                Descripcion = d.Descripcion,
                CodigoQR = d.CodigoQR,
                UrlQR = d.UrlQR,
                UbicacionFisica = d.UbicacionFisica,
                Estado = d.Estado.ToString(),
                Activo = d.Activo,
                NivelConfidencialidad = d.NivelConfidencialidad,
                FechaRegistro = d.FechaRegistro,
                FechaActualizacion = d.FechaActualizacion,
                TipoDocumentoId = d.TipoDocumentoId,
                TipoDocumentoNombre = d.TipoDocumento != null ? d.TipoDocumento.Nombre : null,
                TipoDocumentoCodigo = d.TipoDocumento != null ? d.TipoDocumento.Codigo : null,
                AreaOrigenId = d.AreaOrigenId,
                AreaOrigenNombre = d.AreaOrigen != null ? d.AreaOrigen.Nombre : null,
                AreaOrigenCodigo = d.AreaOrigen != null ? d.AreaOrigen.Codigo : null,
                ResponsableId = d.ResponsableId,
                ResponsableNombre = d.Responsable != null ? d.Responsable.NombreCompleto : null,
                CarpetaId = d.CarpetaId,
                CarpetaNombre = d.Carpeta != null ? d.Carpeta.Nombre : null,
                CarpetaPadreNombre = d.Carpeta != null && d.Carpeta.CarpetaPadre != null ? d.Carpeta.CarpetaPadre.Nombre : null,
                PalabrasClave = d.DocumentoPalabrasClaves.Select(dpc => dpc.PalabraClave.Palabra).ToList()
            })
            .ToListAsync();

        return Ok(new PaginatedResultDTO<DocumentoDTO>
        {
            Items = documentos,
            TotalItems = totalItems,
            Page = page,
            PageSize = pageSize,
            TotalPages = totalPages
        });
    }

    // GET: api/documentos/{id}
    [HttpGet("{id}")]
    public async Task<ActionResult<DocumentoDTO>> GetById(int id)
    {
        var documento = await _context.Documentos
            .Include(d => d.TipoDocumento)
            .Include(d => d.AreaOrigen)
            .Include(d => d.Responsable)
            .Include(d => d.Carpeta)
                .ThenInclude(c => c!.CarpetaPadre)
            .Include(d => d.DocumentoPalabrasClaves)
                .ThenInclude(dpc => dpc.PalabraClave)
            .Where(d => d.Id == id)
            .Select(d => new DocumentoDTO
            {
                Id = d.Id,
                IdDocumento = d.IdDocumento ?? string.Empty,
                Codigo = d.Codigo,
                NumeroCorrelativo = d.NumeroCorrelativo,
                Gestion = d.Gestion,
                FechaDocumento = d.FechaDocumento,
                Descripcion = d.Descripcion,
                CodigoQR = d.CodigoQR,
                UrlQR = d.UrlQR,
                UbicacionFisica = d.UbicacionFisica,
                Estado = d.Estado.ToString(),
                Activo = d.Activo,
                NivelConfidencialidad = d.NivelConfidencialidad,
                FechaRegistro = d.FechaRegistro,
                FechaActualizacion = d.FechaActualizacion,
                TipoDocumentoId = d.TipoDocumentoId,
                TipoDocumentoNombre = d.TipoDocumento != null ? d.TipoDocumento.Nombre : null,
                TipoDocumentoCodigo = d.TipoDocumento != null ? d.TipoDocumento.Codigo : null,
                AreaOrigenId = d.AreaOrigenId,
                AreaOrigenNombre = d.AreaOrigen != null ? d.AreaOrigen.Nombre : null,
                AreaOrigenCodigo = d.AreaOrigen != null ? d.AreaOrigen.Codigo : null,
                ResponsableId = d.ResponsableId,
                ResponsableNombre = d.Responsable != null ? d.Responsable.NombreCompleto : null,
                CarpetaId = d.CarpetaId,
                CarpetaNombre = d.Carpeta != null ? d.Carpeta.Nombre : null,
                CarpetaPadreNombre = d.Carpeta != null && d.Carpeta.CarpetaPadre != null ? d.Carpeta.CarpetaPadre.Nombre : null,
                PalabrasClave = d.DocumentoPalabrasClaves.Select(dpc => dpc.PalabraClave.Palabra).ToList()
            })
            .FirstOrDefaultAsync();

        if (documento == null)
            return NotFound(new { message = "Documento no encontrado" });

        return Ok(documento);
    }

    // GET: api/documentos/ficha/{idDocumento}
    [HttpGet("ficha/{idDocumento}")]
    [AllowAnonymous]
    public async Task<ActionResult<DocumentoDTO>> GetByIdDocumento(string idDocumento)
    {
        var documento = await _context.Documentos
            .Include(d => d.TipoDocumento)
            .Include(d => d.AreaOrigen)
            .Include(d => d.Responsable)
            .Include(d => d.Carpeta)
                .ThenInclude(c => c!.CarpetaPadre)
            .Include(d => d.DocumentoPalabrasClaves)
                .ThenInclude(dpc => dpc.PalabraClave)
            .Where(d => d.IdDocumento == idDocumento)
            .FirstOrDefaultAsync();

        if (documento == null)
            return NotFound(new { message = "Documento no encontrado" });

        // TODO: Verificar permisos de usuario si está autenticado
        // TODO: Registrar acceso en auditoría

        var result = new DocumentoDTO
        {
            Id = documento.Id,
            IdDocumento = documento.IdDocumento ?? string.Empty,
            Codigo = documento.Codigo,
            NumeroCorrelativo = documento.NumeroCorrelativo,
            Gestion = documento.Gestion,
            FechaDocumento = documento.FechaDocumento,
            Descripcion = documento.Descripcion,
            CodigoQR = documento.CodigoQR,
            UrlQR = documento.UrlQR,
            UbicacionFisica = documento.UbicacionFisica,
            Estado = documento.Estado.ToString(),
            Activo = documento.Activo,
            NivelConfidencialidad = documento.NivelConfidencialidad,
            FechaRegistro = documento.FechaRegistro,
            FechaActualizacion = documento.FechaActualizacion,
            TipoDocumentoId = documento.TipoDocumentoId,
            TipoDocumentoNombre = documento.TipoDocumento?.Nombre,
            TipoDocumentoCodigo = documento.TipoDocumento?.Codigo,
            AreaOrigenId = documento.AreaOrigenId,
            AreaOrigenNombre = documento.AreaOrigen?.Nombre,
            AreaOrigenCodigo = documento.AreaOrigen?.Codigo,
            ResponsableId = documento.ResponsableId,
            ResponsableNombre = documento.Responsable?.NombreCompleto,
            CarpetaId = documento.CarpetaId,
            CarpetaNombre = documento.Carpeta?.Nombre,
            CarpetaPadreNombre = documento.Carpeta?.CarpetaPadre?.Nombre,
            PalabrasClave = documento.DocumentoPalabrasClaves.Select(dpc => dpc.PalabraClave.Palabra).ToList()
        };

        return Ok(result);
    }

    // POST: api/documentos
    [HttpPost]
    public async Task<ActionResult<DocumentoDTO>> Create([FromBody] CreateDocumentoDTO dto)
    {
        var numeroCorrelativo = dto.NumeroCorrelativo?.Trim();
        var gestion = dto.Gestion?.Trim();

        // Validaciones
        // Normalizamos a solo dígitos para evitar errores por espacios/separadores
        var correlativoDigits = string.IsNullOrWhiteSpace(numeroCorrelativo)
            ? string.Empty
            : Regex.Replace(numeroCorrelativo, @"\D", "");

        if (string.IsNullOrWhiteSpace(correlativoDigits) || correlativoDigits.Length > 6)
            return BadRequest(new { message = "El número correlativo debe tener entre 1 y 6 dígitos numéricos" });

        if (string.IsNullOrWhiteSpace(gestion) || !Regex.IsMatch(gestion, @"^[0-9]{4}$"))
            return BadRequest(new { message = "La gestión debe tener 4 dígitos numéricos" });

        if (dto.NivelConfidencialidad < 1 || dto.NivelConfidencialidad > 5)
            return BadRequest(new { message = "El nivel de confidencialidad debe estar entre 1 y 5" });

        // Verificar que tipo de documento existe
        var tipoDocumento = await _context.TiposDocumento.FindAsync(dto.TipoDocumentoId);
        if (tipoDocumento == null)
            return BadRequest(new { message = "Tipo de documento no encontrado" });

        // Verificar que área existe
        var area = await _context.Areas.FindAsync(dto.AreaOrigenId);
        if (area == null)
            return BadRequest(new { message = "Área no encontrada" });

        // Verificar responsable si se proporciona
        if (dto.ResponsableId.HasValue)
        {
            var responsable = await _context.Usuarios.FindAsync(dto.ResponsableId.Value);
            if (responsable == null)
                return BadRequest(new { message = "Responsable no encontrado" });
        }

        // Verificar carpeta si se proporciona
        if (dto.CarpetaId.HasValue)
        {
            var carpeta = await _context.Carpetas.FindAsync(dto.CarpetaId.Value);
            if (carpeta == null)
                return BadRequest(new { message = "Carpeta no encontrada" });
        }

        var correlativoFormateado = correlativoDigits.PadLeft(4, '0');
        var tipoCodigo = (tipoDocumento.Codigo ?? "DOC").ToUpperInvariant();
        var areaCodigo = (area.Codigo ?? "AREA").ToUpperInvariant();

        // Generar código único
        var codigo = $"{tipoCodigo}-{areaCodigo}-{gestion}-{correlativoFormateado}";

        // Verificar que el código no exista
        var codigoExists = await _context.Documentos.AnyAsync(d => d.Codigo == codigo);
        if (codigoExists)
            return BadRequest(new { message = "Ya existe un documento con ese código" });

        var documento = new Documento
        {
            Codigo = codigo,
            NumeroCorrelativo = correlativoFormateado,
            TipoDocumentoId = dto.TipoDocumentoId,
            AreaOrigenId = dto.AreaOrigenId,
            AreaActualId = dto.AreaOrigenId, // Inicialmente es la misma
            Gestion = gestion,
            FechaDocumento = DateTime.SpecifyKind(dto.FechaDocumento, DateTimeKind.Utc),
            Descripcion = dto.Descripcion,
            ResponsableId = dto.ResponsableId,
            UbicacionFisica = dto.UbicacionFisica,
            CarpetaId = dto.CarpetaId,
            NivelConfidencialidad = dto.NivelConfidencialidad,
            Estado = EstadoDocumento.Activo,
            Activo = true,
            FechaRegistro = DateTime.UtcNow,
            FechaActualizacion = DateTime.UtcNow
        };

        // Generar QR automáticamente
        try 
        {
            var baseUrl = _configuration["FrontendUrl"] ?? "http://localhost:5286";
            documento.IdDocumento = documento.Codigo; 
            var qrContent = $"{baseUrl}/documentos/ver/{documento.IdDocumento}";
            documento.UrlQR = qrContent;
            documento.CodigoQR = _qrService.GenerarQRBase64(qrContent);
        }
        catch (Exception qrEx)
        {
            _logger.LogWarning(qrEx, "No se pudo generar el QR automáticamente, pero el documento se creará.");
        }

        try
        {
            _context.Documentos.Add(documento);
            documento.FechaActualizacion = DateTime.UtcNow;

            await _context.SaveChangesAsync();
            
            // Cargar el documento completo con relaciones para devolver el DTO correcto
            var documentoCompleto = await _context.Documentos
                .Include(d => d.TipoDocumento)
                .Include(d => d.AreaOrigen)
                .Include(d => d.Responsable)
                .Include(d => d.Carpeta)
                    .ThenInclude(c => c!.CarpetaPadre)
                .Include(d => d.DocumentoPalabrasClaves)
                    .ThenInclude(dpc => dpc.PalabraClave)
                .FirstOrDefaultAsync(d => d.Id == documento.Id);

            if (documentoCompleto == null)
            {
                // Fallback por si acaso (no debería ocurrir)
                return CreatedAtAction(nameof(GetById), new { id = documento.Id }, documento);
            }

            // Asegurar QR si el trigger asignó IdDocumento distinto
            try
            {
                var idDoc = string.IsNullOrWhiteSpace(documentoCompleto.IdDocumento)
                    ? documentoCompleto.Codigo
                    : documentoCompleto.IdDocumento;

                if (string.IsNullOrWhiteSpace(documentoCompleto.CodigoQR) || string.IsNullOrWhiteSpace(documentoCompleto.UrlQR))
                {
                    var baseUrl = _configuration["FrontendUrl"] ?? "http://localhost:5286";
                    var qrContent = $"{baseUrl}/documentos/ver/{idDoc}";
                    documentoCompleto.UrlQR = qrContent;
                    documentoCompleto.CodigoQR = _qrService.GenerarQRBase64(qrContent);
                    documentoCompleto.FechaActualizacion = DateTime.UtcNow;
                    await _context.SaveChangesAsync();
                }
            }
            catch (Exception qrEx)
            {
                _logger.LogWarning(qrEx, "No se pudo generar el QR después de guardar el documento.");
            }

            var resultDto = new DocumentoDTO
            {
                Id = documentoCompleto.Id,
                IdDocumento = documentoCompleto.IdDocumento ?? string.Empty,
                Codigo = documentoCompleto.Codigo,
                NumeroCorrelativo = documentoCompleto.NumeroCorrelativo,
                Gestion = documentoCompleto.Gestion,
                FechaDocumento = documentoCompleto.FechaDocumento,
                Descripcion = documentoCompleto.Descripcion,
                CodigoQR = documentoCompleto.CodigoQR,
                UrlQR = documentoCompleto.UrlQR,
                UbicacionFisica = documentoCompleto.UbicacionFisica,
                Estado = documentoCompleto.Estado.ToString(),
                Activo = documentoCompleto.Activo,
                NivelConfidencialidad = documentoCompleto.NivelConfidencialidad,
                FechaRegistro = documentoCompleto.FechaRegistro,
                FechaActualizacion = documentoCompleto.FechaActualizacion,
                TipoDocumentoId = documentoCompleto.TipoDocumentoId,
                TipoDocumentoNombre = documentoCompleto.TipoDocumento != null ? documentoCompleto.TipoDocumento.Nombre : null,
                TipoDocumentoCodigo = documentoCompleto.TipoDocumento != null ? documentoCompleto.TipoDocumento.Codigo : null,
                AreaOrigenId = documentoCompleto.AreaOrigenId,
                AreaOrigenNombre = documentoCompleto.AreaOrigen != null ? documentoCompleto.AreaOrigen.Nombre : null,
                AreaOrigenCodigo = documentoCompleto.AreaOrigen != null ? documentoCompleto.AreaOrigen.Codigo : null,
                ResponsableId = documentoCompleto.ResponsableId,
                ResponsableNombre = documentoCompleto.Responsable != null ? documentoCompleto.Responsable.NombreCompleto : null,
                CarpetaId = documentoCompleto.CarpetaId,
                CarpetaNombre = documentoCompleto.Carpeta != null ? documentoCompleto.Carpeta.Nombre : null,
                CarpetaPadreNombre = documentoCompleto.Carpeta != null && documentoCompleto.Carpeta.CarpetaPadre != null ? documentoCompleto.Carpeta.CarpetaPadre.Nombre : null,
                PalabrasClave = documentoCompleto.DocumentoPalabrasClaves.Select(dpc => dpc.PalabraClave.Palabra).ToList()
            };

            // TODO: Registrar en auditoría

            return CreatedAtAction(nameof(GetById), new { id = documento.Id }, resultDto);
        }
        catch (DbUpdateException ex)
        {
            _logger.LogError(ex, "Error al crear documento con código {Codigo}", codigo);
            var innerMessage = ex.InnerException?.Message ?? ex.Message;

            if (innerMessage.Contains("codigo_formato", StringComparison.OrdinalIgnoreCase))
            {
                return BadRequest(new { message = "Formato de código inválido. Debe ser TIPO-AREA-GESTION-#### con número correlativo numérico." });
            }

            if (innerMessage.Contains("documentos_codigo_key", StringComparison.OrdinalIgnoreCase) ||
                innerMessage.Contains("duplicate key", StringComparison.OrdinalIgnoreCase))
            {
                return BadRequest(new { message = "Ya existe un documento con ese código. Ajuste el número correlativo." });
            }

            return StatusCode(StatusCodes.Status500InternalServerError, new { message = $"No se pudo guardar el documento en la base de datos. Detalle: {innerMessage}" });
        }
    }

    // PUT: api/documentos/{id}
    [HttpPut("{id}")]
    public async Task<ActionResult> Update(int id, [FromBody] UpdateDocumentoDTO dto)
    {
        var documento = await _context.Documentos
            .Include(d => d.DocumentoPalabrasClaves)
            .FirstOrDefaultAsync(d => d.Id == id);

        if (documento == null)
            return NotFound(new { message = "Documento no encontrado" });

        // Actualizar campos si se proporcionan
        if (!string.IsNullOrWhiteSpace(dto.NumeroCorrelativo))
            documento.NumeroCorrelativo = dto.NumeroCorrelativo;

        if (dto.TipoDocumentoId.HasValue)
        {
            var tipoDocumento = await _context.TiposDocumento.FindAsync(dto.TipoDocumentoId.Value);
            if (tipoDocumento == null)
                return BadRequest(new { message = "Tipo de documento no encontrado" });
            documento.TipoDocumentoId = dto.TipoDocumentoId.Value;
        }

        if (dto.AreaOrigenId.HasValue)
        {
            var area = await _context.Areas.FindAsync(dto.AreaOrigenId.Value);
            if (area == null)
                return BadRequest(new { message = "Área no encontrada" });
            documento.AreaOrigenId = dto.AreaOrigenId.Value;
        }

        if (!string.IsNullOrWhiteSpace(dto.Gestion))
            documento.Gestion = dto.Gestion;

        if (dto.FechaDocumento.HasValue)
            documento.FechaDocumento = DateTime.SpecifyKind(dto.FechaDocumento.Value, DateTimeKind.Utc);

        if (dto.Descripcion != null)
            documento.Descripcion = dto.Descripcion;

        if (dto.ResponsableId.HasValue)
        {
            var responsable = await _context.Usuarios.FindAsync(dto.ResponsableId.Value);
            if (responsable == null)
                return BadRequest(new { message = "Responsable no encontrado" });
            documento.ResponsableId = dto.ResponsableId.Value;
        }

        if (dto.UbicacionFisica != null)
            documento.UbicacionFisica = dto.UbicacionFisica;

        if (dto.CarpetaId.HasValue)
        {
            var carpeta = await _context.Carpetas.FindAsync(dto.CarpetaId.Value);
            if (carpeta == null)
                return BadRequest(new { message = "Carpeta no encontrada" });
            documento.CarpetaId = dto.CarpetaId.Value;
        }

        if (!string.IsNullOrWhiteSpace(dto.Estado) && Enum.TryParse<EstadoDocumento>(dto.Estado, true, out var nuevoEstado))
            documento.Estado = nuevoEstado;

        if (dto.NivelConfidencialidad.HasValue)
            documento.NivelConfidencialidad = dto.NivelConfidencialidad.Value;

        // Actualizar palabras clave si se proporcionan
        if (dto.PalabrasClaveIds != null)
        {
            // Eliminar palabras clave existentes
            _context.DocumentoPalabrasClaves.RemoveRange(documento.DocumentoPalabrasClaves);

            // Agregar nuevas palabras clave
            foreach (var palabraClaveId in dto.PalabrasClaveIds)
            {
                var palabraClave = await _context.PalabrasClaves.FindAsync(palabraClaveId);
                if (palabraClave != null)
                {
                    _context.DocumentoPalabrasClaves.Add(new DocumentoPalabraClave
                    {
                        DocumentoId = documento.Id,
                        PalabraClaveId = palabraClaveId
                    });
                }
            }
        }

        documento.FechaActualizacion = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        // TODO: Registrar en historial_documento
        // TODO: Registrar en auditoría

        return Ok(new
        {
            documento.Id,
            documento.IdDocumento,
            documento.Codigo,
            documento.FechaActualizacion,
            message = "Documento actualizado exitosamente"
        });
    }

    // DELETE: api/documentos/{id}
    [HttpDelete("{id}")]
    public async Task<ActionResult> Delete(int id, [FromQuery] bool hard = false)
    {
        var documento = await _context.Documentos.FindAsync(id);
        if (documento == null)
            return NotFound(new { message = "Documento no encontrado" });

        if (!hard)
        {
            // Borrado lógico
            documento.Activo = false;
            documento.Estado = EstadoDocumento.Eliminado;
            documento.FechaActualizacion = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            // TODO: Registrar en auditoría

            return Ok(new
            {
                documento.Id,
                documento.Activo,
                documento.Estado,
                message = "Documento eliminado (borrado lógico)"
            });
        }

        // Borrado físico
        _context.Documentos.Remove(documento);
        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException)
        {
            return BadRequest(new
            {
                message = "No se pudo eliminar el documento (tiene relaciones). Usa eliminación lógica (hard=false)"
            });
        }

        // TODO: Registrar en auditoría

        return NoContent();
    }

    // POST: api/documentos/buscar
    [HttpPost("buscar")]
    public async Task<ActionResult<PaginatedResultDTO<DocumentoDTO>>> Buscar([FromBody] BusquedaDocumentoDTO filtros)
    {
        var query = _context.Documentos
            .Include(d => d.TipoDocumento)
            .Include(d => d.AreaOrigen)
            .Include(d => d.Responsable)
            .Include(d => d.Carpeta)
                .ThenInclude(c => c!.CarpetaPadre)
            .Include(d => d.DocumentoPalabrasClaves)
                .ThenInclude(dpc => dpc.PalabraClave)
            .AsQueryable();

        // Aplicar filtros
        if (!filtros.IncluirInactivos)
        {
            query = query.Where(d => d.Activo);
        }

        if (!string.IsNullOrWhiteSpace(filtros.Codigo))
        {
            query = query.Where(d => d.Codigo.Contains(filtros.Codigo));
        }

        if (!string.IsNullOrWhiteSpace(filtros.NumeroCorrelativo))
        {
            query = query.Where(d => d.NumeroCorrelativo.Contains(filtros.NumeroCorrelativo));
        }

        if (filtros.TipoDocumentoId.HasValue)
        {
            query = query.Where(d => d.TipoDocumentoId == filtros.TipoDocumentoId.Value);
        }

        if (filtros.AreaOrigenId.HasValue)
        {
            query = query.Where(d => d.AreaOrigenId == filtros.AreaOrigenId.Value);
        }

        if (!string.IsNullOrWhiteSpace(filtros.Gestion))
        {
            query = query.Where(d => d.Gestion == filtros.Gestion);
        }

        if (filtros.FechaDesde.HasValue)
        {
            var fechaDesdeUtc = DateTime.SpecifyKind(filtros.FechaDesde.Value, DateTimeKind.Utc);
            query = query.Where(d => d.FechaDocumento >= fechaDesdeUtc);
        }

        if (filtros.FechaHasta.HasValue)
        {
            var fechaHastaUtc = DateTime.SpecifyKind(filtros.FechaHasta.Value, DateTimeKind.Utc);
            query = query.Where(d => d.FechaDocumento <= fechaHastaUtc);
        }

        if (!string.IsNullOrWhiteSpace(filtros.Estado) && Enum.TryParse<EstadoDocumento>(filtros.Estado, true, out var estadoFiltro))
        {
            query = query.Where(d => d.Estado == estadoFiltro);
        }

        if (filtros.ResponsableId.HasValue)
        {
            query = query.Where(d => d.ResponsableId == filtros.ResponsableId.Value);
        }

        if (filtros.CarpetaId.HasValue)
        {
            query = query.Where(d => d.CarpetaId == filtros.CarpetaId.Value);
        }

        if (filtros.PalabrasClave != null && filtros.PalabrasClave.Any())
        {
            query = query.Where(d => d.DocumentoPalabrasClaves
                .Any(dpc => filtros.PalabrasClave.Contains(dpc.PalabraClave.Palabra)));
        }

        if (!string.IsNullOrWhiteSpace(filtros.TextoBusqueda))
        {
            var texto = filtros.TextoBusqueda.ToLower();
            query = query.Where(d =>
                d.Codigo.ToLower().Contains(texto) ||
                d.NumeroCorrelativo.ToLower().Contains(texto) ||
                (d.Descripcion != null && d.Descripcion.ToLower().Contains(texto)) ||
                (d.IdDocumento != null && d.IdDocumento.ToLower().Contains(texto))
            );
        }

        // Contar total antes de paginar
        var totalItems = await query.CountAsync();

        // Ordenamiento
        query = (filtros.OrderBy?.ToLower(), filtros.OrderDirection?.ToUpper()) switch
        {
            ("fechadocumento", "ASC") => query.OrderBy(d => d.FechaDocumento),
            ("fechadocumento", "DESC") => query.OrderByDescending(d => d.FechaDocumento),
            ("codigo", "ASC") => query.OrderBy(d => d.Codigo),
            ("codigo", "DESC") => query.OrderByDescending(d => d.Codigo),
            ("gestion", "ASC") => query.OrderBy(d => d.Gestion),
            ("gestion", "DESC") => query.OrderByDescending(d => d.Gestion),
            _ => query.OrderByDescending(d => d.FechaDocumento)
        };

        // Paginación
        var documentos = await query
            .Skip((filtros.Page - 1) * filtros.PageSize)
            .Take(filtros.PageSize)
            .Select(d => new DocumentoDTO
            {
                Id = d.Id,
                IdDocumento = d.IdDocumento ?? string.Empty,
                Codigo = d.Codigo,
                NumeroCorrelativo = d.NumeroCorrelativo,
                Gestion = d.Gestion,
                FechaDocumento = d.FechaDocumento,
                Descripcion = d.Descripcion,
                CodigoQR = d.CodigoQR,
                UrlQR = d.UrlQR,
                UbicacionFisica = d.UbicacionFisica,
                Estado = d.Estado.ToString(),
                Activo = d.Activo,
                NivelConfidencialidad = d.NivelConfidencialidad,
                FechaRegistro = d.FechaRegistro,
                FechaActualizacion = d.FechaActualizacion,
                TipoDocumentoId = d.TipoDocumentoId,
                TipoDocumentoNombre = d.TipoDocumento != null ? d.TipoDocumento.Nombre : null,
                TipoDocumentoCodigo = d.TipoDocumento != null ? d.TipoDocumento.Codigo : null,
                AreaOrigenId = d.AreaOrigenId,
                AreaOrigenNombre = d.AreaOrigen != null ? d.AreaOrigen.Nombre : null,
                AreaOrigenCodigo = d.AreaOrigen != null ? d.AreaOrigen.Codigo : null,
                ResponsableId = d.ResponsableId,
                ResponsableNombre = d.Responsable != null ? d.Responsable.NombreCompleto : null,
                CarpetaId = d.CarpetaId,
                CarpetaNombre = d.Carpeta != null ? d.Carpeta.Nombre : null,
                CarpetaPadreNombre = d.Carpeta != null && d.Carpeta.CarpetaPadre != null ? d.Carpeta.CarpetaPadre.Nombre : null,
                PalabrasClave = d.DocumentoPalabrasClaves.Select(dpc => dpc.PalabraClave.Palabra).ToList()
            })
            .ToListAsync();

        var totalPages = (int)Math.Ceiling(totalItems / (double)filtros.PageSize);

        return Ok(new PaginatedResultDTO<DocumentoDTO>
        {
            Items = documentos,
            TotalItems = totalItems,
            Page = filtros.Page,
            PageSize = filtros.PageSize,
            TotalPages = totalPages
        });
    }

    // POST: api/documentos/mover-lote
    [HttpPost("mover-lote")]
    public async Task<ActionResult> MoverLote([FromBody] MoverDocumentosLoteDTO dto)
    {
        if (dto.DocumentoIds == null || !dto.DocumentoIds.Any())
            return BadRequest(new { message = "Debe proporcionar al menos un documento" });

        // Verificar carpeta destino si se proporciona
        Carpeta? carpetaDestino = null;
        if (dto.CarpetaDestinoId.HasValue)
        {
            carpetaDestino = await _context.Carpetas.FindAsync(dto.CarpetaDestinoId.Value);
            if (carpetaDestino == null)
                return BadRequest(new { message = "Carpeta destino no encontrada" });
        }

        var documentos = await _context.Documentos
            .Where(d => dto.DocumentoIds.Contains(d.Id))
            .ToListAsync();

        if (!documentos.Any())
            return NotFound(new { message = "No se encontraron documentos" });

        var documentosMovidos = 0;
        foreach (var documento in documentos)
        {
            var carpetaAnteriorId = documento.CarpetaId;
            documento.CarpetaId = dto.CarpetaDestinoId;
            documento.FechaActualizacion = DateTime.UtcNow;

            // Registrar en historial
            var historial = new HistorialDocumento
            {
                DocumentoId = documento.Id,
                FechaCambio = DateTime.UtcNow,
                // UsuarioId = TODO: Obtener del contexto de autenticación
                EstadoAnterior = documento.Estado.ToString(),
                EstadoNuevo = documento.Estado.ToString(),
                Observacion = dto.Observaciones ?? "Movimiento en lote de documentos"
            };
            _context.HistorialesDocumento.Add(historial);

            documentosMovidos++;
        }

        await _context.SaveChangesAsync();

        // TODO: Registrar en auditoría

        return Ok(new
        {
            documentosMovidos,
            carpetaDestinoId = dto.CarpetaDestinoId,
            carpetaDestinoNombre = carpetaDestino?.Nombre,
            message = $"{documentosMovidos} documento(s) movido(s) exitosamente"
        });
    }

    // POST: api/documentos/{id}/qr
    [HttpPost("{id}/qr")]
    public async Task<ActionResult> GenerarQR(int id)
    {
        var documento = await _context.Documentos.FindAsync(id);
        if (documento == null)
            return NotFound(new { message = "Documento no encontrado" });

        if (string.IsNullOrEmpty(documento.IdDocumento))
        {
             // Si por alguna razón no tiene IdDocumento, intentamos generarlo o usar el ID numérico
             documento.IdDocumento = documento.Codigo; 
             // Idealmente esto no debería pasar si el trigger funciona
        }

        // Construir URL del QR
        // Usar una configuración base URL o una por defecto
        var baseUrl = _configuration["FrontendUrl"] ?? "http://localhost:5286"; 
        var qrContent = $"{baseUrl}/documentos/ver/{documento.IdDocumento}";

        // Generar imagen base64
        var qrBase64 = _qrService.GenerarQRBase64(qrContent);
        
        // Guardar la URL (contenido) y el código QR (base64) si lo deseamos guardar en BD o devolverlo
        documento.UrlQR = qrContent;
        documento.CodigoQR = qrBase64; // Guardamos el base64 directamente o una referencia
        documento.FechaActualizacion = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        return Ok(new
        {
            documento.Id,
            documento.IdDocumento,
            QrContent = qrContent,
            QrImageBase64 = qrBase64,
            message = "Código QR generado exitosamente"
        });
    }
}
