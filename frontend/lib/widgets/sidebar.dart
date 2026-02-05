import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'glass_container.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user_role.dart';

/// Modelo para definir elementos de navegación en la barra lateral.
class NavigationItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget screen;

  NavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.screen,
  });
}
/// Widget de barra lateral personalizada con soporte para modo colapsado y temas.
class SideBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final List<NavigationItem> navItems;
  final bool isCollapsed;
  /// Al tocar la sección de usuario (abajo) se abre Mi perfil.
  final VoidCallback? onUserTap;

  const SideBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.navItems,
    this.isCollapsed = false,
    this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final esOscuro = theme.brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isCollapsed ? 80 : 260,
      margin: EdgeInsets.all(isCollapsed ? 8 : 16),
      child: GlassContainer(
        blur: 15,
        opacity: esOscuro ? 0.05 : 0.6,
        color: esOscuro ? Colors.black : Colors.white,
        borderRadius: 24,
        child: Column(
          children: [
            const SizedBox(height: 24),
            _buildLogo(context),
            const SizedBox(height: 40),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 4 : 12),
                children: List.generate(navItems.length, (index) {
                  final item = navItems[index];
                  return _SideBarItem(
                    icon: item.icon,
                    selectedIcon: item.selectedIcon,
                    label: item.label,
                    isSelected: selectedIndex == index,
                    onTap: () => onItemSelected(index),
                    isCollapsed: isCollapsed,
                  );
                }),
              ),
            ),
            _buildUserSection(context, onUserTap: onUserTap),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.colorPrimario, AppTheme.colorSecundario],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.description_rounded, color: Colors.white, size: 24),
        ),
        if (!isCollapsed) ...[
          const SizedBox(width: 12),
          Text(
            'SSUT',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ]
      ],
    );
  }

  Widget _buildUserSection(BuildContext context, {VoidCallback? onUserTap}) {
    if (isCollapsed) {
      return GestureDetector(
        onTap: onUserTap,
        child: const CircleAvatar(
          radius: 20,
          backgroundColor: AppTheme.colorPrimario,
          child: Icon(Icons.person, color: Colors.white),
        ),
      );
    }
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    final content = Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.colorPrimario,
            child: Text(
              user?['nombreUsuario']?[0]?.toUpperCase() ?? 'U',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  authProvider.role.displayName,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  user?['nombreUsuario'] ?? 'Usuario',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onUserTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onUserTap,
          borderRadius: BorderRadius.circular(16),
          child: content,
        ),
      );
    }
    return content;
  }
}

class _SideBarItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isCollapsed;

  const _SideBarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isCollapsed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.6);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: isCollapsed ? 0 : 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Icon(isSelected ? selectedIcon : icon, color: color),
            if (!isCollapsed) ...[
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    color: color,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
