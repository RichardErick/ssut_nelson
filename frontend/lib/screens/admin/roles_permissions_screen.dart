import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/user_role.dart';
import '../../models/usuario.dart';
import '../../providers/auth_provider.dart';
import '../../services/usuario_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_helper.dart';

class RolesPermissionsScreen extends StatefulWidget {
  const RolesPermissionsScreen({super.key});

  @override
  State<RolesPermissionsScreen> createState() => _RolesPermissionsScreenState();
}

class _RolesPermissionsScreenState extends State<RolesPermissionsScreen> {
  List<Usuario> _usuarios = [];
  List<Usuario> _usuariosFiltrados = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  // Roles disponibles
  final List<String> _roles = [
    'AdministradorSistema',
    'AdministradorDocumentos', 
    'Contador',
    'Gerente',
  ];

  // Permisos por rol según la matriz definida
  final Map<String, List<String>> _permisosPorRol = {
    'AdministradorSistema': ['Ver Documento'],
    'AdministradorDocumentos': [
      'Ver Documento',
      'Crear Documento', 
      'Subir Documento',
      'Editar Metadatos',
      'Borrar Documento',
      'Crear Carpeta',
      'Borrar Carpeta'
    ],
    'Contador': [
      'Ver Documento',
      'Crear Documento',
      'Subir Documento'
    ],
    'Gerente': ['Ver Documento'],
  };

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

  Future<void> _cambiarRol(Usuario usuario, String nuevoRol) async {
    try {
      final usuarioService = Provider.of<UsuarioService>(context, listen: false);
      await usuarioService.updateRol(usuario.id, nuevoRol);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rol actualizado a ${_getRolDisplayName(nuevoRol)}'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar rol: ${ErrorHelper.getErrorMessage(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _mostrarDialogoRol(Usuario usuario) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: _getRolColor(usuario.rol).withOpacity(0.2),
              child: Icon(_getRolIcon(usuario.rol), color: _getRolColor(usuario.rol)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(usuario.nombreCompleto, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Cambiar rol', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _roles.map((rol) {
            final isSelected = usuario.rol == rol;
            return InkWell(
              onTap: () {
                if (!isSelected) {
                  Navigator.pop(context);
                  _cambiarRol(usuario, rol);
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? _getRolColor(rol).withOpacity(0.1) : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? _getRolColor(rol) : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(_getRolIcon(rol), color: _getRolColor(rol), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _getRolDisplayName(rol),
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? _getRolColor(rol) : null,
                        ),
                      ),
                    ),
                    if (isSelected) Icon(Icons.check_circle, color: _getRolColor(rol), size: 20),
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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

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
              const Text('No tienes permisos para acceder a esta sección', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              Text('Rol actual: ${authProvider.role.displayName}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Gestión de Roles y Permisos', style: GoogleFonts.poppins()),
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
          : Column(
              children: [
                // Header con estadísticas
                Container(
                  padding: const EdgeInsets.all(24),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Resumen del Sistema',
                        style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      _buildEstadisticas(),
                      const SizedBox(height: 16),
                      // Buscador
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar usuario...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                // Lista de usuarios
                Expanded(
                  child: _usuariosFiltrados.isEmpty
                      ? const Center(
                          child: Text('No se encontraron usuarios', style: TextStyle(fontSize: 16, color: Colors.grey)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _usuariosFiltrados.length,
                          itemBuilder: (context, index) {
                            final usuario = _usuariosFiltrados[index];
                            return _buildUsuarioCard(usuario);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEstadisticas() {
    final stats = <String, int>{};
    for (final rol in _roles) {
      stats[rol] = _usuarios.where((u) => u.rol == rol).length;
    }

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: stats.entries.map((entry) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _getRolColor(entry.key).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _getRolColor(entry.key).withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getRolIcon(entry.key), color: _getRolColor(entry.key), size: 16),
              const SizedBox(width: 8),
              Text(
                '${_getRolDisplayName(entry.key)}: ${entry.value}',
                style: TextStyle(
                  color: _getRolColor(entry.key),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUsuarioCard(Usuario usuario) {
    final permisos = _permisosPorRol[usuario.rol] ?? [];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header del usuario
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: _getRolColor(usuario.rol),
                  child: Text(
                    usuario.nombreCompleto.isNotEmpty ? usuario.nombreCompleto[0].toUpperCase() : 'U',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        usuario.nombreCompleto,
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '@${usuario.nombreUsuario}',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                // Botón cambiar rol
                ElevatedButton.icon(
                  onPressed: () => _mostrarDialogoRol(usuario),
                  icon: Icon(_getRolIcon(usuario.rol), size: 16),
                  label: Text(_getRolDisplayName(usuario.rol)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getRolColor(usuario.rol).withOpacity(0.1),
                    foregroundColor: _getRolColor(usuario.rol),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Permisos del rol
            Text(
              'Permisos del Rol:',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: permisos.map((permiso) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Text(
                    permiso,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _getRolDisplayName(String rol) {
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

  IconData _getRolIcon(String rol) {
    switch (rol) {
      case 'AdministradorSistema':
        return Icons.security;
      case 'AdministradorDocumentos':
        return Icons.folder_shared;
      case 'Contador':
        return Icons.account_balance;
      case 'Gerente':
        return Icons.business_center;
      default:
        return Icons.person;
    }
  }

  Color _getRolColor(String rol) {
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
}