import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crosssync/features/pdf/data/pdf_repository.dart';
import 'package:crosssync/shared/models/pdf.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _pdfRepoProvider = Provider((_) => PdfRepository());

final pdfListProvider =
    FutureProvider.autoDispose<List<PdfDocument>>((ref) async {
  return ref.watch(_pdfRepoProvider).listDocuments();
});

// ---------------------------------------------------------------------------
// Main screen
// ---------------------------------------------------------------------------

class PdfScreen extends ConsumerStatefulWidget {
  const PdfScreen({super.key});

  @override
  ConsumerState<PdfScreen> createState() => _PdfScreenState();
}

class _PdfScreenState extends ConsumerState<PdfScreen> {
  final Set<String> _selectedIds = {};
  bool _merging = false;

  void _toggleSelect(String id) {
    setState(() {
      _selectedIds.contains(id) ? _selectedIds.remove(id) : _selectedIds.add(id);
    });
  }

  Future<void> _merge() async {
    if (_selectedIds.length < 2) return;
    setState(() => _merging = true);
    try {
      final repo = ref.read(_pdfRepoProvider);
      await repo.mergeDocuments(
        _selectedIds.toList(),
        'merged_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      _selectedIds.clear();
      ref.invalidate(pdfListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDFs merged successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Merge failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _merging = false);
    }
  }

  Future<void> _delete(String docId) async {
    final repo = ref.read(_pdfRepoProvider);
    await repo.deleteDocument(docId);
    ref.invalidate(pdfListProvider);
  }

  Future<void> _showUploadSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _UploadSheet(
        onUploaded: () {
          ref.invalidate(pdfListProvider);
          Navigator.pop(context);
        },
        repo: ref.read(_pdfRepoProvider),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pdfAsync = ref.watch(pdfListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Tools'),
        actions: [
          if (_selectedIds.length >= 2)
            _merging
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton.icon(
                    onPressed: _merge,
                    icon: const Icon(Icons.merge_type),
                    label: Text('Merge ${_selectedIds.length}'),
                  ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showUploadSheet,
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload PDF'),
      ),
      body: pdfAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (docs) => docs.isEmpty
            ? const _EmptyState()
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _DocCard(
                  doc: docs[i],
                  selected: _selectedIds.contains(docs[i].id),
                  onToggle: () => _toggleSelect(docs[i].id),
                  onDelete: () => _delete(docs[i].id),
                  repo: ref.read(_pdfRepoProvider),
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.picture_as_pdf_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'No PDFs uploaded yet',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap "Upload PDF" to get started',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Document card
// ---------------------------------------------------------------------------

class _DocCard extends StatelessWidget {
  const _DocCard({
    required this.doc,
    required this.selected,
    required this.onToggle,
    required this.onDelete,
    required this.repo,
  });

  final PdfDocument doc;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final PdfRepository repo;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: selected
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Colors.grey.shade200,
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: GestureDetector(
          onTap: onToggle,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade400,
                width: 2,
              ),
            ),
            child: selected
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
        ),
        title: Text(
          doc.filename,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${doc.pageCount} pages · ${doc.fileSizeLabel}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.auto_awesome_outlined, size: 20),
              color: Colors.deepPurple,
              tooltip: 'AI Analysis',
              onPressed: () => _showAiPanel(context),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: Colors.red.shade300,
              tooltip: 'Delete',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  void _showAiPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AiPanel(doc: doc, repo: repo),
    );
  }
}

// ---------------------------------------------------------------------------
// AI panel bottom sheet
// ---------------------------------------------------------------------------

class _AiPanel extends StatefulWidget {
  const _AiPanel({required this.doc, required this.repo});

  final PdfDocument doc;
  final PdfRepository repo;

  @override
  State<_AiPanel> createState() => _AiPanelState();
}

class _AiPanelState extends State<_AiPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String _summary = '';
  bool _summaryLoading = false;
  String? _summaryError;

  final List<({String role, String content})> _messages = [];
  final _questionController = TextEditingController();
  bool _chatLoading = false;
  String? _chatError;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    if (widget.doc.isSummarized && widget.doc.summary != null) {
      _summary = widget.doc.summary!;
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _fetchSummary() async {
    setState(() {
      _summaryLoading = true;
      _summaryError = null;
    });
    try {
      final s = await widget.repo.getSummary(widget.doc.id);
      setState(() => _summary = s);
    } catch (e) {
      setState(() => _summaryError = e.toString());
    } finally {
      if (mounted) setState(() => _summaryLoading = false);
    }
  }

  Future<void> _sendQuestion() async {
    final q = _questionController.text.trim();
    if (q.isEmpty) return;
    _questionController.clear();
    setState(() {
      _messages.add((role: 'user', content: q));
      _chatLoading = true;
      _chatError = null;
    });
    try {
      final answer = await widget.repo.askQuestion(widget.doc.id, q);
      setState(() {
        _messages.add((role: 'assistant', content: answer));
      });
    } catch (e) {
      setState(() => _chatError = e.toString());
    } finally {
      if (mounted) setState(() => _chatLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Column(
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_awesome,
                      color: Colors.deepPurple, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.doc.filename,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const Text(
                        'AI Analysis',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Tabs
          TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Summary'),
              Tab(text: 'Ask Questions'),
            ],
          ),
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _SummaryTab(
                  summary: _summary,
                  loading: _summaryLoading,
                  error: _summaryError,
                  onGenerate: _fetchSummary,
                  scrollController: scrollController,
                ),
                _ChatTab(
                  messages: _messages,
                  loading: _chatLoading,
                  error: _chatError,
                  controller: _questionController,
                  onSend: _sendQuestion,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({
    required this.summary,
    required this.loading,
    required this.error,
    required this.onGenerate,
    required this.scrollController,
  });

  final String summary;
  final bool loading;
  final String? error;
  final VoidCallback onGenerate;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(error!,
              style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
        ),
      );
    }
    if (summary.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('Generate an AI summary of this document'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('Generate Summary'),
            ),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      child: Text(summary, style: const TextStyle(height: 1.6)),
    );
  }
}

class _ChatTab extends StatelessWidget {
  const _ChatTab({
    required this.messages,
    required this.loading,
    required this.error,
    required this.controller,
    required this.onSend,
  });

  final List<({String role, String content})> messages;
  final bool loading;
  final String? error;
  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? const Center(
                  child: Text(
                    'Ask anything about this document',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length + (loading ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    if (loading && i == messages.length) {
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }
                    final msg = messages[i];
                    final isUser = msg.role == 'user';
                    return Align(
                      alignment: isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(context).size.width * 0.75,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isUser
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: isUser
                                ? const Radius.circular(16)
                                : const Radius.circular(4),
                            bottomRight: isUser
                                ? const Radius.circular(4)
                                : const Radius.circular(16),
                          ),
                        ),
                        child: Text(
                          msg.content,
                          style: TextStyle(
                            color: isUser ? Colors.white : Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(error!,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'Ask a question…',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  onSubmitted: (_) => onSend(),
                  textInputAction: TextInputAction.send,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: loading ? null : onSend,
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(14),
                ),
                child: const Icon(Icons.send, size: 18),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Upload sheet
// ---------------------------------------------------------------------------

class _UploadSheet extends StatefulWidget {
  const _UploadSheet({required this.onUploaded, required this.repo});

  final VoidCallback onUploaded;
  final PdfRepository repo;

  @override
  State<_UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends State<_UploadSheet> {
  bool _uploading = false;
  String? _error;

  /// Trigger file picking and upload.
  /// Uses file_picker if available; shows instructions otherwise.
  Future<void> _pickAndUpload() async {
    // Dynamic import to avoid hard dep at compile time for this demo.
    // In a real build with file_picker in pubspec: use FilePicker.platform.pickFiles()
    setState(() {
      _error =
          'To enable file picking, add file_picker to pubspec.yaml and import it.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Upload PDF',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _pickAndUpload,
            child: Container(
              width: double.infinity,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tap to select a PDF file',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Maximum size: 50 MB',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: Colors.amber.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                          fontSize: 12, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_uploading) ...[
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
          ],
        ],
      ),
    );
  }
}
