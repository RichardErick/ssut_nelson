using Microsoft.EntityFrameworkCore;
using SistemaGestionDocumental.Models;

namespace SistemaGestionDocumental.Data;

public class ApplicationDbContext : DbContext
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
        : base(options)
    {
    }

    public DbSet<Documento> Documentos { get; set; }
    public DbSet<Movimiento> Movimientos { get; set; }
    public DbSet<Usuario> Usuarios { get; set; }
    public DbSet<Area> Areas { get; set; }
    public DbSet<TipoDocumento> TiposDocumento { get; set; }
    public DbSet<Anexo> Anexos { get; set; }
    public DbSet<HistorialDocumento> HistorialesDocumento { get; set; }
    public DbSet<Auditoria> Auditoria { get; set; }
    public DbSet<Alerta> Alertas { get; set; }
    public DbSet<Configuracion> Configuraciones { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Configuración de Documento
        modelBuilder.Entity<Documento>(entity =>
        {
            entity.HasIndex(d => d.Codigo).IsUnique();
            entity.HasIndex(d => new { d.Gestion, d.NumeroCorrelativo });
            entity.HasIndex(d => d.AreaActualId);
            entity.HasIndex(d => d.Estado);
            entity.HasIndex(d => d.FechaDocumento);
            entity.HasIndex(d => d.ResponsableId);
            
            // Relaciones
            entity.HasOne(d => d.TipoDocumento)
                .WithMany(t => t.Documentos)
                .HasForeignKey(d => d.TipoDocumentoId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(d => d.AreaOrigen)
                .WithMany(a => a.DocumentosOrigen)
                .HasForeignKey(d => d.AreaOrigenId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(d => d.AreaActual)
                .WithMany()
                .HasForeignKey(d => d.AreaActualId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(d => d.Responsable)
                .WithMany(u => u.DocumentosResponsable)
                .HasForeignKey(d => d.ResponsableId)
                .OnDelete(DeleteBehavior.SetNull);

            entity.HasMany(d => d.Movimientos)
                .WithOne(m => m.Documento)
                .HasForeignKey(m => m.DocumentoId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasMany(d => d.Anexos)
                .WithOne(a => a.Documento)
                .HasForeignKey(a => a.DocumentoId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasMany(d => d.HistorialDocumentos)
                .WithOne(h => h.Documento)
                .HasForeignKey(h => h.DocumentoId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasMany(d => d.Alertas)
                .WithOne(a => a.Documento)
                .HasForeignKey(a => a.DocumentoId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // Configuración de Movimiento
        modelBuilder.Entity<Movimiento>(entity =>
        {
            entity.HasIndex(m => m.DocumentoId);
            entity.HasIndex(m => m.FechaMovimiento);
            
            // Relaciones
            entity.HasOne(m => m.AreaOrigen)
                .WithMany(a => a.MovimientosOrigen)
                .HasForeignKey(m => m.AreaOrigenId)
                .OnDelete(DeleteBehavior.SetNull);

            entity.HasOne(m => m.AreaDestino)
                .WithMany(a => a.MovimientosDestino)
                .HasForeignKey(m => m.AreaDestinoId)
                .OnDelete(DeleteBehavior.SetNull);

            entity.HasOne(m => m.Usuario)
                .WithMany(u => u.Movimientos)
                .HasForeignKey(m => m.UsuarioId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        // Configuración de Usuario
        modelBuilder.Entity<Usuario>(entity =>
        {
            entity.HasIndex(u => u.NombreUsuario).IsUnique();
            entity.HasIndex(u => u.Email).IsUnique();
            entity.HasIndex(u => u.Rol);
            entity.HasIndex(u => u.Activo);
            
            // Convertir el enum a string para evitar problemas de orden entre PostgreSQL y C#
            // Esto evita problemas cuando el orden del enum en PostgreSQL no coincide con C#
            entity.Property(u => u.Rol)
                .HasConversion(
                    v => v.ToString(),  // Convertir enum a string al escribir
                    v => (UsuarioRol)Enum.Parse(typeof(UsuarioRol), v, true)  // Convertir string a enum al leer
                )
                .HasColumnType("text");  // Usar text para almacenar como string
            
            entity.HasOne(u => u.Area)
                .WithMany(a => a.Usuarios)
                .HasForeignKey(u => u.AreaId)
                .OnDelete(DeleteBehavior.SetNull);

            entity.HasMany(u => u.Alertas)
                .WithOne(a => a.Usuario)
                .HasForeignKey(a => a.UsuarioId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // Configuración de Area
        modelBuilder.Entity<Area>(entity =>
        {
            // No se requieren configuraciones adicionales
        });

        // Configuración de TipoDocumento
        modelBuilder.Entity<TipoDocumento>(entity =>
        {
            // No se requieren configuraciones adicionales
        });

        // Configuración de Anexo
        modelBuilder.Entity<Anexo>(entity =>
        {
            entity.HasIndex(a => a.DocumentoId);
            
            entity.HasOne(a => a.Documento)
                .WithMany()
                .HasForeignKey(a => a.DocumentoId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // Configuración de HistorialDocumento
        modelBuilder.Entity<HistorialDocumento>(entity =>
        {
            entity.HasIndex(h => h.DocumentoId);
            
            entity.HasOne(h => h.Documento)
                .WithMany()
                .HasForeignKey(h => h.DocumentoId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(h => h.Usuario)
                .WithMany()
                .HasForeignKey(h => h.UsuarioId)
                .OnDelete(DeleteBehavior.SetNull);

            entity.HasOne(h => h.AreaAnterior)
                .WithMany()
                .HasForeignKey(h => h.AreaAnteriorId)
                .OnDelete(DeleteBehavior.NoAction);

            entity.HasOne(h => h.AreaNueva)
                .WithMany()
                .HasForeignKey(h => h.AreaNuevaId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        // Configuración de Auditoria
        modelBuilder.Entity<Auditoria>(entity =>
        {
            entity.HasIndex(a => a.UsuarioId);
            entity.HasIndex(a => a.FechaAccion);
            entity.HasIndex(a => a.TablaAfectada);
            
            entity.HasOne(a => a.Usuario)
                .WithMany()
                .HasForeignKey(a => a.UsuarioId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        // Configuración de Alerta
        modelBuilder.Entity<Alerta>(entity =>
        {
            entity.HasIndex(a => a.UsuarioId);
            entity.HasIndex(a => a.Leida);
            entity.HasIndex(a => a.FechaCreacion);
            
            entity.HasOne(a => a.Usuario)
                .WithMany(u => u.Alertas)
                .HasForeignKey(a => a.UsuarioId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(a => a.Documento)
                .WithMany(d => d.Alertas)
                .HasForeignKey(a => a.DocumentoId)
                .OnDelete(DeleteBehavior.SetNull);

            entity.HasOne(a => a.Movimiento)
                .WithMany()
                .HasForeignKey(a => a.MovimientoId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        // Configuración de Configuracion
        modelBuilder.Entity<Configuracion>(entity =>
        {
            entity.HasIndex(c => c.Clave).IsUnique();
            
            entity.HasOne(c => c.ActualizadoPorUsuario)
                .WithMany()
                .HasForeignKey(c => c.ActualizadoPor)
                .OnDelete(DeleteBehavior.SetNull);
        });
    }
}

