import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BreadcrumbHeader extends StatelessWidget {
  final String? parentName;
  final String currentName;
  final VoidCallback onParentTap;
  final VoidCallback onRootTap;

  const BreadcrumbHeader({
    super.key,
    this.parentName,
    required this.currentName,
    required this.onParentTap,
    required this.onRootTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BreadcrumbItem(
            label: 'Carpetas',
            onTap: onRootTap,
            isLast: false,
          ),
          if (parentName != null && parentName!.isNotEmpty) ...[
            _BreadcrumbItem(
              label: parentName!,
              onTap: onParentTap,
              isLast: false,
            ),
          ],
          _BreadcrumbItem(
            label: currentName,
            onTap: null,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _BreadcrumbItem extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isLast;

  const _BreadcrumbItem({
    required this.label,
    required this.onTap,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isLast ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;
    
    return Row(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: color,
                fontWeight: isLast ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ),
        if (!isLast)
          Icon(
            Icons.chevron_right_rounded,
            size: 16,
            color: theme.colorScheme.outline.withOpacity(0.5),
          ),
      ],
    );
  }
}
