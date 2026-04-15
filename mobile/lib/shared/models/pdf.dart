class PdfDocument {
  final String id;
  final String userId;
  final String filename;
  final int pageCount;
  final int fileSize;
  final String? summary;
  final bool isSummarized;
  final String uploadedAt;

  const PdfDocument({
    required this.id,
    required this.userId,
    required this.filename,
    required this.pageCount,
    required this.fileSize,
    this.summary,
    required this.isSummarized,
    required this.uploadedAt,
  });

  factory PdfDocument.fromJson(Map<String, dynamic> json) => PdfDocument(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        filename: json['filename'] as String,
        pageCount: json['page_count'] as int,
        fileSize: json['file_size'] as int,
        summary: json['summary'] as String?,
        isSummarized: json['is_summarized'] as bool,
        uploadedAt: json['uploaded_at'] as String,
      );

  String get fileSizeLabel {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
