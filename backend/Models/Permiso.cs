using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SistemaGestionDocumental.Models;

[Table("permisos")]
public class Permiso
{
    [Key]
    [Column("id")]
    public int Id { get; set; }

    [Required]
    [Column("codigo")]
    [StringLength(50)]
    public string Codigo { get; set; } = string.Empty;

    [Required]
    [Column("nombre")]
    [StringLength(100)]
    public string Nombre { get; set; } = string.Empty;

    [Column("descripcion")]
    [StringLength(500)]
    public string? Descripcion { get; set; }

    [Column("modulo")]
    [StringLength(50)]
    public string Modulo { get; set; } = "Documentos";

    [Column("activo")]
    public bool Activo { get; set; } = true;

    // Relación muchos a muchos con roles
    public virtual ICollection<RolPermiso> RolPermisos { get; set; } = new List<RolPermiso>();
}
