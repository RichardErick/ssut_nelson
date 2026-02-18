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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BreadcrumbItem(
              label: 'Carpetas',
              icon: Icons.home_rounded,
              onTap: onRootTap,
              isFirst: true,
              isLast: false,
            ),
            if (parentName != null && parentName!.isNotEmpty) ...[
              _BreadcrumbItem(
                label: parentName!,
                onTap: onParentTap,
                isFirst: false,
                isLast: false,
              ),
            ],
            _BreadcrumbItem(
              label: currentName,
              onTap: null,
              isFirst: false,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _BreadcrumbItem extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool isFirst;
  final bool isLast;

  const _BreadcrumbItem({
    required this.label,
    this.icon,
    required this.onTap,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isLast ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;
    final bgColor = isLast ? theme.colorScheme.primary.withOpacity(0.08) : Colors.transparent;

    return Row(
      children: [
        if (!isFirst)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
            ),
          ),
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 300),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.95 + (0.05 * value),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isLast ? theme.colorScheme.primary.withOpacity(0.2) : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      color: color,
                      fontWeight: isLast ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
