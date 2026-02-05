namespace SistemaGestionDocumental.Services;

/// <summary>
/// Servicio opcional para enviar correos (recuperación de contraseña, etc.).
/// Si no está configurado SMTP en appsettings, no se envía el correo.
/// </summary>
public interface IEmailSender
{
    Task<bool> SendPasswordResetAsync(string toEmail, string userName, string resetLink);
    /// <summary>Envía un código de 6 dígitos para restablecer contraseña (método alternativo al enlace).</summary>
    Task<bool> SendPasswordResetCodeAsync(string toEmail, string userName, string code);
}
