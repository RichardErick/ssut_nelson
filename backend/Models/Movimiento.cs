using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SistemaGestionDocumental.Models;

[Table("movimientos")]
public class Movimiento
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
    [Column("tipo_movimiento")]
    [StringLength(20)]
    public string TipoMovimiento { get; set; } = string.Empty; // Entrada, Salida, Derivacion

    [Column("area_origen_id")]
    public int? AreaOrigenId { get; set; }

    [ForeignKey("AreaOrigenId")]
    public virtual Area? AreaOrigen { get; set; }

    [Column("area_destino_id")]
    public int? AreaDestinoId { get; set; }

    [ForeignKey("AreaDestinoId")]
    public virtual Area? AreaDestino { get; set; }

    [Column("usuario_id")]
    public int? UsuarioId { get; set; }

    [ForeignKey("UsuarioId")]
    public virtual Usuario? Usuario { get; set; }

    [Column("observaciones")]
    [StringLength(500)]
    public string? Observaciones { get; set; }

    [Column("fecha_movimiento")]
    public DateTime FechaMovimiento { get; set; } = DateTime.UtcNow;

    [Column("fecha_devolucion")]
    public DateTime? FechaDevolucion { get; set; }

    [Column("estado")]
    [StringLength(20)]
    public string Estado { get; set; } = "Activo"; // Activo, Devuelto, Cancelado
}

