import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final bool isDark;
  final String? Function(String?)? validator;
  final bool obscurePassword;
  final VoidCallback? onTogglePasswordVisibility;

  const LoginTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.isPassword = false,
    this.isDark = false,
    this.validator,
    this.obscurePassword = true,
    this.onTogglePasswordVisibility,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.black87 : Colors.white;
    final hintColor = isDark ? Colors.grey.withOpacity(0.6) : Colors.white.withOpacity(0.4);
    final borderColor = isDark ? Colors.grey.shade300 : Colors.white.withOpacity(0.1);
    final fillColor = isDark ? Colors.grey.shade50 : Colors.white.withOpacity(0.1);
    final iconColor = isDark ? Colors.grey.shade600 : Colors.white.withOpacity(0.7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: isDark ? Colors.grey.shade800 : Colors.white.withOpacity(0.9),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: isPassword && obscurePassword,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: hintColor),
            prefixIcon: Icon(icon, color: iconColor),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: iconColor,
                    ),
                    onPressed: onTogglePasswordVisibility,
                  )
                : null,
            filled: true,
            fillColor: fillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.blue.shade700 : Colors.white,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade600, width: 2),
            ),
            errorStyle: TextStyle(color: Colors.red.shade700, fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
