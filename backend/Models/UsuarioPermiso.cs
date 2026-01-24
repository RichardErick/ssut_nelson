using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SistemaGestionDocumental.Models;

[Table("usuario_permisos")]
public class UsuarioPermiso
{
    [Key]
    [Column("id")]
    public int Id { get; set; }

    [Required]
    [Column("usuario_id")]
    public int UsuarioId { get; set; }

    [ForeignKey("UsuarioId")]
    public virtual Usuario Usuario { get; set; } = null!;

    [Required]
    [Column("permiso_id")]
    public int PermisoId { get; set; }

    [ForeignKey("PermisoId")]
    public virtual Permiso Permiso { get; set; } = null!;

    [Column("activo")]
    public bool Activo { get; set; } = true;

    [Column("denegado")]
    public bool Denegado { get; set; } = false;

    [Column("fecha_asignacion")]
    public DateTime FechaAsignacion { get; set; } = DateTime.UtcNow;
}
