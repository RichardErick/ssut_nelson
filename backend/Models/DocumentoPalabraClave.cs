using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SistemaGestionDocumental.Models;

[Table("documento_palabras_clave")]
public class DocumentoPalabraClave
{
    [Column("documento_id")]
    public int DocumentoId { get; set; }

    [ForeignKey("DocumentoId")]
    public virtual Documento Documento { get; set; } = null!;

    [Column("palabra_clave_id")]
    public int PalabraClaveId { get; set; }

    [ForeignKey("PalabraClaveId")]
    public virtual PalabraClave PalabraClave { get; set; } = null!;
}
