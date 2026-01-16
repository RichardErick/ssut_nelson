import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/user_role.dart';
import '../models/usuario.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/usuario_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_helper.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  List<dynamic> _alertas = [];
  List<Usuario> _pendingUsers = [];
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final usuarioService = Provider.of<UsuarioService>(context, listen: false);
    
    try {
      // 1. Load Alerts
      final alertsResponse = await apiService.get('/alertas');
      final alertsList = alertsResponse.data as List;
      
      // 2. If Admin, load pending users
      List<Usuario> pending = [];
      if (authProvider.role == UserRole.administradorSistema || 
          authProvider.role == UserRole.administradorDocumentos) {
          
          final allUsers = await usuarioService.getAll();
          pending = allUsers.where((u) => !u.activo).toList();
      }
      
      if (mounted) {
        setState(() {
          _alertas = alertsList;
          _pendingUsers = pending;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Silent error or snackbar
        print('Error loading notifications: $e');
      }
    }
  }

  Future<void> _approveUser(Usuario user) async {
    try {
      final usuarioService = Provider.of<UsuarioService>(context, listen: false);
      await usuarioService.updateEstado(user.id, true);
      
      // Refresh
      _loadData(); // Reloads both alerts and users
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuario aprobado y activado correctamente'),
            backgroundColor: AppTheme.colorExito,
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error: ${ErrorHelper.getErrorMessage(e)}'), backgroundColor: Colors.red)
        );
      }
    }
  }

  Future<void> _deleteUser(Usuario user) async {
     // Implement reject logic (maybe delete user or keep inactive)
     // For now, let's assume reject = delete for pending registrations
     try {
       final apiService = Provider.of<ApiService>(context, listen: false);
       await apiService.delete('/usuarios/${user.id}?hard=true');
       
       _loadData();
       
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Solicitud rechazada y usuario eliminado'))
         );
       }
     } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error: ${ErrorHelper.getErrorMessage(e)}'), backgroundColor: Colors.red)
        );
      }
     }
  }

  Future<void> _markAsRead(int id) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.put('/alertas/$id/leida', data: {});
      setState(() {
        final index = _alertas.indexWhere((a) => a['id'] == id);
        if (index != -1) {
          _alertas[index]['leida'] = true;
        }
      });
    } catch (_) {}
  }
  
  Future<void> _deleteAlert(int id) async {
     try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.delete('/alertas/$id');
      setState(() {
        _alertas.removeWhere((a) => a['id'] == id);
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
       appBar: AppBar(
        title: Text('Centro de Notificaciones', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadData,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. Pending Approvals Section
                if (_pendingUsers.isNotEmpty) ...[
                  Text(
                    'SOLICITUDES DE REGISTRO',
                    style: GoogleFonts.inter(
                      fontSize: 12, 
                      fontWeight: FontWeight.bold, 
                      color: theme.colorScheme.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._pendingUsers.map((user) => _buildPendingUserCard(user, theme)).toList(),
                  const SizedBox(height: 24),
                  Divider(color: theme.colorScheme.outline.withOpacity(0.1)),
                  const SizedBox(height: 24),
                ],
                
                // 2. General Alerts
                Row(
                  children: [
                    Text(
                      'NOTIFICACIONES',
                      style: GoogleFonts.inter(
                        fontSize: 12, 
                        fontWeight: FontWeight.bold, 
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    if (_alertas.isNotEmpty)
                      Text(
                        '${_alertas.where((a) => a['leida'] == false).length} nuevas',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_alertas.isEmpty) 
                   _buildEmptyState(theme, 'No tienes notificaciones'),
                ..._alertas.map((alerta) => _buildAlertCard(alerta, theme)).toList(),
              ],
            ),
        ),
    );
  }
  
  Widget _buildPendingUserCard(Usuario user, ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_add, color: Colors.orange),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Solicitud de Nuevo Usuario',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'El usuario '),
                            TextSpan(text: user.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.bold)),
                            TextSpan(text: ' (${user.nombreUsuario}) ha solicitado acceso.'),
                          ]
                        ),
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Row(
                         children: [
                           Icon(Icons.email_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                           const SizedBox(width: 4),
                           Text(user.email, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                           const SizedBox(width: 16),
                           Icon(Icons.calendar_today_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                           const SizedBox(width: 4),
                           Text(
                             DateFormat('dd/MM/yyyy HH:mm').format(user.fechaRegistro),
                             style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)
                           ),
                         ],
                      )
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _deleteUser(user),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red.withOpacity(0.5)),
                  ),
                  child: const Text('Rechazar'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () => _approveUser(user),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Aprobar Acceso'),
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.colorExito),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alerta, ThemeData theme) {
    final bool leida = alerta['leida'] ?? false;
    final String tipo = alerta['tipoAlerta'] ?? 'info';
    final DateTime fecha = DateTime.parse(alerta['fechaCreacion']).toLocal();
    
    Color iconColor;
    IconData icon;
    
    switch(tipo) {
      case 'warning':
        iconColor = Colors.orange;
        icon = Icons.warning_amber_rounded;
        break;
      case 'error':
        iconColor = Colors.red;
        icon = Icons.error_outline;
        break;
      case 'success':
        iconColor = Colors.green;
        icon = Icons.check_circle_outline;
        break;
      default:
        iconColor = theme.colorScheme.primary;
        icon = Icons.info_outline;
    }
    
    return Dismissible(
      key: Key(alerta['id'].toString()),
      background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) => _deleteAlert(alerta['id']),
      child: Card(
        color: leida ? theme.colorScheme.surface : theme.colorScheme.primary.withOpacity(0.05),
        elevation: leida ? 0 : 2,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
           borderRadius: BorderRadius.circular(12),
           side: leida ? BorderSide.none : BorderSide(color: theme.colorScheme.primary.withOpacity(0.2)),
        ),
        child: ListTile(
          onTap: () => _markAsRead(alerta['id']),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          title: Text(
            alerta['titulo'] ?? 'Notificacion',
            style: TextStyle(
              fontWeight: leida ? FontWeight.normal : FontWeight.bold,
              fontSize: 14,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                alerta['mensaje'] ?? '',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                DateFormat('dd MMM HH:mm').format(fecha),
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
          trailing: !leida 
            ? Container(width: 8, height: 8, decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle)) 
            : null,
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(Icons.notifications_off_outlined, size: 48, color: theme.colorScheme.outline.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(message, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
