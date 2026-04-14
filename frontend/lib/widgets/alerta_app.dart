import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tipo de alerta (estilo SweetAlert).
enum AppAlertType { success, error, warning, info }

/// Diálogo de alerta profesional (estilo SweetAlert).
class AppAlert {
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    AppAlertType type = AppAlertType.info,
    String buttonText = 'Aceptar',
    VoidCallback? onPressed,
  }) {
    final theme = Theme.of(context);
    Color iconColor;
    IconData icon;
    Color cardColor;
    switch (type) {
      case AppAlertType.success:
        iconColor = const Color(0xFF22C55E);
        icon = Icons.check_circle_rounded;
        cardColor = const Color(0xFF22C55E).withOpacity(0.08);
        break;
      case AppAlertType.error:
        iconColor = const Color(0xFFEF4444);
        icon = Icons.error_rounded;
        cardColor = const Color(0xFFEF4444).withOpacity(0.08);
        break;
      case AppAlertType.warning:
        iconColor = const Color(0xFFF59E0B);
        icon = Icons.warning_rounded;
        cardColor = const Color(0xFFF59E0B).withOpacity(0.08);
        break;
      case AppAlertType.info:
        iconColor = theme.colorScheme.primary;
        icon = Icons.info_rounded;
        cardColor = theme.colorScheme.primary.withOpacity(0.08);
        break;
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 56, color: iconColor),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.45,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onPressed?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: iconColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    buttonText,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> success(BuildContext context, String title, String message, {String buttonText = 'Aceptar'}) {
    return show(context, title: title, message: message, type: AppAlertType.success, buttonText: buttonText);
  }

  static Future<void> error(BuildContext context, String title, String message, {String buttonText = 'Entendido'}) {
    return show(context, title: title, message: message, type: AppAlertType.error, buttonText: buttonText);
  }

  static Future<void> warning(BuildContext context, String title, String message, {String buttonText = 'Aceptar'}) {
    return show(context, title: title, message: message, type: AppAlertType.warning, buttonText: buttonText);
  }
}
