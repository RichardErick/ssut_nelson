import 'package:flutter/material.dart';
import '../../models/area.dart';
import '../../models/usuario.dart';
import '../../services/usuario_service.dart';

// Helper methods
String _getRolDisplayName(String rol) {
  switch (rol) {
    case 'AdministradorSistema':
    case 'Administrador': return 'Administrador del Sistema';
    case 'AdministradorDocumentos': return 'Administrador de Documentos';
    case 'Contador': return 'Contador';
    case 'Gerente': return 'Gerente';
    default: return rol;
  }
}

IconData _getRolIcon(String rol) {
    switch (rol) {
      case 'AdministradorSistema':
      case 'Administrador': return Icons.security;
      case 'AdministradorDocumentos': return Icons.folder_shared;
      case 'Contador': return Icons.calculate;
      case 'Gerente': return Icons.business;
      default: return Icons.person_outline;
    }
}

Color _getRolColor(String rol) {
    switch (rol) {
      case 'AdministradorSistema':
      case 'Administrador': return Colors.deepPurple;
      case 'AdministradorDocumentos': return Colors.orange;
      case 'Contador': return Colors.blue;
      case 'Gerente': return Colors.green;
      default: return Colors.grey;
    }
}

class CreateUserDialog extends StatefulWidget {
  final List<String> roles;
  final List<Area> areas;

  const CreateUserDialog({
    super.key,
    required this.roles,
    required this.areas,
  });

  @override
  State<CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<CreateUserDialog> {
  final _usuarioController = TextEditingController();
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  late String _selectedRol;
  int? _selectedAreaId;
  bool _activo = true;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Default rol: Gerente si existe, sino el primer rol
    _selectedRol = widget.roles.contains('Gerente') ? 'Gerente' : widget.roles.first;
  }

  @override
  void dispose() {
    _usuarioController.dispose();
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Nuevo usuario'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _usuarioController,
                decoration: const InputDecoration(
                  labelText: 'Usuario',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedRol,
                decoration: const InputDecoration(
                  labelText: 'Rol',
                  prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                ),
                items: widget.roles.map((r) => DropdownMenuItem(
                  value: r,
                  child: Text(_getRolDisplayName(r)),
                )).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedRol = v);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                value: _selectedAreaId,
                decoration: const InputDecoration(
                  labelText: 'Área (opcional)',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Sin área')),
                  ...widget.areas.map((a) => DropdownMenuItem<int?>(
                    value: a.id,
                    child: Text(a.nombre),
                  )),
                ],
                onChanged: (v) => setState(() => _selectedAreaId = v),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _activo,
                onChanged: (v) => setState(() => _activo = v),
                title: const Text('Activo'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final nombreUsuario = _usuarioController.text.trim();
            final nombreCompleto = _nombreController.text.trim();
            final email = _emailController.text.trim();
            final password = _passwordController.text.trim();

            if (nombreUsuario.isEmpty || nombreCompleto.isEmpty || email.isEmpty || password.isEmpty) {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('Todos los campos son obligatorios')),
               );
               return;
            }

            final dto = CreateUsuarioDTO(
              nombreUsuario: nombreUsuario,
              nombreCompleto: nombreCompleto,
              email: email,
              password: password,
              rol: _selectedRol,
              areaId: _selectedAreaId,
              activo: _activo,
            );
            Navigator.pop(context, dto);
          },
          child: const Text('Crear'),
        ),
      ],
    );
  }
}

class EditUserDialog extends StatefulWidget {
  final Usuario usuario;
  final List<String> roles;
  final List<Area> areas;

  const EditUserDialog({
    super.key,
    required this.usuario,
    required this.roles,
    required this.areas,
  });

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  late TextEditingController _nombreController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  
  late String _selectedRol;
  int? _selectedAreaId;
  late bool _activo;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.usuario.nombreCompleto);
    _emailController = TextEditingController(text: widget.usuario.email);
    _passwordController = TextEditingController();
    
    // Map backend rol to frontend rol if needed
    final rawRol = widget.usuario.rol;
    _selectedRol = rawRol == 'Administrador' ? 'AdministradorSistema' : rawRol;
    if (!widget.roles.contains(_selectedRol)) {
        _selectedRol = widget.roles.first; 
    }
    
    _selectedAreaId = widget.usuario.areaId;
    _activo = widget.usuario.activo;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
            CircleAvatar(
                backgroundColor: _getRolColor(widget.usuario.rol).withOpacity(0.2),
                child: Icon(_getRolIcon(widget.usuario.rol), color: _getRolColor(widget.usuario.rol)),
            ),
            const SizedBox(width: 12),
            const Expanded(
                child: Text('Editar usuario', style: TextStyle(fontSize: 18)),
            ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Usuario: ${widget.usuario.nombreUsuario}',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedRol,
                decoration: const InputDecoration(
                  labelText: 'Rol',
                  prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                ),
                items: widget.roles.map((r) => DropdownMenuItem(
                  value: r,
                  child: Text(_getRolDisplayName(r)),
                )).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedRol = v);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                value: _selectedAreaId,
                decoration: const InputDecoration(
                  labelText: 'Área (opcional)',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Sin área')),
                  ...widget.areas.map((a) => DropdownMenuItem<int?>(
                    value: a.id,
                    child: Text(a.nombre),
                  )),
                ],
                onChanged: (v) => setState(() => _selectedAreaId = v),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _activo,
                onChanged: (v) => setState(() => _activo = v),
                title: const Text('Activo'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Nueva contraseña (dejar vacío para no cambiar)',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final nombreCompleto = _nombreController.text.trim();
            final email = _emailController.text.trim();
            final password = _passwordController.text.trim();

            if (nombreCompleto.isEmpty || email.isEmpty) {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('Nombre completo y email son obligatorios')),
               );
               return;
            }

            final dto = UpdateUsuarioDTO(
              nombreCompleto: nombreCompleto,
              email: email,
              rol: _selectedRol,
              areaId: _selectedAreaId,
              activo: _activo,
              password: password.isEmpty ? null : password,
            );
            Navigator.pop(context, dto);
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
