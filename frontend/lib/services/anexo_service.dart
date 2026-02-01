import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/anexo.dart';
import 'api_service.dart';

class AnexoService {
  Future<List<Anexo>> listarPorDocumento(int documentoId) async {
    final api = Provider.of<ApiService>(navigatorKey.currentContext!, listen: false);
    final response = await api.get('/documentos/$documentoId/anexos');
    final data = response.data;
    if (data is! List) return [];
    return data.map((e) => Anexo.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<Anexo> subirArchivo(int documentoId, PlatformFile file) async {
    final api = Provider.of<ApiService>(navigatorKey.currentContext!, listen: false);

    MultipartFile multipart;
    if (file.bytes != null) {
      multipart = MultipartFile.fromBytes(file.bytes!, filename: file.name);
    } else if (file.path != null) {
      multipart = await MultipartFile.fromFile(file.path!, filename: file.name);
    } else {
      throw Exception('No se pudo leer el archivo seleccionado');
    }

    final form = FormData.fromMap({
      'file': multipart,
    });

    final response = await api.post(
      '/documentos/$documentoId/anexos',
      data: form,
    );
    return Anexo.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<Uint8List> descargarBytes(int anexoId) async {
    final api = Provider.of<ApiService>(navigatorKey.currentContext!, listen: false);

    // Timeout largo para PDFs grandes (60 s)
    final response = await api.getBytes(
      '/documentos/anexos/$anexoId/download',
      receiveTimeout: const Duration(seconds: 60),
    );

    final data = response.data;
    if (data is Uint8List) return data;
    if (data is List<int>) return Uint8List.fromList(data);
    throw Exception('Respuesta invalida al descargar el anexo');
  }
}

