import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/user_role.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/sidebar.dart';
import 'admin/permisos_screen.dart';
import 'admin/roles_permissions_screen.dart';
import 'admin/users_sync_screen.dart';
import 'documentos/documentos_list_screen.dart';
import 'documentos/carpetas_screen.dart';
import 'documentos/carpeta_form_screen.dart';
import 'documentos/documento_form_screen.dart';
import 'movimientos/movimientos_screen.dart';
import 'notifications_screen.dart';
import 'qr/qr_scanner_screen.dart';
import 'reportes/reportes_screen.dart';
import 'profile_screen.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isSidebarCollapsed = false;
  late AnimationController _fabController;
  late Animation<double> _fabAnimation;

  // GlobalKey para poder refrescar DocumentosListScreen
  final GlobalKey<DocumentosListScreenState> _documentosKey = GlobalKey<DocumentosListScreenState>();

  List<NavigationItem> _navItems = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _buildNavItems();
  }

  void _buildNavItems() {
    final role = Provider.of<AuthProvider>(context).role;

    _navItems = [
      NavigationItem(
        label: 'Carpetas',
        icon: Icons.folder_outlined,
        selectedIcon: Icons.folder,
        screen: DocumentosListScreen(key: _documentosKey),
      ),
      NavigationItem(
        label: 'Movimientos',
        icon: Icons.swap_horiz_outlined,
        selectedIcon: Icons.swap_horiz,
        screen: const MovimientosScreen(),
      ),
    ];

    if (role == UserRole.administradorSistema ||
        role == UserRole.administradorDocumentos) {
      _navItems.add(
        NavigationItem(
          label: 'Reportes',
          icon: Icons.assessment_outlined,
          selectedIcon: Icons.assessment,
          screen: const ReportesScreen(),
        ),
      );
    }

    if (role == UserRole.administradorSistema) {
      _navItems.add(
        NavigationItem(
          label: 'Roles y Permisos',
          icon: Icons.admin_panel_settings_outlined,
          selectedIcon: Icons.admin_panel_settings,
          screen: const RolesPermissionsScreen(),
        ),
      );
      _navItems.add(
        NavigationItem(
          label: 'Gestión de Permisos',
          icon: Icons.security_outlined,
          selectedIcon: Icons.security,
          screen: const PermisosScreen(),
        ),
      );
      _navItems.add(
        NavigationItem(
          label: 'Sincronización',
          icon:
              Icons.sync_problem_outlined, // Using similar icon as placeholder
          selectedIcon: Icons.sync,
          screen: const UsersSyncScreen(),
        ),
      );
    }

    _navItems.add(
      NavigationItem(
        label: 'Escáner QR',
        icon: Icons.qr_code_scanner_outlined,
        selectedIcon: Icons.qr_code_scanner,
        screen: const QRScannerScreen(),
      ),
    );
  }

  int _unreadNotifications = 0;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabController,
      curve: Curves.elasticOut,
    );
    _fabController.forward();
    _fetchUnreadCount();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _fabController.dispose();
    super.dispose();
  }

  Future<void> _fetchUnreadCount() async {
    if (_isDisposed) return;
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get('/alertas/unread-count');
      if (mounted) {
        setState(() {
          _unreadNotifications = response.data['count'] ?? 0;
        });
      }
    } catch (_) {}
    
    // Poll every 30 seconds
    Future.delayed(const Duration(seconds: 30), _fetchUnreadCount);
  }

  void _onItemSelected(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 0) {
        _fabController.forward();
      } else {
        _fabController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 1100;
    final isTablet = size.width >= 700 && size.width < 1100;

    return Scaffold(
      body: Row(
        children: [
          if (isDesktop || isTablet)
            SideBar(
              selectedIndex: _selectedIndex,
              onItemSelected: _onItemSelected,
              isCollapsed: isTablet || _isSidebarCollapsed,
              navItems: _navItems,
            ),
          Expanded(
            child: Scaffold(
              extendBodyBehindAppBar: true,
              appBar: _buildAppBar(theme, isDesktop),
              body: _buildBody(theme),
              floatingActionButton:
                  _selectedIndex == 0 ? _buildFAB(theme) : null,
              bottomNavigationBar:
                  !isDesktop && !isTablet ? _buildBottomNav(theme) : null,
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme, bool isDesktop) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(80),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        child: GlassContainer(
          blur: 10,
          opacity: theme.brightness == Brightness.dark ? 0.05 : 0.7,
          borderRadius: 20,
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leadingWidth: isDesktop ? 0 : 56,
            leading:
                isDesktop
                    ? null
                    : IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () {
                        setState(
                          () => _isSidebarCollapsed = !_isSidebarCollapsed,
                        );
                      },
                    ),
            title:
                isDesktop
                    ? _buildBreadcrumbs(theme)
                    : Text(
                      _navItems[_selectedIndex].label,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
            actions: [
              _buildActionIcon(Icons.search, 'Búsqueda Global', theme),
              const SizedBox(width: 12),
              _buildNotificationBadge(theme),
              const SizedBox(width: 12),
              _buildThemeToggle(theme),
              const SizedBox(width: 12),
              _buildUserAvatar(theme),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationBadge(ThemeData theme) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _buildActionIcon(
          _unreadNotifications > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
          'Notificaciones',
          theme,
        ),
        if (_unreadNotifications > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.surface, width: 2),
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Text(
                '$_unreadNotifications',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBreadcrumbs(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'SSUT / ${_navItems[_selectedIndex].label.toUpperCase()}',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.primary,
            letterSpacing: 1.1,
          ),
        ),
        Text(
          _navItems[_selectedIndex].label,
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  // _getTitle() removed as it is replaced by _navItems logic

  Widget _buildActionIcon(IconData icon, String tooltip, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: theme.colorScheme.onSurface.withOpacity(0.7),
          size: 22,
        ),
        onPressed: () {
          if (tooltip == 'Notificaciones') {
             Navigator.of(context).push(
               MaterialPageRoute(builder: (context) => const NotificationsScreen())
             );
          }
        },
        tooltip: tooltip,
      ),
    );
  }

  Widget _buildThemeToggle(ThemeData theme) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: IconButton(
        icon: Icon(
          themeProvider.esModoOscuro
              ? Icons.light_mode_rounded
              : Icons.dark_mode_rounded,
          color: Colors.amber,
          size: 22,
        ),
        onPressed: () => themeProvider.cambiarTema(),
        tooltip: 'Cambiar Tema',
      ),
    );
  }

  Widget _buildUserAvatar(ThemeData theme) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.colorPrimario,
              child: Icon(Icons.person, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
      onSelected: (value) {
        if (value == 'logout') {
          Provider.of<AuthProvider>(context, listen: false).logout();
          Navigator.of(context).pushReplacementNamed('/login');
        } else if (value == 'profile') {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const ProfileScreen()),
          );
        }
      },
      itemBuilder:
          (context) => [
            PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person_outline, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  const Text('Mi Perfil'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: const [
                  Icon(Icons.logout, color: Colors.red),
                  SizedBox(width: 12),
                  Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
    );
  }

  Widget _buildBody(ThemeData theme) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.only(top: 100),
      color: theme.colorScheme.background,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        switchInCurve: Curves.easeInOutCubic,
        switchOutCurve: Curves.easeInOutCubic,
        transitionBuilder: (child, animation) {
          final slideAnimation = Tween<Offset>(
            begin: const Offset(0.01, 0),
            end: Offset.zero,
          ).animate(animation);

          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: slideAnimation,
              child: child,
            ),
          );
        },
        child: _navItems[_selectedIndex].screen,
      ),
    );
  }

  Widget _buildFAB(ThemeData theme) {
    final authProvider = Provider.of<AuthProvider>(context);
    final canCreate = authProvider.hasPermission('subir_documento');

    return ScaleTransition(
      scale: _fabAnimation,
      child: FloatingActionButton.extended(
        heroTag: 'home_fab',
        onPressed: canCreate
            ? () async {
              // Navegar a la pantalla de gestión de carpetas (Crear NUEVA)
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CarpetaFormScreen(),
                ),
              );
              // Refrescar lista de documentos al volver
              _documentosKey.currentState?.cargarDocumentos();
            }
            : () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'No tienes el rol suficiente para gestionar carpetas.',
                  ),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 2),
                ),
              );
            },
        backgroundColor:
            canCreate ? Colors.amber.shade800 : Colors.grey.withOpacity(0.5),
        icon: const Icon(Icons.create_new_folder_rounded, color: Colors.white),
        label: Text(
          'AGREGAR CARPETA',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(ThemeData theme) {
    return NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _onItemSelected,
      backgroundColor: theme.colorScheme.surface,
      elevation: 10,
      indicatorColor: theme.colorScheme.primary.withOpacity(0.1),
      destinations: _navItems.map((item) {
        return NavigationDestination(
          icon: Icon(item.icon),
          selectedIcon: Icon(item.selectedIcon),
          label: item.label,
        );
      }).toList(),
    );
  }
}
