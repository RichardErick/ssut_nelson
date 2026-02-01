using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SistemaGestionDocumental.Models;

[Table("usuarios")]
public class Usuario
{
    [Key]
    [Column("id")]
    public int Id { get; set; }

    [Column("uuid")]
    public Guid Uuid { get; set; } = Guid.NewGuid();

    [Required]
    [Column("nombre_usuario")]
    [StringLength(50)]
    public string NombreUsuario { get; set; } = string.Empty;

    [Required]
    [Column("nombre_completo")]
    [StringLength(100)]
    public string NombreCompleto { get; set; } = string.Empty;

    [Required]
    [Column("email")]
    [StringLength(255)]
    [EmailAddress]
    public string Email { get; set; } = string.Empty;

    [Required]
    [Column("password_hash")]
    [StringLength(255)]
    public string PasswordHash { get; set; } = string.Empty;

    [Column("rol")]
    public UsuarioRol Rol { get; set; } = UsuarioRol.Contador;

    [Column("area_id")]
    public int? AreaId { get; set; }

    [ForeignKey("AreaId")]
    public virtual Area? Area { get; set; }

    [Column("activo")]
    public bool Activo { get; set; } = true;

    /// <summary>
    /// True si un administrador rechazó la solicitud de registro; no se muestra en "pendientes".
    /// </summary>
    [Column("solicitud_rechazada")]
    public bool SolicitudRechazada { get; set; } = false;

    [Column("ultimo_acceso")]
    public DateTime? UltimoAcceso { get; set; }

    [Column("intentos_fallidos")]
    public int IntentosFallidos { get; set; } = 0;

    [Column("bloqueado_hasta")]
    public DateTime? BloqueadoHasta { get; set; }

    [Column("fecha_registro")]
    public DateTime FechaRegistro { get; set; } = DateTime.UtcNow;

    [Column("fecha_actualizacion")]
    public DateTime FechaActualizacion { get; set; } = DateTime.UtcNow;

    // Relaciones
    public virtual ICollection<Documento> DocumentosResponsable { get; set; } = new List<Documento>();
    public virtual ICollection<Movimiento> Movimientos { get; set; } = new List<Movimiento>();
    public virtual ICollection<Alerta> Alertas { get; set; } = new List<Alerta>();
}

public enum UsuarioRol
{
    Administrador,           // Administrador de Sistema
    AdministradorDocumentos,  // Administrador de Documentos
    Contador,                 // Contador
    Gerente,                  // Gerente
}

