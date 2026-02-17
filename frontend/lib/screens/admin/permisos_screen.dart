import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/permiso.dart';
import '../../models/user_role.dart';
import '../../models/usuario.dart';
import '../../providers/auth_provider.dart';
import '../../services/permiso_service.dart';
import '../../services/usuario_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_helper.dart';

class PermisosScreen extends StatefulWidget {
  const PermisosScreen({super.key});

  @override
  State<PermisosScreen> createState() => _PermisosScreenState();
}

class _PermisosScreenState extends State<PermisosScreen> {
  // Data
  List<Usuario> _usuarios = [];
  List<Usuario> _usuariosFiltrados = [];
  List<Permiso> _permisosDisponiblesLista = [];

  // Permisos disponibles (solo los que se usan en la matriz)
  final Map<String, String> _permisosDisponibles = {
    'ver_documento': 'Ver Documento',
    'subir_documento': 'Subir Documento',
    'editar_metadatos': 'Editar Metadatos',
    'borrar_documento': 'Borrar Documento',
    'ver_movimientos': 'Ver Movimientos',
  };

  // Matriz: solo estos permisos por rol. Admin Sistema solo ver; Admin Documentos ver+subir+editar metadatos+borrar; Contador ver+subir; Gerente solo ver.
  final Map<UserRole, List<String>> _permisosPorRol = {
    UserRole.administradorSistema: ['ver_documento'],
    UserRole.administradorDocumentos: [
      'ver_documento',
      'subir_documento',
      'editar_metadatos',
      'borrar_documento',
      'ver_movimientos',
    ],
    UserRole.contador: ['ver_documento', 'subir_documento', 'ver_movimientos'],
    UserRole.gerente: ['ver_documento', 'ver_movimientos'],
  };

  // State
  final Map<String, Map<String, bool>> _permisosActivos = {};
  final Map<String, Map<String, bool>> _initialPermisosActivos = {};

  Usuario? _usuarioSeleccionado;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isLoadingPermisosUsuario = false;
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
      _usuariosFiltrados =
          _usuarios.where((usuario) {
            return usuario.nombreCompleto.toLowerCase().contains(query) ||
                usuario.nombreUsuario.toLowerCase().contains(query);
          }).toList();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final usuarioService = Provider.of<UsuarioService>(
        context,
        listen: false,
      );
      final permisoService = Provider.of<PermisoService>(
        context,
        listen: false,
      );

      final usuarios = await usuarioService.getAll();
      final permisos = await permisoService.getAll();

      if (mounted) {
        setState(() {
          _usuarios = usuarios.where((u) => u.activo).toList();
          _usuariosFiltrados = List.from(_usuarios);
          _permisosDisponiblesLista = permisos;
          _isLoading = false;
        });

        // Seleccionar el primer usuario si existe
        if (_usuarios.isNotEmpty && _usuarioSeleccionado == null) {
          _seleccionarUsuario(_usuarios.first);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error cargando usuarios: ${ErrorHelper.getErrorMessage(e)}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Carga los permisos reales del usuario desde la API (lo que está guardado en el sistema).
  Future<void> _cargarPermisosUsuario(Usuario usuario) async {
    if (!mounted) return;
    setState(() => _isLoadingPermisosUsuario = true);
    try {
      final permisoService = Provider.of<PermisoService>(context, listen: false);
      final entries = await permisoService.getPermisosUsuarioAdmin(usuario.id);
      if (!mounted) return;
      final mapa = <String, bool>{};
      for (final codigo in _permisosDisponibles.keys) {
        mapa[codigo] = false;
      }
      for (final entry in entries) {
        final codigo = entry.permiso.codigo;
        if (_permisosDisponibles.containsKey(codigo)) {
          mapa[codigo] = entry.userHas;
        }
      }
      setState(() {
        _permisosActivos[usuario.nombreUsuario] = mapa;
        _initialPermisosActivos[usuario.nombreUsuario] = Map.from(mapa);
        _isLoadingPermisosUsuario = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPermisosUsuario = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error cargando permisos: ${ErrorHelper.getErrorMessage(e)}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _seleccionarUsuario(Usuario usuario) {
    print('DEBUG: Seleccionando usuario: ${usuario.nombreCompleto}');
    print('DEBUG: Rol del usuario: "${usuario.rol}"');
    print('DEBUG: Nombre de usuario: "${usuario.nombreUsuario}"');

    setState(() {
      _usuarioSeleccionado = usuario;
    });

    // Cargar permisos reales desde la API (persistidos en el sistema)
    _cargarPermisosUsuario(usuario);
  }

  UserRole _parseRoleWithContext(
    String roleName,
    String nombreUsuario,
    String nombreCompleto,
  ) {
    print(
      'DEBUG PERMISOS: Parseando rol: "$roleName" para usuario: "$nombreUsuario" ($nombreCompleto)',
    );
    final roleNameLower = roleName.toLowerCase().trim();
    final usernameLower = nombreUsuario.toLowerCase().trim();
    final fullNameLower = nombreCompleto.toLowerCase().trim();

    switch (roleNameLower) {
      case 'administradorsistema':
      case 'administrador sistema':
      case 'admin sistema':
        print('DEBUG PERMISOS: Mapeado a AdministradorSistema');
        return UserRole.administradorSistema;
      case 'administradordocumentos':
      case 'administrador documentos':
      case 'admin documentos':
      case 'administrador de documentos':
        print('DEBUG PERMISOS: Mapeado a AdministradorDocumentos');
        return UserRole.administradorDocumentos;
      case 'administrador':
      case 'admin':
      case 'administrator':
        // Para el rol genérico "Administrador", usar contexto del usuario
        // Si el nombre completo contiene "documentos" o el username es "doc_admin", es admin de documentos
        if (fullNameLower.contains('documentos') ||
            fullNameLower.contains('documento') ||
            usernameLower == 'doc_admin' ||
            usernameLower.contains('doc')) {
          print(
            'DEBUG PERMISOS: Rol "Administrador" mapeado a AdministradorDocumentos por contexto (documentos)',
          );
          return UserRole.administradorDocumentos;
        }
        // Si el nombre completo contiene "sistema" o el username es "admin", es admin de sistema
        else if (fullNameLower.contains('sistema') ||
            usernameLower == 'admin') {
          print(
            'DEBUG PERMISOS: Rol "Administrador" mapeado a AdministradorSistema por contexto (sistema)',
          );
          return UserRole.administradorSistema;
        } else {
          // Por defecto, si no hay contexto claro, asignar AdministradorDocumentos
          print(
            'DEBUG PERMISOS: Rol "Administrador" mapeado a AdministradorDocumentos por defecto',
          );
          return UserRole.administradorDocumentos;
        }
      case 'contador':
        print('DEBUG PERMISOS: Mapeado a Contador');
        return UserRole.contador;
      case 'gerente':
        print('DEBUG PERMISOS: Mapeado a Gerente');
        return UserRole.gerente;
      default:
        print(
          'DEBUG PERMISOS: Rol no reconocido: "$roleName", asignando AdministradorDocumentos por defecto',
        );
        return UserRole.administradorDocumentos;
    }
  }

  UserRole _parseRole(String roleName) {
    // Función de compatibilidad que llama a la nueva función con contexto vacío
    return _parseRoleWithContext(roleName, '', '');
  }

  /// Devuelve la lista de códigos de permiso que tiene el rol base del usuario.
  List<String> _obtenerPermisosRol(Usuario usuario) {
    final role = _parseRoleWithContext(
      usuario.rol,
      usuario.nombreUsuario,
      usuario.nombreCompleto,
    );
    return _permisosPorRol[role] ?? [];
  }

  void _togglePermiso(String permiso, bool nuevoValor) {
    if (_usuarioSeleccionado == null) return;
    final username = _usuarioSeleccionado!.nombreUsuario;
    if (!_permisosActivos.containsKey(username)) {
      _permisosActivos[username] = {};
    }
    setState(() {
      _permisosActivos[username]![permiso] = nuevoValor;
    });
  }

  Future<void> _guardarCambios() async {
    if (_usuarioSeleccionado == null) return;

    setState(() => _isSaving = true);

    final permisoService = Provider.of<PermisoService>(context, listen: false);
    final usuario = _usuarioSeleccionado!;
    final permisosActivos = _permisosActivos[usuario.nombreUsuario] ?? {};
    final permisosIniciales = _initialPermisosActivos[usuario.nombreUsuario] ?? {};
    
    // Solo enviar los que realmente cambiaron
    final codigosAGuardar = _permisosDisponibles.keys.where((codigo) {
      return (permisosActivos[codigo] ?? false) != (permisosIniciales[codigo] ?? false);
    }).toList();

    if (codigosAGuardar.isEmpty) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay cambios pendientes para guardar'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    int ok = 0;
    int fail = 0;
    List<String> errorMessages = [];
    
    for (final codigo in codigosAGuardar) {
      final activo = permisosActivos[codigo] ?? false;

      final permiso = _permisosDisponiblesLista.firstWhere(
        (p) => p.codigo == codigo,
        orElse: () => Permiso(
          id: 0,
          codigo: codigo,
          nombre: '',
          descripcion: '',
          modulo: '',
          activo: true,
        ),
      );
      if (permiso.id == 0) continue;

      try {
        if (activo) {
          await permisoService.asignarPermiso(usuario.id, permiso.id);
          ok++;
        } else {
          await permisoService.revocarPermiso(usuario.id, permiso.id);
          ok++;
        }
      } catch (e) {
        fail++;
        final msg = ErrorHelper.getErrorMessage(e);
        if (!errorMessages.contains(msg)) {
          errorMessages.add(msg);
        }
      }
    }

    if (mounted) {
      setState(() => _isSaving = false);
      await _cargarPermisosUsuario(usuario);
      
      if (fail == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(ok > 0
                    ? 'Permisos guardados correctamente'
                    : 'Sin cambios que guardar'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // Mostrar alerta detallada si hay errores
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
                const SizedBox(width: 10),
                const Text('Atención al guardar'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Se guardaron $ok cambios, pero $fail fallaron.'),
                const SizedBox(height: 16),
                const Text('Motivos del error:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...errorMessages.map((msg) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(child: Text(msg)),
                    ],
                  ),
                )),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendido'),
              ),
            ],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    } else {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Solo el administrador de sistema puede gestionar permisos
    if (!authProvider.canManageUserPermissions) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Gestión de Permisos', style: GoogleFonts.poppins()),
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

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Gestión de Permisos', style: GoogleFonts.poppins()),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar datos',
            onPressed: _loadData,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final height = constraints.maxHeight;
                  if (width <= 0 || height <= 0) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return Row(
                    children: [
                      Expanded(flex: 1, child: _buildUsuariosList()),
                      const VerticalDivider(width: 1),
                      Expanded(flex: 2, child: _buildPermisosPanel()),
                    ],
                  );
                },
              ),
    );
  }

  Widget _buildUsuariosList() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Buscador
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar usuario...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          // Lista de usuarios
          Expanded(
            child: ListView.builder(
              itemCount: _usuariosFiltrados.length,
              itemBuilder: (context, index) {
                final usuario = _usuariosFiltrados[index];
                final isSelected = _usuarioSeleccionado?.id == usuario.id;

                return ListTile(
                  selected: isSelected,
                  selectedTileColor: AppTheme.colorPrimario.withOpacity(0.1),
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.colorPrimario,
                    child: Text(
                      usuario.nombreCompleto.isNotEmpty
                          ? usuario.nombreCompleto[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    usuario.nombreCompleto,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@${usuario.nombreUsuario}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getRoleColor(usuario.rol).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getRoleDisplayName(usuario.rol),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _getRoleColor(usuario.rol),
                          ),
                        ),
                      ),
                    ],
                  ),
                  onTap: () => _seleccionarUsuario(usuario),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermisosPanel() {
    if (_usuarioSeleccionado == null) {
      return const Center(
        child: Text(
          'Selecciona un usuario para gestionar sus permisos',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final usuario = _usuarioSeleccionado!;
    final permisosUsuario = _permisosActivos[usuario.nombreUsuario] ?? {};

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Header del usuario
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.colorPrimario.withOpacity(0.1), Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.colorPrimario,
                  child: Text(
                    usuario.nombreCompleto.isNotEmpty
                        ? usuario.nombreCompleto[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        usuario.nombreCompleto,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '@${usuario.nombreUsuario}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getRoleColor(usuario.rol).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _getRoleDisplayName(usuario.rol),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _getRoleColor(usuario.rol),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Permisos
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Control de Permisos por Usuario',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Todos los permisos pueden activarse o desactivarse por usuario. Activa o desactiva según lo acordado con el seguro.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_isLoadingPermisosUsuario)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          // Todos los permisos disponibles para cualquier rol (activar/desactivar según se requiera)
                          final todosLosPermisos = _permisosDisponibles.keys.toList();
                          if (todosLosPermisos.isEmpty) {
                            return Center(
                              child: Text(
                                'No hay permisos configurados.',
                                style: GoogleFonts.inter(color: Colors.grey.shade600),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }
                          return ListView.builder(
                            itemCount: todosLosPermisos.length,
                            itemBuilder: (context, index) {
                              final permiso = todosLosPermisos[index];
                              final nombre =
                                  _permisosDisponibles[permiso] ?? permiso;
                              final estaActivo = permisosUsuario[permiso] ?? false;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color:
                                      estaActivo
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _getPermisoIcon(permiso),
                                  color: estaActivo ? Colors.green : Colors.red,
                                ),
                              ),
                              title: Text(
                                nombre,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                estaActivo
                                    ? 'Permiso ACTIVO'
                                    : 'Permiso DESACTIVADO',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color:
                                      estaActivo
                                          ? Colors.green.shade600
                                          : Colors.red.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: Switch(
                                value: estaActivo,
                                onChanged: _isSaving
                                    ? null
                                    : (value) => _togglePermiso(permiso, value),
                                activeColor: Colors.green,
                                inactiveThumbColor: Colors.red.shade300,
                                inactiveTrackColor: Colors.red.shade100,
                              ),
                            ),
                          );
                        },
                      );
                        }
                    ),
                  ),

                  if (!_isLoadingPermisosUsuario) ...[
                    const SizedBox(height: 16),
                    // Botón guardar
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _guardarCambios,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.colorPrimario,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child:
                            _isSaving
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : Text(
                                  'Guardar Cambios',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String rol) {
    switch (rol) {
      case 'AdministradorSistema':
        return Colors.red;
      case 'AdministradorDocumentos':
        return Colors.blue;
      case 'Contador':
        return Colors.green;
      case 'Gerente':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getRoleDisplayName(String rol) {
    switch (rol) {
      case 'AdministradorSistema':
        return 'Admin Sistema';
      case 'AdministradorDocumentos':
        return 'Admin Documentos';
      case 'Contador':
        return 'Contador';
      case 'Gerente':
        return 'Gerente';
      default:
        return rol;
    }
  }

  IconData _getPermisoIcon(String permiso) {
    switch (permiso) {
      case 'ver_documento':
        return Icons.visibility;
      case 'subir_documento':
        return Icons.upload;
      case 'editar_metadatos':
        return Icons.edit;
      case 'borrar_documento':
        return Icons.delete;
      case 'ver_movimientos':
        return Icons.swap_horiz_rounded;
      default:
        return Icons.security;
    }
  }
}
