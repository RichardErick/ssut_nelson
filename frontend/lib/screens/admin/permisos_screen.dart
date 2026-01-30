import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/user_role.dart';
import '../../models/usuario.dart';
import '../../providers/auth_provider.dart';
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
  
  // Permisos disponibles según la matriz
  final Map<String, String> _permisosDisponibles = {
    'ver_documento': 'Ver Documento',
    'crear_documento': 'Crear Documento',
    'subir_documento': 'Subir Documento',
    'editar_metadatos': 'Editar Metadatos',
    'borrar_documento': 'Borrar Documento',
  };

  // Permisos por rol según la matriz definida
  final Map<UserRole, List<String>> _permisosPorRol = {
    UserRole.administradorSistema: ['ver_documento'],
    UserRole.administradorDocumentos: [
      'ver_documento',
      'crear_documento',
      'subir_documento',
      'editar_metadatos',
      'borrar_documento'
    ],
    UserRole.contador: [
      'ver_documento',
      'crear_documento',
      'subir_documento'
    ],
    UserRole.gerente: ['ver_documento'],
  };

  // State
  final Map<String, Map<String, bool>> _permisosPersonalizados = {};

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
      final usuarios = await usuarioService.getAll();
      
      if (mounted) {
        setState(() {
          _usuarios = usuarios.where((u) => u.activo).toList();
          _usuariosFiltrados = List.from(_usuarios);
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
    setState(() {
      _usuarioSeleccionado = usuario;
    });
    
    // Inicializar permisos personalizados si no existen
    if (!_permisosPersonalizados.containsKey(usuario.nombreUsuario)) {
      _permisosPersonalizados[usuario.nombreUsuario] = {};
      
      // Inicializar con permisos por defecto del rol
      final role = _parseRole(usuario.rol);
      final permisosRol = _permisosPorRol[role] ?? [];
      
      for (final permiso in _permisosDisponibles.keys) {
        _permisosPersonalizados[usuario.nombreUsuario]![permiso] = 
            permisosRol.contains(permiso);
      }
    }
  }

  UserRole _parseRole(String roleName) {
    switch (roleName) {
      case 'AdministradorSistema':
      case 'Administrador':
        return UserRole.administradorSistema;
      case 'AdministradorDocumentos':
        return UserRole.administradorDocumentos;
      case 'Contador':
        return UserRole.contador;
      case 'Gerente':
        return UserRole.gerente;
      default:
        return UserRole.administradorSistema;
    }
  }

  void _togglePermiso(String permiso) {
    if (_usuarioSeleccionado == null) return;
    
    setState(() {
      final username = _usuarioSeleccionado!.nombreUsuario;
      _permisosPersonalizados[username]![permiso] = 
          !(_permisosPersonalizados[username]![permiso] ?? false);
    });
  }

  Future<void> _guardarCambios() async {
    if (_usuarioSeleccionado == null) return;
    
    setState(() => _isSaving = true);
    
    try {
      // Aquí iría la lógica para guardar en el backend
      // Por ahora solo mostramos un mensaje de éxito
      
      await Future.delayed(const Duration(seconds: 1)); // Simular llamada API
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permisos actualizados correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error guardando permisos: ${ErrorHelper.getErrorMessage(e)}'),
            backgroundColor: Colors.red,
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
        body: const Center(
          child: Text(
            'No tienes permisos para acceder a esta sección',
            style: TextStyle(fontSize: 16),
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
          : Row(
              children: [
                // Panel izquierdo - Lista de usuarios
                Expanded(
                  flex: 1,
                  child: _buildUsuariosList(),
                ),
                const VerticalDivider(width: 1),
                // Panel derecho - Permisos del usuario seleccionado
                Expanded(
                  flex: 2,
                  child: _buildPermisosPanel(),
                ),
              ],
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
    final permisosUsuario = _permisosPersonalizados[usuario.nombreUsuario] ?? {};

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
                    'Permisos de Documentos',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Personaliza los permisos específicos para este usuario',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Expanded(
                    child: ListView.builder(
                      itemCount: _permisosDisponibles.length,
                      itemBuilder: (context, index) {
                        final permiso = _permisosDisponibles.keys.elementAt(index);
                        final nombre = _permisosDisponibles[permiso]!;
                        final tienePermisoRol = permisosRol.contains(permiso);
                        final tienePermisoUsuario = permisosUsuario[permiso] ?? tienePermisoRol;
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: tienePermisoUsuario 
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getPermisoIcon(permiso),
                                color: tienePermisoUsuario ? Colors.green : Colors.grey,
                              ),
                            ),
                            title: Text(
                              nombre,
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              tienePermisoRol 
                                  ? 'Incluido por rol' 
                                  : 'Permiso personalizado',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            trailing: Switch(
                              value: tienePermisoUsuario,
                              onChanged: (value) => _togglePermiso(permiso),
                              activeColor: Colors.green,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
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
      case 'crear_documento':
        return Icons.add_circle;
      case 'subir_documento':
        return Icons.upload;
      case 'editar_metadatos':
        return Icons.edit;
      case 'borrar_documento':
        return Icons.delete;
      default:
        return Icons.security;
    }
  }
}