import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/area.dart';
import '../../models/usuario.dart';
import '../../providers/auth_provider.dart';
import '../../utils/error_helper.dart';
import '../../services/api_service.dart';
import '../../services/usuario_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/loading_shimmer.dart';
import 'user_dialogs.dart';

class RolesPermissionsScreen extends StatefulWidget {
  /// Si se especifica, la pantalla intentará enfocar/abrir directamente al usuario indicado.
  final int? initialUserId;

  const RolesPermissionsScreen({super.key, this.initialUserId});

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
  /// Por defecto "Todos" para que siempre se vean usuarios (evitar 0 de N si todos están inactivos).
  bool? _selectedEstadoFilter = null;
  bool _isGridView = false;
  bool _initialUserHandled = false;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// Solo los roles que acepta el backend (AdministradorSistema, AdministradorDocumentos, Contador, Gerente).
  final List<String> _roles = [
    'AdministradorSistema',
    'AdministradorDocumentos',
    'Contador',
    'Gerente',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (!authProvider.canManageUserPermissions) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Acceso denegado: Requiere permiso de administrador del sistema',
            ),
          ),
        );
      }
    });
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _searchQuery = _searchController.text);
  }

  Future<void> _loadData({bool showRefreshIndicator = false}) async {
    if (showRefreshIndicator) {
      setState(() => _isRefreshing = true);
    } else {
      setState(() => _isLoading = true);
    }
    try {
      final usuarioService = Provider.of<UsuarioService>(context, listen: false);
      final apiService = Provider.of<ApiService>(context, listen: false);
      final usuariosFuture = usuarioService.getAll(incluirInactivos: true);
      final areasResponse = await apiService.get('/areas');
      final usuarios = await usuariosFuture;

      if (mounted) {
        setState(() {
          _usuarios = usuarios;
          _areas = (areasResponse.data as List).map((json) => Area.fromJson(json)).toList();
          _isLoading = false;
          _isRefreshing = false;
        });
        if (!_initialUserHandled && widget.initialUserId != null) {
          _initialUserHandled = true;
          final target = _usuarios.firstWhere((u) => u.id == widget.initialUserId, orElse: () => _usuarios.first);
          _searchController.text = target.nombreUsuario;
          _searchQuery = target.nombreUsuario;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showRolDialog(target);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; _isRefreshing = false; });
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

  void _showCreateUserDialog() async {
    final result = await showDialog<CreateUsuarioDTO>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CreateUserDialog(
        roles: _roles,
        areas: _areas,
      ),
    );

    if (result != null) {
      _createUsuario(result);
    }
  }

  void _showRolDialog(Usuario usuario) async {
    final result = await showDialog<UpdateUsuarioDTO>(
      context: context,
      barrierDismissible: false,
      builder: (context) => EditUserDialog(
        usuario: usuario,
        roles: _roles,
        areas: _areas,
      ),
    );

    if (result != null) {
      _guardarEdicionUsuario(usuario, result);
    }
  }

  void _showPermissionsDialog(Usuario usuario) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UserPermissionsDialog(
        userId: usuario.id,
        userName: usuario.nombreUsuario,
      ),
    );
  }

  Future<void> _guardarEdicionUsuario(Usuario usuario, UpdateUsuarioDTO dto) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?['id'] as int?;
    // Usamos dto.activo en lugar de usuario.activo para la comprobación
    if (currentUserId != null && usuario.id == currentUserId && dto.activo == false) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No puedes desactivar tu propia cuenta'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    try {
      final usuarioService = Provider.of<UsuarioService>(context, listen: false);
      await usuarioService.updateUsuario(usuario.id, dto);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuario actualizado correctamente'),
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
            content: Text('Error al actualizar: ${ErrorHelper.getErrorMessage(e)}'),
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
      if (rol == 'AdministradorSistema') {
        stats['rol_$rol'] = _usuarios.where((u) => u.rol == rol || u.rol == 'Administrador').length;
      } else {
        stats['rol_$rol'] = _usuarios.where((u) => u.rol == rol).length;
      }
    }
    return stats;
  }

  List<Usuario> get _usuariosFiltrados {
    var filtered = _usuarios;
    final query = _searchQuery.trim();
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      filtered = filtered.where((usuario) {
        return usuario.nombreCompleto.toLowerCase().contains(q) ||
            usuario.nombreUsuario.toLowerCase().contains(q) ||
            (usuario.email.toLowerCase().contains(q));
      }).toList();
    }
    if (_selectedRolFilter != null) {
      filtered = filtered.where((usuario) {
        if (usuario.rol == _selectedRolFilter) return true;
        if (_selectedRolFilter == 'AdministradorSistema' && usuario.rol == 'Administrador') return true;
        return false;
      }).toList();
    }
    if (_selectedAreaFilter != null) {
      final areaId = int.tryParse(_selectedAreaFilter!);
      if (areaId != null) {
        filtered = filtered.where((usuario) => usuario.areaId == areaId).toList();
      }
    }
    if (_selectedEstadoFilter != null) {
      filtered = filtered.where((usuario) => usuario.activo == _selectedEstadoFilter).toList();
    }
    return filtered;
  }

  Future<void> _toggleEstado(Usuario usuario) async {
    try {
      final usuarioService = Provider.of<UsuarioService>(context, listen: false);
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

  Future<void> _confirmDeleteUsuario(Usuario usuario) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar usuario'),
        content: Text(
          'Se eliminará permanentemente a "${usuario.nombreCompleto}" (${usuario.nombreUsuario}). Esta acción no se puede deshacer. ¿Continuar?',
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
      ),
    );
    if (confirmed != true) return;
    try {
      final usuarioService = Provider.of<UsuarioService>(context, listen: false);
      await usuarioService.deleteUsuario(usuario.id, hard: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuario eliminado permanentemente.'),
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
            content: Text('Error al eliminar: ${ErrorHelper.getErrorMessage(e)}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _getRolDisplayName(String rol) {
    switch (rol) {
      case 'AdministradorSistema':
      case 'Administrador':
        return 'Administrador del Sistema';
      case 'AdministradorDocumentos':
        return 'Administrador de Documentos';
      case 'Contador':
        return 'Contador';
      case 'Gerente':
        return 'Gerente';
      default:
        return rol;
    }
  }

  IconData _getRolIcon(String rol) {
    switch (rol) {
      case 'AdministradorSistema':
      case 'Administrador':
        return Icons.security;
      case 'AdministradorDocumentos':
        return Icons.folder_shared;
      case 'Contador':
        return Icons.calculate;
      case 'Gerente':
        return Icons.business;
      default:
        return Icons.person_outline;
    }
  }

  Color _getRolColor(String rol) {
    switch (rol) {
      case 'AdministradorSistema':
      case 'Administrador':
        return Colors.deepPurple;
      case 'AdministradorDocumentos':
        return Colors.orange;
      case 'Contador':
        return Colors.blue;
      case 'Gerente':
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
    return _searchQuery.trim().isNotEmpty ||
        _selectedRolFilter != null ||
        _selectedAreaFilter != null ||
        _selectedEstadoFilter != null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

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
    int index = 0;
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
          index++,
        ),
        _buildStatCard(
          'Activos',
          stats['activos']!.toString(),
          Icons.check_circle,
          Colors.green,
          cardWidth,
          index++,
        ),
        _buildStatCard(
          'Inactivos',
          stats['inactivos']!.toString(),
          Icons.cancel,
          Colors.red,
          cardWidth,
          index++,
        ),
        ..._roles.map(
          (rol) => _buildStatCard(
            _getRolDisplayName(rol),
            stats['rol_$rol']!.toString(),
            _getRolIcon(rol),
            _getRolColor(rol),
            cardWidth,
            index++,
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
    int animIndex,
  ) {
    return AnimatedCard(
      delay: Duration(milliseconds: animIndex * 100),
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
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre, usuario o email...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon:
                          _searchQuery.trim().isNotEmpty
                              ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
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
            LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth;
                final dropdownWidth =
                    isDesktop ? 250.0 : (maxWidth > 0 ? maxWidth - 16 : 280.0);
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: dropdownWidth,
                      child: DropdownButtonFormField<String?>(
                        isExpanded: true,
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
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Todos los roles'),
                          ),
                          ..._roles.map(
                            (rol) => DropdownMenuItem<String?>(
                              value: rol,
                              child: Text(
                                _getRolDisplayName(rol),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ],
                        onChanged:
                            (value) =>
                                setState(() => _selectedRolFilter = value),
                      ),
                    ),
                    SizedBox(
                      width: dropdownWidth,
                      child: DropdownButtonFormField<String?>(
                        isExpanded: true,
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
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Todas las áreas'),
                          ),
                          ..._areas.map(
                            (area) => DropdownMenuItem<String?>(
                              value: area.id.toString(),
                              child: Text(
                                area.nombre,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged:
                            (value) =>
                                setState(() => _selectedAreaFilter = value),
                      ),
                    ),
                    SizedBox(
                      width: isDesktop ? 200.0 : dropdownWidth,
                      child: DropdownButtonFormField<bool?>(
                        isExpanded: true,
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
                          DropdownMenuItem<bool?>(
                            value: null,
                            child: Text('Todos'),
                          ),
                          DropdownMenuItem<bool?>(
                            value: true,
                            child: Text('Activos'),
                          ),
                          DropdownMenuItem<bool?>(
                            value: false,
                            child: Text('Inactivos'),
                          ),
                        ],
                        onChanged:
                            (value) =>
                                setState(() => _selectedEstadoFilter = value),
                      ),
                    ),
                  ],
                );
              },
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
        itemBuilder:
            (context, index) =>
                _buildUserCardGrid(_usuariosFiltrados[index], theme),
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
    final inactivo = !usuario.activo;
    return Opacity(
      opacity: inactivo ? 0.85 : 1,
      child: Container(
        decoration: inactivo
            ? BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade500, width: 1.5),
              )
            : null,
        child: ListTile(
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
              if (inactivo)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Inactivo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  usuario.nombreCompleto,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: inactivo ? Colors.grey.shade800 : null,
                  ),
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
          isDesktop ?
               Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shield_outlined),
                    onPressed: () => _showPermissionsDialog(usuario),
                    tooltip: 'Gestionar Permisos',
                    color: Colors.blueGrey,
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showRolDialog(usuario),
                    tooltip: 'Editar usuario',
                    color: theme.colorScheme.primary,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDeleteUsuario(usuario),
                    tooltip: 'Eliminar (borrado permanente)',
                    color: Colors.red.shade700,
                  ),
                  Switch(
                    value: usuario.activo,
                    onChanged: (_) => _toggleEstado(usuario),
                  ),
                ],
              )
              : PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'permisos':
                      _showPermissionsDialog(usuario);
                      break;
                    case 'rol':
                      _showRolDialog(usuario);
                      break;
                    case 'eliminar':
                      _confirmDeleteUsuario(usuario);
                      break;
                    case 'estado':
                      _toggleEstado(usuario);
                      break;
                  }
                },
                itemBuilder:
                    (context) => [
                      const PopupMenuItem<String>(
                        value: 'permisos',
                        child: Row(
                          children: [
                            Icon(Icons.shield_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Permisos'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'rol',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Editar usuario'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'eliminar',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Eliminar (permanente)'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'estado',
                        child: Row(
                          children: [
                            Icon(
                              usuario.activo ? Icons.toggle_on : Icons.toggle_off,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(usuario.activo ? 'Desactivar' : 'Activar'),
                          ],
                        ),
                      ),
                    ],
              ),
        ),
      ),
    );
  }

  Widget _buildUserCardGrid(Usuario usuario, ThemeData theme) {
    final inactivo = !usuario.activo;
    final card = Card(
      elevation: inactivo ? 0 : 2,
      color: inactivo ? Colors.grey.shade300 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: inactivo ? BorderSide(color: Colors.grey.shade500, width: 1.5) : BorderSide.none,
      ),
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
                            : Colors.grey.shade600,
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
              if (inactivo)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade600,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Inactivo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              Text(
                usuario.nombreCompleto,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: inactivo ? Colors.grey.shade700 : null,
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
                    icon: const Icon(Icons.shield_outlined, size: 18),
                    onPressed: () => _showPermissionsDialog(usuario),
                    tooltip: 'Permisos',
                    color: Colors.blueGrey,
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => _showRolDialog(usuario),
                    tooltip: 'Editar usuario',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => _confirmDeleteUsuario(usuario),
                    tooltip: 'Eliminar (permanente)',
                    color: Colors.red.shade700,
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
    return inactivo ? Opacity(opacity: 0.9, child: card) : card;
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
