namespace SistemaGestionDocumental.DTOs;

public class DocumentoDTO
{
    public int Id { get; set; }
    public string IdDocumento { get; set; } = string.Empty;
    public string Codigo { get; set; } = string.Empty;
    public string NumeroCorrelativo { get; set; } = string.Empty;
    public int TipoDocumentoId { get; set; }
    public string? TipoDocumentoNombre { get; set; }
    public string? TipoDocumentoCodigo { get; set; }
    public int AreaOrigenId { get; set; }
    public string? AreaOrigenNombre { get; set; }
    public string? AreaOrigenCodigo { get; set; }
    public string Gestion { get; set; } = string.Empty;
    public DateTime FechaDocumento { get; set; }
    public string? Descripcion { get; set; }
    public int? ResponsableId { get; set; }
    public string? ResponsableNombre { get; set; }
    public string? CodigoQR { get; set; }
    public string? UrlQR { get; set; }
    public string? UbicacionFisica { get; set; }
    public string Estado { get; set; } = string.Empty;
    public bool Activo { get; set; }
    public int NivelConfidencialidad { get; set; }
    public DateTime FechaRegistro { get; set; }
    public DateTime FechaActualizacion { get; set; }
    public int? CarpetaId { get; set; }
    public string? CarpetaNombre { get; set; }
    public string? CarpetaPadreNombre { get; set; }
    public List<string> PalabrasClave { get; set; } = new();
}

public class CreateDocumentoDTO
{
    public string NumeroCorrelativo { get; set; } = string.Empty;
    public int TipoDocumentoId { get; set; }
    public int AreaOrigenId { get; set; }
    public string Gestion { get; set; } = string.Empty;
    public DateTime FechaDocumento { get; set; }
    public string? Descripcion { get; set; }
    public int? ResponsableId { get; set; }
    public string? UbicacionFisica { get; set; }
    public int? CarpetaId { get; set; }
    public List<int>? PalabrasClaveIds { get; set; }
    public int NivelConfidencialidad { get; set; } = 1;
}

public class UpdateDocumentoDTO
{
    public string? NumeroCorrelativo { get; set; }
    public int? TipoDocumentoId { get; set; }
    public int? AreaOrigenId { get; set; }
    public string? Gestion { get; set; }
    public DateTime? FechaDocumento { get; set; }
    public string? Descripcion { get; set; }
    public int? ResponsableId { get; set; }
    public string? UbicacionFisica { get; set; }
    public int? CarpetaId { get; set; }
    public List<int>? PalabrasClaveIds { get; set; }
    public string? Estado { get; set; }
    public int? NivelConfidencialidad { get; set; }
}

public class BusquedaDocumentoDTO
{
    public string? Codigo { get; set; }
    public string? NumeroCorrelativo { get; set; }
    public int? TipoDocumentoId { get; set; }
    public int? AreaOrigenId { get; set; }
    public string? Gestion { get; set; }
    public DateTime? FechaDesde { get; set; }
    public DateTime? FechaHasta { get; set; }
    public string? Estado { get; set; }
    public string? CodigoQR { get; set; }
    public int? ResponsableId { get; set; }
    public List<string>? PalabrasClave { get; set; }
    public int? CarpetaId { get; set; }
    public string? TextoBusqueda { get; set; }
    public bool IncluirInactivos { get; set; } = false;
    
    // Paginación
    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 20;
    
    // Ordenamiento
    public string? OrderBy { get; set; } = "FechaDocumento";
    public string? OrderDirection { get; set; } = "DESC";
}

public class MoverDocumentosLoteDTO
{
    public List<int> DocumentoIds { get; set; } = new();
    public int? CarpetaDestinoId { get; set; }
    public string? Observaciones { get; set; }
}

public class PaginatedResultDTO<T>
{
    public List<T> Items { get; set; } = new();
    public int TotalItems { get; set; }
    public int Page { get; set; }
    public int PageSize { get; set; }
    public int TotalPages { get; set; }
}
