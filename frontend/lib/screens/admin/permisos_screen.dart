import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/permiso.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_helper.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/loading_shimmer.dart';

class PermisosScreen extends StatefulWidget {
  const PermisosScreen({super.key});

  @override
  State<PermisosScreen> createState() => _PermisosScreenState();
}

class _PermisosScreenState extends State<PermisosScreen> {
  List<Permiso> _permisos = [];
  Map<String, Map<int, bool>> _matrizPermisos =
      {}; // rol -> permisoId -> tienePermiso
  List<String> _roles = [
    'AdministradorSistema',
    'AdministradorDocumentos',
    'Contador',
    'Gerente',
  ];
  String? _rolSeleccionado;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPermisos();
  }

  Future<void> _loadPermisos() async {
    setState(() => _isLoading = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get('/permisos/roles');

      final data = response.data as Map<String, dynamic>;
      final permisosList =
          (data['permisos'] as List)
              .map((p) => Permiso.fromJson(p as Map<String, dynamic>))
              .toList();

      final matriz = (data['matriz'] as List).cast<Map<String, dynamic>>();

      final matrizMap = <String, Map<int, bool>>{};
      for (var rolData in matriz) {
        final rol = rolData['rol'] as String;
        final permisosRol =
            (rolData['permisos'] as List).cast<Map<String, dynamic>>();
        matrizMap[rol] = {};
        for (var permisoData in permisosRol) {
          final permisoId = permisoData['id'] as int;
          final tienePermiso = permisoData['tienePermiso'] as bool;
          matrizMap[rol]![permisoId] = tienePermiso;
        }
      }

      setState(() {
        _permisos = permisosList;
        _matrizPermisos = matrizMap;
        _rolSeleccionado = _roles.isNotEmpty ? _roles[0] : null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ErrorHelper.getErrorMessage(e),
                    style: const TextStyle(fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _togglePermiso(
    String rol,
    int permisoId,
    bool nuevoEstado,
  ) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
      _matrizPermisos[rol]![permisoId] = nuevoEstado;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);

      if (nuevoEstado) {
        await apiService.post(
          '/permisos/asignar',
          data: {'rol': rol, 'permisoId': permisoId},
        );
      } else {
        await apiService.post(
          '/permisos/revocar',
          data: {'rol': rol, 'permisoId': permisoId},
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  nuevoEstado ? Icons.check_circle : Icons.remove_circle,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Text(
                  nuevoEstado
                      ? 'Permiso asignado correctamente'
                      : 'Permiso revocado correctamente',
                ),
              ],
            ),
            backgroundColor: AppTheme.colorExito,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Revertir cambio en caso de error
      setState(() {
        _matrizPermisos[rol]![permisoId] = !nuevoEstado;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ErrorHelper.getErrorMessage(e),
                    style: const TextStyle(fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  String _getRolDisplayName(String rol) {
    switch (rol) {
      case 'AdministradorSistema':
        return 'Administrador de Sistema';
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
        return Icons.security;
      case 'AdministradorDocumentos':
        return Icons.folder_shared;
      case 'Contador':
        return Icons.calculate;
      case 'Gerente':
        return Icons.business_center;
      default:
        return Icons.person_outline;
    }
  }

  Color _getRolColor(String rol) {
    switch (rol) {
      case 'AdministradorSistema':
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Gestión de Permisos',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body:
          _isLoading
              ? _buildLoadingShimmer()
              : isDesktop
              ? _buildDesktopLayout(theme)
              : _buildMobileLayout(theme),
    );
  }

  Widget _buildLoadingShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder:
          (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: LoadingShimmer(
              width: double.infinity,
              height: 100,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
    );
  }

  Widget _buildDesktopLayout(ThemeData theme) {
    return Row(
      children: [
        // Panel lateral con roles
        Container(
          width: 280,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              right: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.1),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Roles',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _roles.length,
                  itemBuilder: (context, index) {
                    final rol = _roles[index];
                    final isSelected = _rolSeleccionado == rol;
                    return InkWell(
                      onTap: () {
                        setState(() => _rolSeleccionado = rol);
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? _getRolColor(rol).withOpacity(0.1)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                isSelected
                                    ? _getRolColor(rol)
                                    : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _getRolColor(rol).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getRolIcon(rol),
                                color: _getRolColor(rol),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _getRolDisplayName(rol),
                                style: GoogleFonts.inter(
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // Panel principal con permisos
        Expanded(
          child:
              _rolSeleccionado != null
                  ? _buildPermisosPanel(theme, true)
                  : Center(
                    child: Text(
                      'Seleccione un rol para ver sus permisos',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(ThemeData theme) {
    return Column(
      children: [
        // Selector de rol
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.1),
              ),
            ),
          ),
          child: DropdownButtonFormField<String>(
            value: _rolSeleccionado,
            decoration: InputDecoration(
              labelText: 'Seleccionar Rol',
              prefixIcon: const Icon(Icons.admin_panel_settings),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            items:
                _roles.map((rol) {
                  return DropdownMenuItem(
                    value: rol,
                    child: Row(
                      children: [
                        Icon(
                          _getRolIcon(rol),
                          size: 18,
                          color: _getRolColor(rol),
                        ),
                        const SizedBox(width: 12),
                        Text(_getRolDisplayName(rol)),
                      ],
                    ),
                  );
                }).toList(),
            onChanged: (value) {
              setState(() => _rolSeleccionado = value);
            },
          ),
        ),
        // Panel de permisos
        Expanded(
          child:
              _rolSeleccionado != null
                  ? _buildPermisosPanel(theme, false)
                  : Center(
                    child: Text(
                      'Seleccione un rol para ver sus permisos',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _buildPermisosPanel(ThemeData theme, bool isDesktop) {
    if (_rolSeleccionado == null) return const SizedBox.shrink();

    final permisosRol = _matrizPermisos[_rolSeleccionado] ?? {};

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 32 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getRolColor(_rolSeleccionado!).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getRolIcon(_rolSeleccionado!),
                  color: _getRolColor(_rolSeleccionado!),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getRolDisplayName(_rolSeleccionado!),
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gestionar permisos para este rol',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'Permisos Disponibles',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ..._permisos.map((permiso) {
            final tienePermiso = permisosRol[permiso.id] ?? false;
            return AnimatedCard(
              delay: Duration(milliseconds: _permisos.indexOf(permiso) * 50),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        tienePermiso
                            ? AppTheme.colorExito.withOpacity(0.3)
                            : theme.colorScheme.outline.withOpacity(0.1),
                    width: tienePermiso ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: tienePermiso,
                      onChanged:
                          _isSaving
                              ? null
                              : (value) {
                                _togglePermiso(
                                  _rolSeleccionado!,
                                  permiso.id,
                                  value ?? false,
                                );
                              },
                      activeColor: AppTheme.colorExito,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            permiso.nombre,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          if (permiso.descripcion != null &&
                              permiso.descripcion!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              permiso.descripcion!,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (tienePermiso)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.colorExito.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Activo',
                          style: TextStyle(
                            color: AppTheme.colorExito,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
