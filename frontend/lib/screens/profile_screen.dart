import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/usuario.dart';
import '../services/usuario_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Usuario? _usuario;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  Future<void> _cargarPerfil() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final usuarioService = Provider.of<UsuarioService>(context, listen: false);
      final usuario = await usuarioService.getCurrent(context);
      if (mounted) {
        setState(() {
          _usuario = usuario;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo cargar el perfil: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Mi perfil', style: GoogleFonts.poppins()),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError(theme)
              : _usuario == null
                  ? _buildEmpty(theme)
                  : RefreshIndicator(
                      onRefresh: _cargarPerfil,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        child: _buildContent(theme, _usuario!),
                      ),
                    ),
    );
  }

  Widget _buildContent(ThemeData theme, Usuario usuario) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final initials =
        (usuario.nombreCompleto.isNotEmpty ? usuario.nombreCompleto : usuario.nombreUsuario)
            .trim()
            .split(' ')
            .where((p) => p.isNotEmpty)
            .take(2)
            .map((p) => p[0].toUpperCase())
            .join();

    final areaLabel = usuario.areaNombre ??
        (usuario.areaId != null ? 'Area #${usuario.areaId}' : 'Sin area');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: theme.colorScheme.primary,
                child: Text(
                  initials.isEmpty ? 'U' : initials,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      usuario.nombreCompleto,
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      usuario.rol,
                      style: GoogleFonts.inter(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('Datos de cuenta'),
        const SizedBox(height: 8),
        _buildInfoRow(theme, Icons.badge_outlined, 'ID', usuario.id.toString()),
        _buildInfoRow(theme, Icons.person_outline, 'Usuario', usuario.nombreUsuario),
        _buildInfoRow(theme, Icons.account_circle_outlined, 'Nombre completo', usuario.nombreCompleto),
        _buildInfoRow(theme, Icons.email_outlined, 'Correo', usuario.email),
        _buildInfoRow(theme, Icons.work_outline, 'Rol', usuario.rol),
        _buildInfoRow(theme, Icons.apartment_outlined, 'Area', areaLabel),
        _buildInfoRow(theme, Icons.verified_user_outlined, 'Activo', usuario.activo ? 'Si' : 'No'),
        const SizedBox(height: 16),
        _buildSectionTitle('Seguridad'),
        const SizedBox(height: 8),
        _buildInfoRow(
          theme,
          Icons.error_outline,
          'Intentos fallidos',
          usuario.intentosFallidos.toString(),
        ),
        _buildInfoRow(
          theme,
          Icons.lock_clock_outlined,
          'Bloqueado hasta',
          _formatDate(dateFormat, usuario.bloqueadoHasta),
        ),
        const SizedBox(height: 16),
        _buildSectionTitle('Actividad'),
        const SizedBox(height: 8),
        _buildInfoRow(
          theme,
          Icons.access_time,
          'Ultimo acceso',
          _formatDate(dateFormat, usuario.ultimoAcceso),
        ),
        _buildInfoRow(
          theme,
          Icons.calendar_today_outlined,
          'Fecha registro',
          _formatDate(dateFormat, usuario.fechaRegistro),
        ),
        _buildInfoRow(
          theme,
          Icons.update_outlined,
          'Fecha actualizacion',
          _formatDate(dateFormat, usuario.fechaActualizacion),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildInfoRow(ThemeData theme, IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '-' : value,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateFormat formatter, DateTime? value) {
    if (value == null) return '-';
    return formatter.format(value);
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 60, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(_error ?? 'Error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _cargarPerfil,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_outlined, size: 60, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            const Text('No se encontraron datos del usuario.'),
          ],
        ),
      ),
    );
  }
}
