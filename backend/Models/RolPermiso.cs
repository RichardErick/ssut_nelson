using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SistemaGestionDocumental.Models;

[Table("rol_permisos")]
public class RolPermiso
{
    [Key]
    [Column("id")]
    public int Id { get; set; }

    [Required]
    [Column("rol")]
    [StringLength(50)]
    public string Rol { get; set; } = string.Empty;

    [Required]
    [Column("permiso_id")]
    public int PermisoId { get; set; }

    [ForeignKey("PermisoId")]
    public virtual Permiso Permiso { get; set; } = null!;

    [Column("activo")]
    public bool Activo { get; set; } = true;

    [Column("fecha_asignacion")]
    public DateTime FechaAsignacion { get; set; } = DateTime.UtcNow;
}
