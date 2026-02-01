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
  
  // Permisos disponibles según la matriz SIMPLIFICADA
  final Map<String, String> _permisosDisponibles = {
    'ver_documento': 'Ver Documento',
    'subir_documento': 'Subir Documento',
    'editar_documento': 'Editar Documento',
    'borrar_documento': 'Borrar Documento',
  };

  // Permisos por rol según la matriz SIMPLIFICADA
  final Map<UserRole, List<String>> _permisosPorRol = {
    UserRole.administradorSistema: ['ver_documento'],
    UserRole.administradorDocumentos: [
      'ver_documento',
      'subir_documento',
      'editar_documento',
      'borrar_documento'
    ],
    UserRole.contador: [
      'ver_documento',
      'subir_documento'
    ],
    UserRole.gerente: ['ver_documento'],
  };

  // State
  final Map<String, Map<String, bool>> _permisosActivos = {};

  Usuario? _usuarioSeleccionado;
  bool _isLoading = true;
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
      _usuariosFiltrados = _usuarios.where((usuario) {
        return usuario.nombreCompleto.toLowerCase().contains(query) ||
               usuario.nombreUsuario.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final usuarioService = Provider.of<UsuarioService>(context, listen: false);
      final permisoService = Provider.of<PermisoService>(context, listen: false);
      
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
            content: Text('Error cargando usuarios: ${ErrorHelper.getErrorMessage(e)}'),
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
    
    // Inicializar permisos activos si no existen
    if (!_permisosActivos.containsKey(usuario.nombreUsuario)) {
      _permisosActivos[usuario.nombreUsuario] = {};
      
      // Inicializar todos los permisos del rol como ACTIVOS por defecto
      final role = _parseRoleWithContext(usuario.rol, usuario.nombreUsuario, usuario.nombreCompleto);
      print('DEBUG: Rol parseado: $role');
      final permisosRol = _permisosPorRol[role] ?? [];
      print('DEBUG: Permisos del rol: $permisosRol');
      
      for (final permiso in permisosRol) {
        _permisosActivos[usuario.nombreUsuario]![permiso] = true; // ACTIVO por defecto
        print('DEBUG: Activando permiso: $permiso');
      }
    }
  }

  UserRole _parseRoleWithContext(String roleName, String nombreUsuario, String nombreCompleto) {
    print('DEBUG PERMISOS: Parseando rol: "$roleName" para usuario: "$nombreUsuario" ($nombreCompleto)');
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
          print('DEBUG PERMISOS: Rol "Administrador" mapeado a AdministradorDocumentos por contexto (documentos)');
          return UserRole.administradorDocumentos;
        }
        // Si el nombre completo contiene "sistema" o el username es "admin", es admin de sistema
        else if (fullNameLower.contains('sistema') || 
                 usernameLower == 'admin') {
          print('DEBUG PERMISOS: Rol "Administrador" mapeado a AdministradorSistema por contexto (sistema)');
          return UserRole.administradorSistema;
        } else {
          // Por defecto, si no hay contexto claro, asignar AdministradorDocumentos
          print('DEBUG PERMISOS: Rol "Administrador" mapeado a AdministradorDocumentos por defecto');
          return UserRole.administradorDocumentos;
        }
      case 'contador':
        print('DEBUG PERMISOS: Mapeado a Contador');
        return UserRole.contador;
      case 'gerente':
        print('DEBUG PERMISOS: Mapeado a Gerente');
        return UserRole.gerente;
      default:
        print('DEBUG PERMISOS: Rol no reconocido: "$roleName", asignando AdministradorDocumentos por defecto');
        return UserRole.administradorDocumentos;
    }
  }

  UserRole _parseRole(String roleName) {
    // Función de compatibilidad que llama a la nueva función con contexto vacío
    return _parseRoleWithContext(roleName, '', '');
  }

  void _togglePermiso(String permiso) {
    if (_usuarioSeleccionado == null) return;
    
    setState(() {
      final username = _usuarioSeleccionado!.nombreUsuario;
      _permisosActivos[username]![permiso] = 
          !(_permisosActivos[username]![permiso] ?? false);
    });
  }

  Future<void> _guardarCambios() async {
    if (_usuarioSeleccionado == null) return;
    
    setState(() => _isSaving = true);
    
    try {
      final permisoService = Provider.of<PermisoService>(context, listen: false);
      final usuario = _usuarioSeleccionado!;
      final permisosActivos = _permisosActivos[usuario.nombreUsuario] ?? {};
      
      // Obtener los permisos del rol base para comparar
      final permisosRol = _obtenerPermisosRol(usuario);
      
      int cambios = 0;
      for (final codigo in _permisosDisponibles.keys) {
        final activo = permisosActivos[codigo] ?? false;
        final rolTienePermiso = permisosRol.contains(codigo);
        
        // Buscar el ID del permiso en el catálogo
        final permiso = _permisosDisponiblesLista.firstWhere(
          (p) => p.codigo == codigo,
          orElse: () => Permiso(id: 0, codigo: codigo, nombre: '', descripcion: '', modulo: '', activo: true),
        );
        
        if (permiso.id == 0) {
          print('WARN: No se encontró ID para permiso $codigo');
          continue;
        }
        
        // Si el usuario debe tenerlo activo pero el rol NO lo tiene, asignar
        if (activo && !rolTienePermiso) {
          await permisoService.asignarPermiso(usuario.id, permiso.id);
          cambios++;
        }
        // Si el usuario NO debe tenerlo activo pero el rol SÍ lo tiene, revocar (denegar)
        else if (!activo && rolTienePermiso) {
          await permisoService.revocarPermiso(usuario.id, permiso.id);
          cambios++;
        }
        // Si ambos están de acuerdo con el rol, no hacer nada
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Permisos actualizados ($cambios cambios aplicados)'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error guardando permisos: ${ErrorHelper.getErrorMessage(e)}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
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
      body: _isLoading
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
    final role = _parseRole(usuario.rol);
    final permisosRol = _permisosPorRol[role] ?? [];
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    'Activa o desactiva los permisos asignados al rol de este usuario',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Mostrar solo los permisos que tiene el rol
                  if (permisosRol.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Este rol no tiene permisos de documentos asignados',
                              style: GoogleFonts.inter(
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: permisosRol.length,
                        itemBuilder: (context, index) {
                          final permiso = permisosRol[index];
                          final nombre = _permisosDisponibles[permiso] ?? permiso;
                          final estaActivo = permisosUsuario[permiso] ?? true;
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: estaActivo 
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
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                estaActivo 
                                    ? 'Permiso ACTIVO' 
                                    : 'Permiso DESACTIVADO',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: estaActivo ? Colors.green.shade600 : Colors.red.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: Switch(
                                value: estaActivo,
                                onChanged: (value) => _togglePermiso(permiso),
                                activeColor: Colors.green,
                                inactiveThumbColor: Colors.red.shade300,
                                inactiveTrackColor: Colors.red.shade100,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  
                  if (permisosRol.isNotEmpty) ...[
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
                        child: _isSaving
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
      case 'editar_documento':
        return Icons.edit;
      case 'borrar_documento':
        return Icons.delete;
      default:
        return Icons.security;
    }
  }
}