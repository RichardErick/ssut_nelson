using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SistemaGestionDocumental.Models;

[Table("auditoria")]
public class Auditoria
{
    [Key]
    [Column("id")]
    public int Id { get; set; }

    [Column("usuario_id")]
    public int? UsuarioId { get; set; }

    [ForeignKey("UsuarioId")]
    public virtual Usuario? Usuario { get; set; }

    [Required]
    [Column("accion")]
    [StringLength(100)]
    public string Accion { get; set; } = string.Empty;

    [Column("tabla_afectada")]
    [StringLength(50)]
    public string? TablaAfectada { get; set; }

    [Column("registro_id")]
    public int? RegistroId { get; set; }

    [Column("detalle")]
    public string? Detalle { get; set; }

    [Column("ip_address")]
    [StringLength(50)]
    public string? IpAddress { get; set; }

    [Column("fecha_accion")]
    public DateTime FechaAccion { get; set; } = DateTime.UtcNow;
}
