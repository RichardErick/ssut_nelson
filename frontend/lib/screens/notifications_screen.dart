import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/user_role.dart';
import '../models/usuario.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/usuario_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_helper.dart';
import '../widgets/app_alert.dart';
import 'configurar_pregunta_secreta_screen.dart';
import 'admin/roles_permissions_screen.dart';

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
      // 1. Load Alerts (si el endpoint falla o no existe, usar lista vacía)
      List<dynamic> alertsList = [];
      try {
        final alertsResponse = await apiService.get('/alertas');
        if (alertsResponse.statusCode == 200 && alertsResponse.data != null) {
          final data = alertsResponse.data;
          alertsList = data is List ? data : [];
        }
      } catch (_) {
        alertsList = [];
      }

      // 2. Solo el Administrador de Sistema puede ver y gestionar solicitudes de registro
      List<Usuario> pending = [];
      if (authProvider.role == UserRole.administradorSistema) {
        final allUsers = await usuarioService.getAll(incluirInactivos: true);
        // Solo pendientes: inactivos que no fueron rechazados (rechazados no vuelven a aparecer)
        pending =
            allUsers.where((u) => !u.activo && !u.solicitudRechazada).toList();
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
      final usuarioService = Provider.of<UsuarioService>(
        context,
        listen: false,
      );
      await usuarioService.updateEstado(user.id, true);
      if (mounted) await _loadData();
      if (mounted) {
        AppAlert.success(
          context,
          'Usuario aprobado',
          '${user.nombreCompleto} ya puede iniciar sesión en el sistema.',
          buttonText: 'Entendido',
        );
      }
    } catch (e) {
      if (mounted) {
        AppAlert.error(
          context,
          'Error al aprobar',
          ErrorHelper.getErrorMessage(e),
          buttonText: 'Entendido',
        );
      }
    }
  }

  Future<void> _confirmarRechazo(Usuario user) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 380),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_off_rounded,
                      size: 48,
                      color: Colors.orange.shade700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Rechazar solicitud',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(ctx).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '¿Rechazar la solicitud de ${user.nombreCompleto}? Esta acción no se puede deshacer.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Rechazar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
    if (confirm == true && mounted) await _rechazarSolicitud(user);
  }

  Future<void> _rechazarSolicitud(Usuario user) async {
    try {
      final usuarioService = Provider.of<UsuarioService>(
        context,
        listen: false,
      );
      await usuarioService.rechazarSolicitudRegistro(user.id);
      if (!mounted) return;
      // Quitar al usuario y sus notificaciones de la lista al instante (sin recargar)
      final referencia = '(UsuarioId: ${user.id})';
      setState(() {
        _pendingUsers.removeWhere((u) => u.id == user.id);
        _alertas.removeWhere((a) {
          final titulo = a['titulo']?.toString() ?? '';
          final mensaje = a['mensaje']?.toString() ?? '';
          return titulo == 'Nuevo Registro de Usuario' &&
              mensaje.contains(referencia);
        });
      });
      // Refresco silencioso para actualizar el contador del badge en el menú
      _refreshSilently();
      if (mounted) {
        AppAlert.warning(
          context,
          'Solicitud rechazada',
          'El registro de ${user.nombreCompleto} ha sido denegado.',
          buttonText: 'Entendido',
        );
      }
    } catch (e) {
      if (mounted) {
        AppAlert.error(
          context,
          'Error al rechazar',
          ErrorHelper.getErrorMessage(e),
          buttonText: 'Entendido',
        );
      }
    }
  }

  /// Refresca alertas y pendientes sin mostrar pantalla de carga (para actualizar badge).
  Future<void> _refreshSilently() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final usuarioService = Provider.of<UsuarioService>(context, listen: false);
    try {
      List<dynamic> alertsList = [];
      try {
        final alertsResponse = await apiService.get('/alertas');
        if (alertsResponse.statusCode == 200 && alertsResponse.data != null) {
          final data = alertsResponse.data;
          alertsList = data is List ? data : [];
        }
      } catch (_) {}
      List<Usuario> pending = [];
      if (authProvider.role == UserRole.administradorSistema) {
        final allUsers = await usuarioService.getAll(incluirInactivos: true);
        pending =
            allUsers.where((u) => !u.activo && !u.solicitudRechazada).toList();
      }
      if (mounted) {
        setState(() {
          _alertas = alertsList;
          _pendingUsers = pending;
        });
      }
    } catch (_) {}
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
        title: Text(
          'Centro de Notificaciones',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body:
          _isLoading
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Cargando notificaciones...',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  children: [
                    if (_pendingUsers.isNotEmpty) ...[
                      _buildSectionHeader(
                        'SOLICITUDES DE REGISTRO',
                        '${_pendingUsers.length} pendiente${_pendingUsers.length == 1 ? '' : 's'}',
                        theme,
                        isPrimary: true,
                      ),
                      const SizedBox(height: 10),
                      ..._pendingUsers.map(
                        (user) => _buildPendingUserCard(user, theme),
                      ),
                      const SizedBox(height: 20),
                      Divider(
                        height: 1,
                        color: theme.colorScheme.outline.withOpacity(0.15),
                      ),
                      const SizedBox(height: 20),
                    ],
                    _buildSectionHeader(
                      'NOTIFICACIONES',
                      _alertas.isEmpty
                          ? ''
                          : '${_alertas.where((a) => a['leida'] == false).length} nuevas',
                      theme,
                      isPrimary: false,
                    ),
                    const SizedBox(height: 10),
                    if (_alertas.isEmpty) _buildEmptyState(theme),
                    ..._alertas.map((alerta) => _buildAlertCard(alerta, theme)),
                  ],
                ),
              ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    String subtitle,
    ThemeData theme, {
    bool isPrimary = false,
  }) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color:
                isPrimary
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
            letterSpacing: 1.0,
          ),
        ),
        const Spacer(),
        if (subtitle.isNotEmpty)
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
      ],
    );
  }

  Widget _buildPendingUserCard(Usuario user, ThemeData theme) {
    return Card(
      elevation: 1,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_add_rounded,
                    color: Colors.orange.shade700,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Solicitud de Nuevo Usuario',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: user.nombreCompleto,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            TextSpan(
                              text: ' (${user.nombreUsuario})',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        style: GoogleFonts.inter(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.email_outlined,
                            size: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              user.email,
                              style: GoogleFonts.inter(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat(
                              'dd/MM HH:mm',
                            ).format(user.fechaRegistro),
                            style: GoogleFonts.inter(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _confirmarRechazo(user),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    side: BorderSide(color: Colors.red.shade200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 36),
                  ),
                  child: const Text('Rechazar'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: () => _approveUser(user),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Aprobar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.colorExito,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 36),
                  ),
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

    switch (tipo) {
      case 'warning':
        iconColor = Colors.orange.shade700;
        icon = Icons.warning_amber_rounded;
        break;
      case 'error':
        iconColor = Colors.red.shade600;
        icon = Icons.error_rounded;
        break;
      case 'success':
        iconColor = Colors.green.shade600;
        icon = Icons.check_circle_rounded;
        break;
      default:
        iconColor = theme.colorScheme.primary;
        icon = Icons.info_rounded;
    }

    return Dismissible(
      key: Key(alerta['id'].toString()),
      background: Container(
        color: Colors.red.shade500,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 22),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteAlert(alerta['id']),
      child: Card(
        color:
            leida
                ? theme.colorScheme.surface
                : theme.colorScheme.primary.withOpacity(0.04),
        elevation: leida ? 0 : 1,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side:
              leida
                  ? BorderSide.none
                  : BorderSide(
                    color: theme.colorScheme.primary.withOpacity(0.15),
                  ),
        ),
        child: ListTile(
          onTap: () {
            _markAsRead(alerta['id']);
            final titulo = alerta['titulo']?.toString() ?? '';
            if (titulo == 'Pregunta secreta pendiente') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ConfigurarPreguntaSecretaScreen(),
                ),
              ).then((configurado) {
                if (configurado == true && mounted) _loadData();
              });
            } else if (titulo.startsWith('Solicitud: recuperación de contraseña')) {
              // Intentar extraer (UsuarioId: X) del mensaje para ir directo a la gestión de ese usuario
              final mensaje = alerta['mensaje']?.toString() ?? '';
              final userId = _extraerUsuarioIdDesdeMensaje(mensaje);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RolesPermissionsScreen(
                    initialUserId: userId,
                  ),
                ),
              );
            }
          },
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 6,
          ),
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          title: Text(
            alerta['titulo'] ?? 'Notificación',
            style: GoogleFonts.inter(
              fontWeight: leida ? FontWeight.w500 : FontWeight.w600,
              fontSize: 13,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alerta['mensaje'] ?? '',
                  style: GoogleFonts.inter(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd MMM HH:mm').format(fecha),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          trailing:
              !leida
                  ? Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  )
                  : null,
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_off_outlined,
              size: 44,
              color: theme.colorScheme.outline.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No tienes notificaciones',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Las alertas y avisos aparecerán aquí.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  /// Extrae el UsuarioId del mensaje de la alerta cuando viene en el formato "(UsuarioId: 30)".
  int? _extraerUsuarioIdDesdeMensaje(String mensaje) {
    final pattern = RegExp(r'\(UsuarioId:\s*(\d+)\)');
    final match = pattern.firstMatch(mensaje);
    if (match != null) {
      final idStr = match.group(1);
      if (idStr != null) {
        return int.tryParse(idStr);
      }
    }
    return null;
  }
}
