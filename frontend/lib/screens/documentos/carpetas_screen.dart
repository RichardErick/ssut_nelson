import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/carpeta.dart';
import '../../services/carpeta_service.dart';

class CarpetasScreen extends StatefulWidget {
  const CarpetasScreen({super.key});

  @override
  State<CarpetasScreen> createState() => _CarpetasScreenState();
}

class _CarpetasScreenState extends State<CarpetasScreen> {
  bool _isLoading = false;
  List<Carpeta> _carpetas = [];
  String _gestion = DateTime.now().year.toString();

  @override
  void initState() {
    super.initState();
    _loadCarpetas();
  }

  Future<void> _loadCarpetas() async {
    setState(() => _isLoading = true);
    try {
      final carpetaService = Provider.of<CarpetaService>(context, listen: false);
      // Usamos el endpoint arbol para ver jerarquia
      final carpetas = await carpetaService.getArbol(_gestion);
      setState(() => _carpetas = carpetas);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar carpetas: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _crearCarpeta({int? padreId}) async {
    final nombreController = TextEditingController();
    final codigoController = TextEditingController();
    final descripcionController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(padreId == null ? 'Nueva Carpeta Principal' : 'Nueva Subcarpeta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreController,
              decoration: const InputDecoration(labelText: 'Nombre *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: codigoController,
              decoration: const InputDecoration(labelText: 'Código (Opcional)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descripcionController,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (nombreController.text.isEmpty) return;
              try {
                final carpetaService = Provider.of<CarpetaService>(context, listen: false);
                await carpetaService.create(CreateCarpetaDTO(
                  nombre: nombreController.text,
                  codigo: codigoController.text.isEmpty ? null : codigoController.text,
                  gestion: _gestion,
                  descripcion: descripcionController.text,
                  carpetaPadreId: padreId,
                ));
                if (context.mounted) Navigator.pop(context);
                _loadCarpetas();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gestión de Carpetas $_gestion', style: GoogleFonts.poppins()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCarpetas,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _crearCarpeta(),
        child: const Icon(Icons.create_new_folder),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCarpetas,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _carpetas.length,
                itemBuilder: (context, index) {
                  final carpeta = _carpetas[index];
                  return _buildCarpetaItem(carpeta);
                },
              ),
            ),
    );
  }

  Widget _buildCarpetaItem(Carpeta carpeta) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Icon(Icons.folder, color: Colors.amber.shade700, size: 40),
        title: Text(carpeta.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${carpeta.codigo ?? "S/C"} • ${carpeta.numeroDocumentos} documentos'),
        children: [
          if (carpeta.subcarpetas.isNotEmpty)
            ...carpeta.subcarpetas.map((sub) => ListTile(
              contentPadding: const EdgeInsets.only(left: 32, right: 16),
              leading: Icon(Icons.folder_open, color: Colors.amber.shade400),
              title: Text(sub.nombre),
              subtitle: Text('${sub.codigo ?? ""} • ${sub.numeroDocumentos} docs'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Navegar a detalles de carpeta o lista de documentos filtrada
              },
            )),
          ListTile(
            contentPadding: const EdgeInsets.only(left: 32),
            leading: const Icon(Icons.add, color: Colors.blue),
            title: const Text('Crear subcarpeta'),
            onTap: () => _crearCarpeta(padreId: carpeta.id),
          ),
        ],
      ),
    );
  }
}
