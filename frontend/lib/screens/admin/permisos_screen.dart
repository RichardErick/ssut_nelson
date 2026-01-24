import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/permiso.dart';
import '../../models/usuario.dart';
import '../../services/api_service.dart';
import '../../services/usuario_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_helper.dart';

class PermisosScreen extends StatefulWidget {
  const PermisosScreen({super.key});

  @override
  State<PermisosScreen> createState() => _PermisosScreenState();
}

class _PermisoUsuarioEntry {
  final Permiso permiso;
  final bool roleHas;
  final bool userHas;

  const _PermisoUsuarioEntry({
    required this.permiso,
    required this.roleHas,
    required this.userHas,
  });
}

class _PermisosScreenState extends State<PermisosScreen> {
  // Data
  List<Usuario> _usuarios = [];
  List<Usuario> _usuariosFiltrados = [];
  List<_PermisoUsuarioEntry> _permisosUsuario = [];
  Map<String, List<_PermisoUsuarioEntry>> _permisosPorModulo = {};
  
  // State
  final Map<int, bool> _cambiosLocales = {};
  final Map<int, bool> _userPermOriginal = {};
  
  Usuario? _usuarioSeleccionado;
  bool _isLoading = true;
  bool _isLoadingPermisos = false;
  bool _isSaving = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filtrarUsuarios);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filtrarUsuarios() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _usuariosFiltrados = List.from(_usuarios);
      } else {
        _usuariosFiltrados = _usuarios.where((u) {
          return u.nombreCompleto.toLowerCase().contains(query) ||
                 u.nombreUsuario.toLowerCase().contains(query) ||
                 u.rol.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final usuarioService = Provider.of<UsuarioService>(context, listen: false);

      // Fetch Users
      final usuariosList = await usuarioService.getAll();
      Usuario? selected = _usuarioSeleccionado;
      if (selected != null) {
        final idx = usuariosList.indexWhere((u) => u.id == selected!.id);
        selected = idx == -1 && usuariosList.isNotEmpty ? usuariosList.first : (idx == -1 ? null : usuariosList[idx]);
      } else if (usuariosList.isNotEmpty) {
        selected = usuariosList.first;
      }

      if (mounted) {
        setState(() {
          _usuarios = usuariosList;
          _usuariosFiltrados = List.from(usuariosList);
          _usuarioSeleccionado = selected;
          _isLoading = false;
        });
      }

      if (selected != null) {
        await _loadPermisosUsuario(selected);
      } else {
        if (mounted) {
          setState(() {
            _permisosUsuario = [];
            _permisosPorModulo = {};
            _cambiosLocales.clear();
            _userPermOriginal.clear();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: ${ErrorHelper.getErrorMessage(e)}'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  Future<void> _loadPermisosUsuario(Usuario usuario) async {
    setState(() => _isLoadingPermisos = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get('/permisos/usuarios/${usuario.id}');
      final data = response.data as Map<String, dynamic>;

      final permisosList = (data['permisos'] as List)
          .map((p) {
            final permiso = Permiso.fromJson(p as Map<String, dynamic>);
            final roleHas = p['roleHas'] as bool? ?? false;
            final userHas = p['userHas'] as bool? ?? false;
            return _PermisoUsuarioEntry(
              permiso: permiso,
              roleHas: roleHas,
              userHas: userHas,
            );
          })
          .toList();

      final grouped = <String, List<_PermisoUsuarioEntry>>{};
      final originales = <int, bool>{};
      for (final entry in permisosList) {
        if (!grouped.containsKey(entry.permiso.modulo)) {
          grouped[entry.permiso.modulo] = [];
        }
        grouped[entry.permiso.modulo]!.add(entry);
        originales[entry.permiso.id] = entry.userHas;
      }

      if (mounted) {
        setState(() {
          _permisosUsuario = permisosList;
          _permisosPorModulo = grouped;
          _userPermOriginal
            ..clear()
            ..addAll(originales);
          _cambiosLocales.clear();
          _isLoadingPermisos = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPermisos = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar permisos: ${ErrorHelper.getErrorMessage(e)}'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  Future<void> _selectUsuario(Usuario usuario) async {
    if (_usuarioSeleccionado?.id == usuario.id) return;
    setState(() {
      _usuarioSeleccionado = usuario;
      _cambiosLocales.clear();
    });
    await _loadPermisosUsuario(usuario);
  }

  void _onPermisoChanged(_PermisoUsuarioEntry entry, bool value) {
    if (entry.roleHas) return;
    setState(() {
      final permisoId = entry.permiso.id;
      final originalState = _userPermOriginal[permisoId] ?? false;
      if (value == originalState) {
        _cambiosLocales.remove(permisoId);
      } else {
        _cambiosLocales[permisoId] = value;
      }
    });
  }

  bool _tienePermiso(_PermisoUsuarioEntry entry) {
    if (entry.roleHas) return true;
    final permisoId = entry.permiso.id;
    if (_cambiosLocales.containsKey(permisoId)) {
      return _cambiosLocales[permisoId]!;
    }
    return entry.userHas;
  }

  bool _isModified(_PermisoUsuarioEntry entry) {
     return _cambiosLocales.containsKey(entry.permiso.id);
  }

  int _countChanges() {
    int count = 0;
    count += _cambiosLocales.length;
    return count;
  }

  void _restaurarCambios() {
    setState(() {
      _cambiosLocales.clear();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cambios descartados')),
      );
    }
  }

  Future<void> _guardarCambios() async {
    if (_isSaving) return;
    if (_usuarioSeleccionado == null) return;
    setState(() => _isSaving = true);

    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      final usuarioId = _usuarioSeleccionado!.id;
      for (var permisoId in _cambiosLocales.keys) {
        final nuevoEstado = _cambiosLocales[permisoId]!;
        if (nuevoEstado) {
          await apiService.post(
            '/permisos/usuarios/asignar',
            data: {'usuarioId': usuarioId, 'permisoId': permisoId},
          );
        } else {
          await apiService.post(
            '/permisos/usuarios/revocar',
            data: {'usuarioId': usuarioId, 'permisoId': permisoId},
          );
        }
      }

      await _loadPermisosUsuario(_usuarioSeleccionado!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
               children: [
                 Icon(Icons.check_circle, color: Colors.white),
                 SizedBox(width: 12),
                 Text('Permisos guardados correctamente'),
               ],
            ),
            backgroundColor: AppTheme.colorExito,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: ${ErrorHelper.getErrorMessage(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _getRolDisplayName(String rol) {
    switch (rol) {
      case 'AdministradorSistema': return 'Administrador de Sistema';
      case 'AdministradorDocumentos': return 'Admin. Documentos';
      case 'Contador': return 'Contador';
      case 'Gerente': return 'Gerente';
      case 'Administrador': return 'Administrador';
      case 'ArchivoCentral': return 'Archivo Central';
      case 'TramiteDocumentario': return 'Trámite Documentario';
      case 'Usuario': return 'Usuario';
      case 'Supervisor': return 'Supervisor';
      default: return rol;
    }
  }

  Color _getRolColor(String rol) {
    switch (rol) {
      case 'AdministradorSistema':
      case 'Administrador': 
        return Colors.red.shade700;
      case 'Gerente': return Colors.purple;
      case 'Usuario': return Colors.blue;     
      default: return Colors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final changesCount = _countChanges();

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Permisos por Usuario',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar datos',
            onPressed: _loadData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                isDesktop
                    ? _buildDesktopLayout(theme)
                    : _buildMobileLayout(theme),
                
                // Floating Action Bar for Changes
                if (changesCount > 0)
                  Positioned(
                    bottom: 24,
                    left: 24,
                    right: 24,
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 500),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.inverseSurface,
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.colorExito,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$changesCount',
                                style: const TextStyle(
                                  color: Colors.white, 
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Cambios pendientes',
                              style: TextStyle(
                                color: theme.colorScheme.onInverseSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: _isSaving ? null : _restaurarCambios,
                              child: const Text('Descartar'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: _isSaving ? null : _guardarCambios,
                              icon: _isSaving 
                                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) 
                                : const Icon(Icons.check, size: 16),
                              label: const Text('Guardar'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.colorExito,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildDesktopLayout(ThemeData theme) {
    return Row(
      children: [
        // Sidebar Users
        Container(
          width: 320,
          color: theme.colorScheme.surface,
          child: Column(
            children: [
              _buildUserSearchHeader(theme),
              Expanded(
                child: ListView.separated(
                  itemCount: _usuariosFiltrados.length,
                  separatorBuilder: (c, i) => Divider(height: 1, color: theme.colorScheme.outline.withOpacity(0.05)),
                  itemBuilder: (context, index) {
                    final usuario = _usuariosFiltrados[index];
                    return _buildUserTile(usuario, theme);
                  },
                ),
              ),
            ],
          ),
        ),
        VerticalDivider(width: 1, color: theme.colorScheme.outline.withOpacity(0.1)),
        // Main Content
        Expanded(
          child: _usuarioSeleccionado != null
              ? (_isLoadingPermisos
                  ? const Center(child: CircularProgressIndicator())
                  : _buildPermissionsContent(theme))
              : _buildEmptyState(theme),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(ThemeData theme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          color: theme.colorScheme.surface,
          child: Column(
             children: [
               _buildUserSearchHeader(theme),
               const SizedBox(height: 8),
               DropdownButtonFormField<Usuario>(
                  value: _usuarioSeleccionado,
                  isExpanded: true,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  ),
                  hint: const Text('Seleccionar Usuario'),
                  items: _usuariosFiltrados.map((u) {
                    return DropdownMenuItem(
                      value: u,
                      child: Text(u.nombreCompleto, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      _selectUsuario(val);
                    }
                  },
               ),
             ],
          ),
        ),
        Expanded(
          child: _usuarioSeleccionado != null
              ? (_isLoadingPermisos
                  ? const Center(child: CircularProgressIndicator())
                  : _buildPermissionsContent(theme))
              : _buildEmptyState(theme),
        ),
      ],
    );
  }

  Widget _buildUserSearchHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar usuario...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty 
                ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => _searchController.clear())
                : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.4),
            ),
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(Usuario usuario, ThemeData theme) {
    final isSelected = _usuarioSeleccionado?.id == usuario.id;
    final rolColor = _getRolColor(usuario.rol);
    
    return ListTile(
      onTap: () => _selectUsuario(usuario),
      selected: isSelected,
      selectedTileColor: theme.colorScheme.primary.withOpacity(0.08),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: rolColor.withOpacity(0.1),
        child: Text(
          usuario.nombreUsuario.isNotEmpty ? usuario.nombreUsuario[0].toUpperCase() : '?',
          style: TextStyle(
            color: rolColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      title: Text(
        usuario.nombreCompleto,
        style: GoogleFonts.inter(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
          fontSize: 14,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: rolColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _getRolDisplayName(usuario.rol),
              style: TextStyle(
                fontSize: 10, 
                color: rolColor,
                fontWeight: FontWeight.w600
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsContent(ThemeData theme) {
    final modules = _permisosPorModulo.keys.toList()..sort();
    if (_permisosUsuario.isEmpty) {
      return _buildEmptyPermissions(theme);
    }

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          color: theme.colorScheme.surface,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _usuarioSeleccionado!.nombreCompleto,
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Rol asignado: ',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        ),
                        Container(
                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                           decoration: BoxDecoration(
                              color: _getRolColor(_usuarioSeleccionado!.rol).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _getRolColor(_usuarioSeleccionado!.rol).withOpacity(0.3)),
                           ),
                           child: Text(
                             _getRolDisplayName(_usuarioSeleccionado!.rol),
                             style: TextStyle(color: _getRolColor(_usuarioSeleccionado!.rol), fontWeight: FontWeight.bold, fontSize: 12),
                           ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Modules and Permissions
        Expanded(
          child: Container(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3), // Slight gray bg
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 100), // Bottom padding for FAB
              itemCount: modules.length,
              itemBuilder: (context, index) {
                final module = modules[index];
                final permisos = _permisosPorModulo[module] ?? [];
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12, top: 8),
                      child: Row(
                        children: [
                          Icon(Icons.layers_outlined, size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            module.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                              fontSize: 12, 
                              letterSpacing: 1.1
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Divider(color: theme.colorScheme.outline.withOpacity(0.2))),
                        ],
                      ),
                    ),
                    
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 400,
                        mainAxisExtent: 90, // Fixed height for cards
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: permisos.length,
                      itemBuilder: (context, pIndex) {
                        final entry = permisos[pIndex];
                        return _buildPermissionCard(entry, theme);
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyPermissions(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.security_outlined, size: 64, color: theme.colorScheme.outline.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'Sin permisos disponibles',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard(_PermisoUsuarioEntry entry, ThemeData theme) {
    final tienePermiso = _tienePermiso(entry);
    final isModified = _isModified(entry);
    final isLockedByRole = entry.roleHas;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isModified 
            ? Colors.orange 
            : (tienePermiso ? theme.colorScheme.primary.withOpacity(0.5) : theme.colorScheme.outline.withOpacity(0.1)),
          width: isModified || tienePermiso ? 1.5 : 1,
        ),
        boxShadow: tienePermiso ? [
          BoxShadow(
             color: theme.colorScheme.shadow.withOpacity(0.05),
             blurRadius: 8,
             offset: const Offset(0, 2),
          )
        ] : [],
      ),
      child: Opacity(
        opacity: isLockedByRole ? 0.5 : 1.0,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: isLockedByRole 
              ? () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Este permiso es heredado del rol y no se puede modificar.'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 2),
                    )
                  );
                } 
              : () => _onPermisoChanged(entry, !tienePermiso),
            child: Padding(
              padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                AbsorbPointer(
                  absorbing: isLockedByRole,
                  child: Switch(
                    value: tienePermiso,
                    onChanged: isLockedByRole ? null : (val) => _onPermisoChanged(entry, val),
                    activeColor: AppTheme.colorExito,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       Text(
                         entry.permiso.nombre,
                         style: GoogleFonts.inter(
                           fontWeight: FontWeight.w600,
                           fontSize: 13,
                         ),
                         maxLines: 2,
                         overflow: TextOverflow.ellipsis,
                       ),
                       if (entry.permiso.descripcion?.isNotEmpty == true) ...[
                         const SizedBox(height: 2),
                         Text(
                           entry.permiso.descripcion!,
                           style: TextStyle(
                             fontSize: 11,
                             color: theme.colorScheme.onSurfaceVariant,
                           ),
                           maxLines: 1,
                           overflow: TextOverflow.ellipsis,
                         ),
                       ],
                       if (isLockedByRole) ...[
                         const SizedBox(height: 4),
                         Row(
                           children: [
                             Icon(Icons.lock_outline, size: 12, color: theme.colorScheme.onSurfaceVariant),
                             const SizedBox(width: 4),
                             Text(
                               'Rol: ${_getRolDisplayName(_usuarioSeleccionado!.rol)}',
                               style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                               maxLines: 1,
                               overflow: TextOverflow.ellipsis,
                             ),
                           ],
                         ),
                       ],
                       if (isModified)
                         Padding(
                           padding: const EdgeInsets.only(top: 4),
                           child: Text(
                             'Modificado',
                             style: TextStyle(fontSize: 10, color: Colors.orange.shade700, fontWeight: FontWeight.bold),
                           ),
                         ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app_outlined, size: 64, color: theme.colorScheme.outline.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'Selecciona un usuario',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withOpacity(0.5)
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Podrás gestionar los permisos asociados a su rol.',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
