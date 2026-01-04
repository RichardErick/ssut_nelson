using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SistemaGestionDocumental.Models;

[Table("anexos")]
public class Anexo
{
    [Key]
    [Column("id")]
    public int Id { get; set; }

    [Required]
    [Column("documento_id")]
    public int DocumentoId { get; set; }

    [ForeignKey("DocumentoId")]
    public virtual Documento? Documento { get; set; }

    [Required]
    [Column("nombre_archivo")]
    [StringLength(255)]
    public string NombreArchivo { get; set; } = string.Empty;

    [Column("extension")]
    [StringLength(10)]
    public string? Extension { get; set; }

    [Column("tamano")]
    public int? Tamano { get; set; }

    [Column("url_archivo")]
    [StringLength(500)]
    public string? UrlArchivo { get; set; }

    [Column("tipo_contenido")]
    [StringLength(100)]
    public string? TipoContenido { get; set; }

    [Column("fecha_registro")]
    public DateTime FechaRegistro { get; set; } = DateTime.UtcNow;

    [Column("activo")]
    public bool Activo { get; set; } = true;
}
