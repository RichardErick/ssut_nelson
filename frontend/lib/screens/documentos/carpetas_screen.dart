import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/carpeta.dart';
import '../../services/carpeta_service.dart';
import 'documento_form_screen.dart';

class CarpetasScreen extends StatefulWidget {
  const CarpetasScreen({super.key});

  @override
  State<CarpetasScreen> createState() => _CarpetasScreenState();
}

class _CarpetasScreenState extends State<CarpetasScreen> {
  static const String _nombreCarpetaPermitida = 'Comprobante de Egreso';
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
      final carpetas = await carpetaService.getArbol(_gestion);
      final ordered = [...carpetas]
        ..sort((a, b) {
          final aIsMain = a.nombre == _nombreCarpetaPermitida;
          final bIsMain = b.nombre == _nombreCarpetaPermitida;
          if (aIsMain == bIsMain) return a.id.compareTo(b.id);
          return aIsMain ? -1 : 1;
        });
      setState(() => _carpetas = ordered);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al cargar carpetas: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _crearCarpeta({int? padreId}) async {
    if (padreId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solo se permite crear la carpeta Comprobante de Egreso'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_carpetas.any((c) => c.nombre == _nombreCarpetaPermitida)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La carpeta Comprobante de Egreso ya existe'), backgroundColor: Colors.orange),
      );
      return;
    }
    final nombreController = TextEditingController(text: _nombreCarpetaPermitida);
    final numeroController = TextEditingController(text: _nextNumeroCarpeta().toString());
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
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Nombre *'),
            ),
            const SizedBox(height: 8),
            TextField(
              readOnly: true,
              controller: TextEditingController(text: _gestion),
              decoration: const InputDecoration(labelText: 'Gesti??n'),
            ),
            const SizedBox(height: 8),
            TextField(
              readOnly: true,
              controller: numeroController,
              decoration: const InputDecoration(labelText: 'N??mero Correlativo'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descripcionController,
              decoration: const InputDecoration(labelText: 'Descripcion'),
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
                  codigo: null,
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
    final hasCarpetas = _carpetas.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text('Carpetas', style: GoogleFonts.poppins()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCarpetas,
          ),
        ],
      ),
      floatingActionButton: hasCarpetas
          ? FloatingActionButton.extended(
              onPressed: () => _crearCarpeta(),
              icon: const Icon(Icons.create_new_folder),
              label: const Text('Nueva Carpeta'),
              backgroundColor: Colors.amber.shade800,
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : hasCarpetas
              ? RefreshIndicator(
                  onRefresh: _loadCarpetas,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _carpetas.length,
                    itemBuilder: (context, index) {
                      final carpeta = _carpetas[index];
                      return _buildCarpetaItem(carpeta);
                    },
                  ),
                )
              : _buildEmptyState(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_off_rounded, size: 80, color: Colors.amber.shade700),
            const SizedBox(height: 16),
            Text(
              'No hay carpetas para $_gestion',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Crea la primera carpeta para empezar a organizar documentos.',
              style: GoogleFonts.poppins(color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 260,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _crearCarpeta(),
                icon: const Icon(Icons.add_box_rounded, size: 22),
                label: const Text('Crear carpeta'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade800,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarpetaSubtitle(Carpeta carpeta) {
    final gestionLine =
        carpeta.gestion.isNotEmpty ? 'Gestion ${carpeta.gestion}' : null;
    final nroLine =
        carpeta.numeroCarpeta != null ? 'Nro ${carpeta.numeroCarpeta}' : null;
    final romano = (carpeta.codigoRomano ?? '').isNotEmpty
        ? carpeta.codigoRomano
        : carpeta.codigo;
    final romanoLine = (romano ?? '').isNotEmpty ? 'Romano $romano' : null;
    final rango = _formatRango(carpeta);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (gestionLine != null) Text(gestionLine),
        if (nroLine != null) Text(nroLine),
        if (romanoLine != null) Text(romanoLine),
        const SizedBox(height: 4),
        Text('Documentos: ${carpeta.numeroDocumentos} - Rango: $rango'),
      ],
    );
  }

  Future<void> _confirmarEliminarCarpeta(Carpeta carpeta) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar carpeta'),
        content: Text(
          'Se eliminara la carpeta "${carpeta.nombre}". No se puede eliminar si tiene documentos o subcarpetas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _eliminarCarpeta(carpeta);
    }
  }

  Future<void> _eliminarCarpeta(Carpeta carpeta) async {
    try {
      final carpetaService = Provider.of<CarpetaService>(context, listen: false);
      await carpetaService.delete(carpeta.id, hard: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Carpeta eliminada')));
      _loadCarpetas();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
    }
  }

  Widget _buildCarpetaItem(Carpeta carpeta) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: Colors.amber.shade100,
          child: Icon(Icons.folder_rounded, color: Colors.amber.shade800, size: 26),
        ),
        title: Text(carpeta.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: _buildCarpetaSubtitle(carpeta),
        children: [
          if (carpeta.subcarpetas.isNotEmpty)
            ...carpeta.subcarpetas.map((sub) => ListTile(
                  contentPadding: const EdgeInsets.only(left: 32, right: 16),
                  leading: Icon(Icons.folder_open_rounded, color: Colors.amber.shade400),
                  title: Text(sub.nombre),
                  subtitle: Text('Romano ${sub.codigo ?? "S/C"} - ${sub.numeroDocumentos} docs'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Navegar a detalles de carpeta o lista de documentos filtrada
                  },
                )),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _confirmarEliminarCarpeta(carpeta),
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  label: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _agregarDocumentoACarpeta(carpeta),
                  icon: const Icon(Icons.note_add_rounded, size: 20, color: Colors.white),
                  label: const Text('Agregar carpeta', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _nextNumeroCarpeta() {
    if (_carpetas.isEmpty) return 1;
    final numeros = _carpetas
        .map((c) => c.numeroCarpeta)
        .whereType<int>()
        .toList();
    if (numeros.isEmpty) return _carpetas.length + 1;
    numeros.sort();
    return numeros.last + 1;
  }

  String _formatRango(Carpeta carpeta) {
    if (carpeta.rangoInicio == null || carpeta.rangoFin == null) {
      return 'sin documentos';
    }
    return '${carpeta.rangoInicio} - ${carpeta.rangoFin}';
  }

  void _agregarDocumentoACarpeta(Carpeta carpeta) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentoFormScreen(initialCarpetaId: carpeta.id),
      ),
    );
    if (result == true) {
      _loadCarpetas();
    }
  }
}
