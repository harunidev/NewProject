import 'dart:io';
import 'package:dio/dio.dart';
import 'package:crosssync/core/api/api_client.dart';
import 'package:crosssync/shared/models/pdf.dart';

class PdfRepository {
  final Dio _dio = ApiClient.instance.dio;

  Future<List<PdfDocument>> listDocuments() async {
    final res = await _dio.get('/pdf/');
    return (res.data as List)
        .map((e) => PdfDocument.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PdfDocument> uploadDocument(File file) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      ),
    });
    final res = await _dio.post('/pdf/', data: formData);
    return PdfDocument.fromJson(res.data as Map<String, dynamic>);
  }

  Future<String> getSummary(String docId) async {
    final res = await _dio.get('/pdf/$docId/summary');
    return res.data['summary'] as String;
  }

  Future<String> askQuestion(String docId, String question) async {
    final res = await _dio.post(
      '/pdf/$docId/ask',
      data: {'question': question},
    );
    return res.data['answer'] as String;
  }

  Future<PdfDocument> mergeDocuments(
      List<String> ids, String outputFilename) async {
    final res = await _dio.post('/pdf/merge', data: {
      'document_ids': ids,
      'output_filename': outputFilename,
    });
    return PdfDocument.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteDocument(String docId) async {
    await _dio.delete('/pdf/$docId');
  }
}
