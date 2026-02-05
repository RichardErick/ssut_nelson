import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/sync_service.dart';
import '../../models/sync_log.dart';

class UsersSyncScreen extends StatefulWidget {
  const UsersSyncScreen({super.key});

  @override
  State<UsersSyncScreen> createState() => _UsersSyncScreenState();
}

class _UsersSyncScreenState extends State<UsersSyncScreen> {
  bool _isSyncing = false;

  Future<void> _startSync() async {
    setState(() => _isSyncing = true);
    final syncService = Provider.of<SyncService>(context, listen: false);

    try {
      await syncService.sincronizarUsuarios();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sincronización completada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error en la sincronización: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncService = Provider.of<SyncService>(context);
    final history = syncService.history;
    
    // Logic for filtering
    final filteredHistory = _filterStatus == 'Todos' 
        ? history 
        : history.where((element) {
            if (_filterStatus == 'Correcto') return element.estado == SyncStatus.exitoso;
            if (_filterStatus == 'Fallido') return element.estado != SyncStatus.exitoso;
            return true;
          }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          _buildSyncCard(context),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Historial de Sincronizaciones',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              _buildFilters(),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: filteredHistory.isEmpty
                ? const Center(child: Text('No hay registros para el filtro seleccionado.'))
                : ListView.builder(
                    itemCount: filteredHistory.length,
                    itemBuilder: (context, index) {
                      final log = filteredHistory[index];
                      return _buildHistoryItem(log);
                    },
                  ),
          ),
        ],
      ),
    );
  }
  
  String _filterStatus = 'Todos'; // State variable for filter

  Widget _buildFilters() {
    return Row(
      children: [
        _buildFilterChip('Todos'),
        const SizedBox(width: 8),
        _buildFilterChip('Correcto', color: Colors.green),
        const SizedBox(width: 8),
        _buildFilterChip('Fallido', color: Colors.red),
      ],
    );
  }

  Widget _buildFilterChip(String label, {Color? color}) {
    final isSelected = _filterStatus == label;
    return FilterChip(
      label: Text(
        label, 
        style: TextStyle(
          color: isSelected ? Colors.white : (color ?? Colors.black87),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) {
           setState(() => _filterStatus = label);
        }
      },
      backgroundColor: Colors.white,
      selectedColor: color ?? Colors.blue.shade600,
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sincronización de Usuarios',
          style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Sincronización: actualiza usuarios, roles y permisos desde la base de datos institucional. Use el botón "Sincronizar" para ejecutar la importación o actualización de perfiles.',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildSyncCard(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.cloud_sync_rounded, size: 40, color: Colors.blue.shade700),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sincronización Manual',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Actualiza usuarios, roles y permisos ahora.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _isSyncing ? null : _startSync,
              icon: _isSyncing 
                  ? const SizedBox(
                      width: 20, 
                      height: 20, 
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                    )
                  : const Icon(Icons.sync),
              label: Text(_isSyncing ? 'Procesando...' : 'Sincronizar'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(SyncLog log) {
    final isSuccess = log.estado == SyncStatus.exitoso;
    final color = isSuccess ? Colors.green : Colors.red;
    final icon = isSuccess ? Icons.check_circle_outline : Icons.error_outline;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: color, size: 30),
        title: Text(
          isSuccess ? 'Sincronización Exitosa' : 'Error de Sincronización',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(log.fecha)),
            const SizedBox(height: 4),
            Text(log.mensaje),
            if (isSuccess) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  _Badge(label: 'Procesados: ${log.usuariosProcesados}', color: Colors.blue.shade100, textColor: Colors.blue.shade900),
                  const SizedBox(width: 8),
                  _Badge(label: 'Actualizados: ${log.usuariosActualizados}', color: Colors.green.shade100, textColor: Colors.green.shade900),
                ],
              )
            ]
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _Badge({required this.label, required this.color, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: textColor, fontWeight: FontWeight.bold),
      ),
    );
  }
}
