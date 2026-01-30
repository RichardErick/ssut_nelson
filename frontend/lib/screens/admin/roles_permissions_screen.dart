import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../models/area.dart';
import '../../models/usuario.dart';
import '../../services/api_service.dart';
import '../../services/usuario_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/loading_shimmer.dart';

class RolesPermissionsScreen extends StatefulWidget {
  const RolesPermissionsScreen({super.key});

  @override
  State<RolesPermissionsScreen> createState() => _RolesPermissionsScreenState();
}

class _RolesPermissionsScreenState extends State<RolesPermissionsScreen> {
  List<Usuario> _usuarios = [];
  List<Area> _areas = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String _searchQuery = '';
  String? _selectedRolFilter;
  String? _selectedAreaFilter;
  bool? _selectedEstadoFilter = true;
  bool _isGridView = false;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Roles disponibles
  final List<String> _roles = [
    'AdministradorSistema',
    'Administrador',
    'AdministradorDocumentos',
    'ArchivoCentral',
    'TramiteDocumentario',
    'Usuario',
    'Supervisor',
  ];

  @override
  void initState() {
    super.initState();
    // Validar permiso al entrar (defensa en profundidad)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (!authProvider.canManageUserPermissions) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Acceso denegado: Solo Admin Sistema puede gestionar roles')),
        );
      }
    });

    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _createUsuario(CreateUsuarioDTO dto) async {
    try {
      final usuarioService = Provider.of<UsuarioService>(
        context,
        listen: false,
      );
      await usuarioService.create(dto);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuario creado correctamente'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _selectedEstadoFilter = true);
        _loadData(showRefreshIndicator: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear usuario: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteUsuario(Usuario usuario) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Eliminar usuario'),
          content: Text(
            'Se desactivará el usuario "${usuario.nombreCompleto}" (eliminación lógica). ¿Continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final usuarioService = Provider.of<UsuarioService>(
        context,
        listen: false,
      );
      await usuarioService.deleteUsuario(usuario.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuario desactivado'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadData(showRefreshIndicator: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar usuario: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showCreateUserDialog() {
    final nombreUsuarioController = TextEditingController();
    final nombreCompletoController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    String rol = 'Usuario';
    int? areaId;
    bool activo = true;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Nuevo usuario'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nombreUsuarioController,
                        decoration: const InputDecoration(
                          labelText: 'Usuario',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nombreCompletoController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre completo',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: rol,
                        decoration: const InputDecoration(
                          labelText: 'Rol',
                          prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                        ),
                        items:
                            _roles
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(_getRolDisplayName(r)),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setStateDialog(() => rol = v);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int?>(
                        value: areaId,
                        decoration: const InputDecoration(
                          labelText: 'Área (opcional)',
                          prefixIcon: Icon(Icons.business_outlined),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Sin área'),
                          ),
                          ..._areas.map(
                            (a) => DropdownMenuItem<int?>(
                              value: a.id,
                              child: Text(a.nombre),
                            ),
                          ).toList(),
                        ],
                        onChanged: (v) => setStateDialog(() => areaId = v),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        value: activo,
                        onChanged: (v) => setStateDialog(() => activo = v),
                        title: const Text('Activo'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final dto = CreateUsuarioDTO(
                      nombreUsuario: nombreUsuarioController.text,
                      nombreCompleto: nombreCompletoController.text,
                      email: emailController.text,
                      password: passwordController.text,
                      rol: rol,
                      areaId: areaId,
                      activo: activo,
                    );
                    Navigator.pop(dialogContext);
                    _createUsuario(dto);
                  },
                  child: const Text('Crear'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      nombreUsuarioController.dispose();
      nombreCompletoController.dispose();
      emailController.dispose();
      passwordController.dispose();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  Future<void> _loadData({bool showRefreshIndicator = false}) async {
    if (showRefreshIndicator) {
      setState(() => _isRefreshing = true);
    } else {
      setState(() => _isLoading = true);
    }
    try {
      final usuarioService = Provider.of<UsuarioService>(
        context,
        listen: false,
      );
      final apiService = Provider.of<ApiService>(context, listen: false);

      final usuariosFuture = usuarioService.getAll();
      final areasResponse = await apiService.get('/areas');
      final usuarios = await usuariosFuture;

      if (mounted) {
        setState(() {
          _usuarios = usuarios;
          _areas =
              (areasResponse.data as List)
                  .map((json) => Area.fromJson(json))
                  .toList();
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Map<String, int> get _estadisticas {
    final stats = <String, int>{
      'total': _usuarios.length,
      'activos': _usuarios.where((u) => u.activo).length,
      'inactivos': _usuarios.where((u) => !u.activo).length,
    };

    for (final rol in _roles) {
      stats['rol_$rol'] = _usuarios.where((u) => u.rol == rol).length;
    }

    return stats;
  }

  List<Usuario> get _usuariosFiltrados {
    var filtered = _usuarios;

    if (_searchQuery.isNotEmpty) {
      filtered =
          filtered.where((usuario) {
            return usuario.nombreCompleto.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                usuario.nombreUsuario.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                usuario.email.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                );
          }).toList();
    }

    if (_selectedRolFilter != null) {
      filtered =
          filtered
              .where((usuario) => usuario.rol == _selectedRolFilter)
              .toList();
    }

    if (_selectedAreaFilter != null) {
      final areaId = int.tryParse(_selectedAreaFilter!);
      if (areaId != null) {
        filtered =
            filtered.where((usuario) => usuario.areaId == areaId).toList();
      }
    }

    if (_selectedEstadoFilter != null) {
      filtered =
          filtered
              .where((usuario) => usuario.activo == _selectedEstadoFilter)
              .toList();
    }

    return filtered;
  }

  Future<void> _updateRol(Usuario usuario, String nuevoRol) async {
    try {
      final usuarioService = Provider.of<UsuarioService>(
        context,
        listen: false,
      );
      await usuarioService.updateRol(usuario.id, nuevoRol);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Rol actualizado a ${_getRolDisplayName(nuevoRol)}'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadData(showRefreshIndicator: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar rol: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _toggleEstado(Usuario usuario) async {
    try {
      final usuarioService = Provider.of<UsuarioService>(
        context,
        listen: false,
      );
      await usuarioService.updateEstado(usuario.id, !usuario.activo);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Usuario ${usuario.activo ? 'desactivado' : 'activado'}'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadData(showRefreshIndicator: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar estado: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showRolDialog(Usuario usuario) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getRolColor(usuario.rol).withOpacity(0.2),
                  child: Icon(
                    _getRolIcon(usuario.rol),
                    color: _getRolColor(usuario.rol),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        usuario.nombreCompleto,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Cambiar rol',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  _roles.map((rol) {
                    final isSelected = usuario.rol == rol;
                    return InkWell(
                      onTap: () {
                        if (!isSelected) {
                          Navigator.pop(context);
                          _updateRol(usuario, rol);
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? _getRolColor(rol).withOpacity(0.1)
                                  : Colors.transparent,
                          border: Border.all(
                            color:
                                isSelected
                                    ? _getRolColor(rol)
                                    : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getRolIcon(rol),
                              color: _getRolColor(rol),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _getRolDisplayName(rol),
                                style: TextStyle(
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                  color: isSelected ? _getRolColor(rol) : null,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: _getRolColor(rol),
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          ),
    );
  }

  String _getRolDisplayName(String rol) {
    switch (rol) {
      case 'AdministradorSistema':
        return 'Administrador del Sistema';
      case 'Administrador':
        return 'Administrador';
      case 'AdministradorDocumentos':
        return 'Administrador de Documentos';
      case 'ArchivoCentral':
        return 'Archivo Central';
      case 'TramiteDocumentario':
        return 'Trámite Documentario';
      case 'Supervisor':
        return 'Supervisor';
      case 'Usuario':
        return 'Usuario';
      default:
        return rol;
    }
  }

  IconData _getRolIcon(String rol) {
    switch (rol) {
      case 'AdministradorSistema':
        return Icons.security;
      case 'Administrador':
        return Icons.admin_panel_settings;
      case 'AdministradorDocumentos':
        return Icons.folder_shared;
      case 'ArchivoCentral':
        return Icons.inventory_2;
      case 'TramiteDocumentario':
        return Icons.assignment;
      case 'Supervisor':
        return Icons.supervisor_account;
      case 'Usuario':
        return Icons.person;
      default:
        return Icons.person_outline;
    }
  }

  Color _getRolColor(String rol) {
    switch (rol) {
      case 'AdministradorSistema':
        return Colors.deepPurple;
      case 'Administrador':
        return Colors.red;
      case 'AdministradorDocumentos':
        return Colors.orange;
      case 'ArchivoCentral':
        return Colors.teal;
      case 'TramiteDocumentario':
        return Colors.indigo;
      case 'Supervisor':
        return Colors.blue;
      case 'Usuario':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _selectedRolFilter = null;
      _selectedAreaFilter = null;
      _selectedEstadoFilter = null;
      _searchController.clear();
    });
  }

  bool get _hasActiveFilters {
    return _searchQuery.isNotEmpty ||
        _selectedRolFilter != null ||
        _selectedAreaFilter != null ||
        _selectedEstadoFilter != null;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    // Solo el administrador de sistema puede gestionar roles
    if (!authProvider.canManageUserPermissions) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Gestión de Roles', style: GoogleFonts.poppins()),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'No tienes permisos para acceder a esta sección',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Text(
                'Rol actual: ${authProvider.role.displayName}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadData(showRefreshIndicator: true),
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isDesktop ? 32.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme, isDesktop),
            const SizedBox(height: 24),
            if (!_isLoading) _buildStatisticsCards(theme, isDesktop),
            if (!_isLoading) const SizedBox(height: 24),
            _buildFilters(theme, isDesktop),
            const SizedBox(height: 24),
            _buildUsersSection(theme, isDesktop),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDesktop) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gestión de Roles y Permisos',
                style: GoogleFonts.poppins(
                  fontSize: isDesktop ? 32 : 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Administre roles y permisos de usuarios del sistema',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: isDesktop ? 16 : 14,
                ),
              ),
            ],
          ),
        ),
        if (!_isLoading) ...[
          if (isDesktop)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilledButton.icon(
                onPressed: _showCreateUserDialog,
                icon: const Icon(Icons.person_add),
                label: const Text('Nuevo'),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: _showCreateUserDialog,
              tooltip: 'Nuevo usuario',
            ),
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _loadData(showRefreshIndicator: true),
              tooltip: 'Actualizar',
            ),
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () => setState(() => _isGridView = !_isGridView),
            tooltip: _isGridView ? 'Vista lista' : 'Vista cuadrícula',
          ),
        ],
      ],
    );
  }

  Widget _buildStatisticsCards(ThemeData theme, bool isDesktop) {
    final stats = _estadisticas;
    final cardWidth =
        isDesktop ? 200.0 : (MediaQuery.of(context).size.width - 64) / 2;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildStatCard(
          'Total Usuarios',
          stats['total']!.toString(),
          Icons.people,
          AppTheme.colorPrimario,
          cardWidth,
        ),
        _buildStatCard(
          'Activos',
          stats['activos']!.toString(),
          Icons.check_circle,
          Colors.green,
          cardWidth,
        ),
        _buildStatCard(
          'Inactivos',
          stats['inactivos']!.toString(),
          Icons.cancel,
          Colors.red,
          cardWidth,
        ),
        ..._roles.map(
          (rol) => _buildStatCard(
            _getRolDisplayName(rol),
            stats['rol_$rol']!.toString(),
            _getRolIcon(rol),
            _getRolColor(rol),
            cardWidth,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    double width,
  ) {
    return AnimatedCard(
      delay: Duration(milliseconds: _roles.indexOf(title) * 100),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(ThemeData theme, bool isDesktop) {
    return GlassContainer(
      blur: 10,
      opacity: theme.brightness == Brightness.dark ? 0.05 : 0.7,
      borderRadius: 16,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre, usuario o email...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon:
                          _searchQuery.isNotEmpty
                              ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => _searchController.clear(),
                              )
                              : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                    ),
                  ),
                ),
                if (_hasActiveFilters) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.filter_alt_off),
                    onPressed: _clearFilters,
                    tooltip: 'Limpiar filtros',
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.errorContainer,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: isDesktop ? 250 : double.infinity,
                  child: DropdownButtonFormField<String>(
                    value: _selectedRolFilter,
                    decoration: InputDecoration(
                      labelText: 'Filtrar por Rol',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Todos los roles'),
                      ),
                      ..._roles.map(
                        (rol) => DropdownMenuItem(
                          value: rol,
                          child: Row(
                            children: [
                              Icon(
                                _getRolIcon(rol),
                                size: 18,
                                color: _getRolColor(rol),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _getRolDisplayName(rol),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).toList(),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedRolFilter = value);
                    },
                  ),
                ),
                SizedBox(
                  width: isDesktop ? 250 : double.infinity,
                  child: DropdownButtonFormField<String>(
                    value: _selectedAreaFilter,
                    decoration: InputDecoration(
                      labelText: 'Filtrar por Área',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Todas las áreas'),
                      ),
                      ..._areas.map(
                        (area) => DropdownMenuItem(
                          value: area.id.toString(),
                          child: Text(
                            area.nombre,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedAreaFilter = value);
                    },
                  ),
                ),
                SizedBox(
                  width: isDesktop ? 200 : double.infinity,
                  child: DropdownButtonFormField<bool>(
                    value: _selectedEstadoFilter,
                    decoration: InputDecoration(
                      labelText: 'Estado',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Todos')),
                      DropdownMenuItem(value: true, child: Text('Activos')),
                      DropdownMenuItem(value: false, child: Text('Inactivos')),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedEstadoFilter = value);
                    },
                  ),
                ),
              ],
            ),
            if (_usuariosFiltrados.length != _usuarios.length) ...[
              const SizedBox(height: 12),
              Text(
                'Mostrando ${_usuariosFiltrados.length} de ${_usuarios.length} usuarios',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUsersSection(ThemeData theme, bool isDesktop) {
    if (_isLoading) {
      return Column(
        children: List.generate(
          5,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: LoadingShimmer(
              width: double.infinity,
              height: 120,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    if (_usuariosFiltrados.isEmpty) {
      return const EmptyState(
        icon: Icons.people_outline,
        title: 'No se encontraron usuarios',
        subtitle: 'Intenta ajustar los filtros de búsqueda',
      );
    }

    if (_isGridView) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isDesktop ? 3 : 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: isDesktop ? 1.0 : 0.85, 
        ),
        itemCount: _usuariosFiltrados.length,
        itemBuilder: (context, index) {
          return _buildUserCardGrid(_usuariosFiltrados[index], theme);
        },
      );
    }

    return Column(
      children:
          _usuariosFiltrados.asMap().entries.map((entry) {
            return AnimatedCard(
              delay: Duration(milliseconds: entry.key * 50),
              margin: const EdgeInsets.only(bottom: 12),
              child: _buildUserCard(entry.value, theme, isDesktop),
            );
          }).toList(),
    );
  }

  Widget _buildUserCard(Usuario usuario, ThemeData theme, bool isDesktop) {
    return ListTile(
      contentPadding: EdgeInsets.all(isDesktop ? 20 : 16),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: isDesktop ? 30 : 24,
            backgroundColor:
                usuario.activo ? theme.colorScheme.primary : Colors.grey,
            child: Text(
              usuario.nombreCompleto[0].toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isDesktop ? 20 : 16,
              ),
            ),
          ),
          if (!usuario.activo)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.block, color: Colors.white, size: 12),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              usuario.nombreCompleto,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _getRolColor(usuario.rol).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _getRolColor(usuario.rol), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getRolIcon(usuario.rol),
                  size: 14,
                  color: _getRolColor(usuario.rol),
                ),
                const SizedBox(width: 6),
                Text(
                  _getRolDisplayName(usuario.rol),
                  style: TextStyle(
                    color: _getRolColor(usuario.rol),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(Icons.person_outline, usuario.nombreUsuario),
            const SizedBox(height: 4),
            _buildInfoRow(Icons.email_outlined, usuario.email),
            if (usuario.areaNombre != null) ...[
              const SizedBox(height: 4),
              _buildInfoRow(Icons.business_outlined, usuario.areaNombre!),
            ],
            if (usuario.ultimoAcceso != null) ...[
              const SizedBox(height: 4),
              _buildInfoRow(
                Icons.access_time,
                'Último acceso: ${DateFormat('dd/MM/yyyy HH:mm').format(usuario.ultimoAcceso!)}',
              ),
            ],
          ],
        ),
      ),
      trailing:
          isDesktop
              ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showRolDialog(usuario),
                    tooltip: 'Cambiar rol',
                    color: theme.colorScheme.primary,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDeleteUsuario(usuario),
                    tooltip: 'Eliminar',
                    color: theme.colorScheme.error,
                  ),
                  Switch(
                    value: usuario.activo,
                    onChanged: (_) => _toggleEstado(usuario),
                  ),
                ],
              )
              : PopupMenuButton(
                itemBuilder:
                    (context) => [
                      PopupMenuItem(
                        child: const Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Cambiar rol'),
                          ],
                        ),
                        onTap:
                            () => Future.delayed(
                              const Duration(milliseconds: 100),
                              () => _showRolDialog(usuario),
                            ),
                      ),
                      PopupMenuItem(
                        child: Row(
                          children: [
                            Icon(
                              usuario.activo ? Icons.block : Icons.check_circle,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(usuario.activo ? 'Desactivar' : 'Activar'),
                          ],
                        ),
                        onTap:
                            () => Future.delayed(
                              const Duration(milliseconds: 100),
                              () => _toggleEstado(usuario),
                            ),
                      ),
                      PopupMenuItem(
                        child: const Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18),
                            SizedBox(width: 8),
                            Text('Eliminar'),
                          ],
                        ),
                        onTap:
                            () => Future.delayed(
                              const Duration(milliseconds: 100),
                              () => _confirmDeleteUsuario(usuario),
                            ),
                      ),
                    ],
              ),
    );
  }

  Widget _buildUserCardGrid(Usuario usuario, ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showRolDialog(usuario),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor:
                        usuario.activo
                            ? theme.colorScheme.primary
                            : Colors.grey,
                    child: Text(
                      usuario.nombreCompleto[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  if (!usuario.activo)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.block,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                usuario.nombreCompleto,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getRolColor(usuario.rol).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getRolDisplayName(usuario.rol),
                  style: TextStyle(
                    color: _getRolColor(usuario.rol),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => _showRolDialog(usuario),
                    tooltip: 'Cambiar rol',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => _confirmDeleteUsuario(usuario),
                    tooltip: 'Eliminar',
                  ),
                  Switch(
                    value: usuario.activo,
                    onChanged: (_) => _toggleEstado(usuario),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
