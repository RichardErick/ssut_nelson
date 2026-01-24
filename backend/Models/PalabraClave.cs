using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SistemaGestionDocumental.Models;

[Table("palabras_clave")]
public class PalabraClave
{
    [Key]
    [Column("id")]
    public int Id { get; set; }

    [Required]
    [Column("palabra")]
    [StringLength(50)]
    public string Palabra { get; set; } = string.Empty;

    [Column("descripcion")]
    [StringLength(200)]
    public string? Descripcion { get; set; }

    [Column("activo")]
    public bool Activo { get; set; } = true;

    // Relaciones
    public virtual ICollection<DocumentoPalabraClave> DocumentoPalabrasClaves { get; set; } = new List<DocumentoPalabraClave>();
}
