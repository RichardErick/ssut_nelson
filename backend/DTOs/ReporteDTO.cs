namespace SistemaGestionDocumental.DTOs;

public class ReporteMovimientosDTO
{
    public DateTime FechaDesde { get; set; }
    public DateTime FechaHasta { get; set; }
    public int? AreaId { get; set; }
    public string? TipoMovimiento { get; set; }
}

public class ReporteDocumentosDTO
{
    public string? Gestion { get; set; }
    public int? TipoDocumentoId { get; set; }
    public int? AreaOrigenId { get; set; }
    public string? Estado { get; set; }
}

public class EstadisticaDocumentoDTO
{
    public int TotalDocumentos { get; set; }
    public int DocumentosActivos { get; set; }
    public int DocumentosPrestados { get; set; }
    public int DocumentosArchivados { get; set; }
    public int MovimientosMes { get; set; }
    public Dictionary<string, int> DocumentosPorTipo { get; set; } = new();
    public Dictionary<string, int> DocumentosPorArea { get; set; } = new();
    public Dictionary<string, int> MovimientosPorTipo { get; set; } = new();
}

