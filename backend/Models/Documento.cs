using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SistemaGestionDocumental.Models;

[Table("documentos")]
public class Documento
{
    [Key]
    [Column("id")]
    public int Id { get; set; }

    [Column("uuid")]
    public Guid Uuid { get; set; } = Guid.NewGuid();

    [Required]
    [Column("codigo")]
    [StringLength(50)]
    public string Codigo { get; set; } = string.Empty;

    [Required]
    [Column("numero_correlativo")]
    [StringLength(50)]
    public string NumeroCorrelativo { get; set; } = string.Empty;

    [Required]
    [Column("tipo_documento_id")]
    public int TipoDocumentoId { get; set; }

    [ForeignKey("TipoDocumentoId")]
    public virtual TipoDocumento? TipoDocumento { get; set; }

    [Required]
    [Column("area_origen_id")]
    public int AreaOrigenId { get; set; }

    [ForeignKey("AreaOrigenId")]
    public virtual Area? AreaOrigen { get; set; }

    [Required]
    [Column("area_actual_id")]
    public int AreaActualId { get; set; }

    [ForeignKey("AreaActualId")]
    public virtual Area? AreaActual { get; set; }

    [Required]
    [Column("gestion")]
    [StringLength(4)]
    [RegularExpression(@"^[0-9]{4}$", ErrorMessage = "La gestión debe tener 4 dígitos")]
    public string Gestion { get; set; } = string.Empty;

    [Column("fecha_documento")]
    public DateTime FechaDocumento { get; set; }

    [Column("descripcion")]
    public string? Descripcion { get; set; }

    [Column("responsable_id")]
    public int? ResponsableId { get; set; }

    [ForeignKey("ResponsableId")]
    public virtual Usuario? Responsable { get; set; }

    [Column("codigo_qr", TypeName = "text")]
    public string? CodigoQR { get; set; }

    [Column("url_qr")]
    [StringLength(500)]
    public string? UrlQR { get; set; }

    [Column("id_documento")]
    [StringLength(100)]
    public string? IdDocumento { get; set; }

    [Column("carpeta_id")]
    public int? CarpetaId { get; set; }

    [ForeignKey("CarpetaId")]
    public virtual Carpeta? Carpeta { get; set; }

    [Column("ubicacion_fisica")]
    [StringLength(200)]
    public string? UbicacionFisica { get; set; }

    [Column("estado")]
    public EstadoDocumento Estado { get; set; } = EstadoDocumento.Activo;

    [Column("activo")]
    public bool Activo { get; set; } = true;

    [Column("nivel_confidencialidad")]
    [Range(1, 5, ErrorMessage = "El nivel de confidencialidad debe estar entre 1 y 5")]
    public int NivelConfidencialidad { get; set; } = 1;

    [Column("fecha_vencimiento")]
    public DateTime? FechaVencimiento { get; set; }

    [Column("fecha_registro")]
    public DateTime FechaRegistro { get; set; } = DateTime.UtcNow;

    [Column("fecha_actualizacion")]
    public DateTime FechaActualizacion { get; set; } = DateTime.UtcNow;

    // Relaciones
    public virtual ICollection<Movimiento> Movimientos { get; set; } = new List<Movimiento>();
    public virtual ICollection<Anexo> Anexos { get; set; } = new List<Anexo>();
    public virtual ICollection<HistorialDocumento> HistorialDocumentos { get; set; } = new List<HistorialDocumento>();
    public virtual ICollection<Alerta> Alertas { get; set; } = new List<Alerta>();
    public virtual ICollection<DocumentoPalabraClave> DocumentoPalabrasClaves { get; set; } = new List<DocumentoPalabraClave>();
}

