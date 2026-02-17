using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SistemaGestionDocumental.Models;

[Table("carpetas")]
public class Carpeta
{
    [Key]
    [Column("id")]
    public int Id { get; set; }

    [Required]
    [Column("nombre")]
    [StringLength(100)]
    public string Nombre { get; set; } = string.Empty;

    [Column("codigo")]
    [StringLength(20)]
    public string? Codigo { get; set; }

    [Required]
    [Column("gestion")]
    [StringLength(4)]
    [RegularExpression(@"^[0-9]{4}$", ErrorMessage = "La gestión debe tener 4 dígitos")]
    public string Gestion { get; set; } = string.Empty;

    [Column("descripcion")]
    [StringLength(300)]
    public string? Descripcion { get; set; }

    [Column("rango_inicio")]
    public int? RangoInicio { get; set; }

    [Column("rango_fin")]
    public int? RangoFin { get; set; }

    [Column("tipo")]
    [StringLength(50)]
    public string? Tipo { get; set; }

    [Column("carpeta_padre_id")]
    public int? CarpetaPadreId { get; set; }

    [ForeignKey("CarpetaPadreId")]
    public virtual Carpeta? CarpetaPadre { get; set; }

    [Column("activo")]
    public bool Activo { get; set; } = true;

    [Column("fecha_creacion")]
    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;

    [Column("usuario_creacion_id")]
    public int? UsuarioCreacionId { get; set; }

    [ForeignKey("UsuarioCreacionId")]
    public virtual Usuario? UsuarioCreacion { get; set; }

    // Relaciones
    public virtual ICollection<Carpeta> Subcarpetas { get; set; } = new List<Carpeta>();
    public virtual ICollection<Documento> Documentos { get; set; } = new List<Documento>();
}
