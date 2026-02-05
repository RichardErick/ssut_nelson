using System.Net;
using System.Net.Mail;

namespace SistemaGestionDocumental.Services;

/// <summary>
/// Envía correos por SMTP. Configurar en appsettings.json bajo "Email".
/// Si SmtpHost está vacío, SendPasswordResetAsync no envía y devuelve false.
/// </summary>
public class EmailSender : IEmailSender
{
    private readonly IConfiguration _config;

    public EmailSender(IConfiguration config)
    {
        _config = config;
    }

    public async Task<bool> SendPasswordResetAsync(string toEmail, string userName, string resetLink)
    {
        var host = _config["Email:SmtpHost"];
        if (string.IsNullOrWhiteSpace(host))
            return false;

        var port = _config.GetValue<int>("Email:SmtpPort", 587);
        var user = _config["Email:SmtpUser"];
        var password = _config["Email:SmtpPassword"];
        var fromAddress = _config["Email:FromAddress"] ?? user;
        var fromName = _config["Email:FromName"] ?? "SSUT Gestión Documental";

        using var client = new SmtpClient(host, port)
        {
            EnableSsl = port == 587 || port == 465,
            Credentials = !string.IsNullOrEmpty(user) ? new NetworkCredential(user, password) : null
        };

        var mail = new MailMessage
        {
            From = new MailAddress(fromAddress ?? "noreply@ssut.local", fromName),
            Subject = "Restablecer contraseña - SSUT Gestión Documental",
            Body = $@"
Hola {userName},

Has solicitado restablecer tu contraseña. Haz clic en el siguiente enlace (válido por 1 hora):

{resetLink}

Si no solicitaste este cambio, ignora este correo.

— Sistema de Gestión Documental SSUT
".Trim(),
            IsBodyHtml = false
        };
        mail.To.Add(toEmail);

        try
        {
            await client.SendMailAsync(mail);
            return true;
        }
        catch
        {
            return false;
        }
    }

    public async Task<bool> SendPasswordResetCodeAsync(string toEmail, string userName, string code)
    {
        var host = _config["Email:SmtpHost"];
        if (string.IsNullOrWhiteSpace(host))
            return false;

        var port = _config.GetValue<int>("Email:SmtpPort", 587);
        var user = _config["Email:SmtpUser"];
        var password = _config["Email:SmtpPassword"];
        var fromAddress = _config["Email:FromAddress"] ?? user;
        var fromName = _config["Email:FromName"] ?? "SSUT Gestión Documental";

        using var client = new SmtpClient(host, port)
        {
            EnableSsl = port == 587 || port == 465,
            Credentials = !string.IsNullOrEmpty(user) ? new NetworkCredential(user, password) : null
        };

        var mail = new MailMessage
        {
            From = new MailAddress(fromAddress ?? "noreply@ssut.local", fromName),
            Subject = "Código para restablecer contraseña - SSUT Gestión Documental",
            Body = $@"
Hola {userName},

Tu código para restablecer la contraseña es:

  {code}

Válido por 1 hora. No lo compartas con nadie.

Si no solicitaste este cambio, ignora este correo.

— Sistema de Gestión Documental SSUT
".Trim(),
            IsBodyHtml = false
        };
        mail.To.Add(toEmail);

        try
        {
            await client.SendMailAsync(mail);
            return true;
        }
        catch
        {
            return false;
        }
    }
}
