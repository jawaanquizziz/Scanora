import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scanora/core/theme/app_colors.dart';
import 'package:scanora/core/widgets/custom_dialogs.dart';
import 'package:scanora/models/scanned_document.dart';
import '../models/chat_message.dart';
import '../models/document_chunk.dart';
import '../models/source_citation.dart';
import '../repositories/document_chat_repository.dart';
import '../services/document_chunking_service.dart';
import '../services/document_retrieval_service.dart';
import '../services/document_text_extraction_service.dart';
import '../services/on_device_ai_service.dart';
import '../screens/pdf_citation_viewer_screen.dart';

class DocumentChatScreen extends StatefulWidget {
  final ScannedDocument document;

  const DocumentChatScreen({
    super.key,
    required this.document,
  });

  @override
  State<DocumentChatScreen> createState() => _DocumentChatScreenState();
}

class _DocumentChatScreenState extends State<DocumentChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DocumentChatRepository _chatRepository = DocumentChatRepository();
  final DocumentTextExtractionService _extractionService =
      DocumentTextExtractionService();
  final DocumentChunkingService _chunkingService = DocumentChunkingService();
  final DocumentRetrievalService _retrievalService = DocumentRetrievalService();
  final OnDeviceAIService _aiService = OnDeviceAIService();

  List<ChatMessage> _messages = [];
  List<DocumentChunk> _chunks = [];

  bool _isExtracting = true;
  String _extractionStatus = 'Reading document text...';
  double _extractionProgress = 0.0;
  bool _isGenerating = false;
  String? _extractionError;

  bool _isDownloadingModel = false;
  double _modelDownloadProgress = 0.0;
  String _modelDownloadStatus = '';

  @override
  void initState() {
    super.initState();
    _loadMessagesAndIndex();
    _autoInitOrDownloadModel();
  }

  Future<void> _autoInitOrDownloadModel() async {
    final downloaded = await _aiService.isModelDownloaded();
    if (!downloaded && !_isDownloadingModel) {
      if (mounted) {
        setState(() {
          _isDownloadingModel = true;
          _modelDownloadStatus = 'Downloading AI engine...';
          _modelDownloadProgress = 0.0;
        });
      }
      try {
        await _aiService.downloadModel(
          onProgress: (p) {
            if (mounted) {
              setState(() {
                _modelDownloadProgress = p.progress;
                _modelDownloadStatus = p.statusMessage;
              });
            }
          },
        );
      } catch (e) {
        debugPrint('Auto download error: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isDownloadingModel = false;
          });
        }
      }
    }

    // Pre-initialize in background isolate so first message is instant
    if (await _aiService.isModelDownloaded() && !_aiService.isModelReady) {
      try {
        await _aiService.ensureModelInitialized();
        if (mounted) setState(() {});
      } catch (e) {
        debugPrint('Pre-initialization error: $e');
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessagesAndIndex() async {
    // 1. Load saved messages
    final saved = await _chatRepository.getMessages(widget.document.id);
    if (mounted) {
      setState(() {
        _messages = saved;
      });
    }

    // 2. Extract / load cached text and chunk
    await _indexDocument();
  }

  Future<void> _indexDocument({bool forceRefresh = false}) async {
    setState(() {
      _isExtracting = true;
      _extractionError = null;
      _extractionStatus = 'Extracting document text...';
      _extractionProgress = 0.0;
    });

    try {
      final extracted = await _extractionService.extractText(
        documentId: widget.document.id,
        filePath: widget.document.filePath,
        thumbnailPath: widget.document.thumbnailPath,
        forceRefresh: forceRefresh,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _extractionProgress = total > 0 ? (current / total) : 0.0;
              _extractionStatus = 'Processing Page $current of $total...';
            });
          }
        },
      );

      final chunks = _chunkingService.chunkDocument(extracted);

      if (mounted) {
        setState(() {
          _chunks = chunks;
          _isExtracting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExtracting = false;
          _extractionError = e.toString();
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? presetText]) async {
    final query = (presetText ?? _textController.text).trim();
    if (query.isEmpty || _isGenerating) return;

    if (_isExtracting) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document text is being indexed. Please try again in a few seconds.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    _textController.clear();

    final userMessage = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}_u',
      documentId: widget.document.id,
      sender: MessageSender.user,
      content: query,
      timestamp: DateTime.now(),
    );

    // If chunks are empty, attempt immediate extraction
    if (_chunks.isEmpty) {
      await _indexDocument(forceRefresh: true);
    }

    if (_chunks.isEmpty) {
      final emptyDocMessage = ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}_a',
        documentId: widget.document.id,
        sender: MessageSender.assistant,
        content: 'I could not detect any readable text in this document yet. Tap the menu (⋮) at the top right and select "Re-extract Text" to scan it with OCR.',
        timestamp: DateTime.now(),
      );
      setState(() {
        _messages.add(userMessage);
        _messages.add(emptyDocMessage);
      });
      await _chatRepository.saveMessages(widget.document.id, _messages);
      _scrollToBottom();
      return;
    }

    final assistantPlaceholder = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}_a',
      documentId: widget.document.id,
      sender: MessageSender.assistant,
      content: '',
      timestamp: DateTime.now(),
      isGenerating: true,
    );

    setState(() {
      _messages.add(userMessage);
      _messages.add(assistantPlaceholder);
      _isGenerating = true;
    });
    _scrollToBottom();

    // Persist user message
    await _chatRepository.saveMessages(widget.document.id, _messages);

    try {
      // 1. Retrieve relevant passages
      final retrievedChunks = _retrievalService.retrieve(
        query: query,
        chunks: _chunks,
        topK: 4,
      );

      // 2. Generate grounded answer
      String accumulated = '';
      final result = await _aiService.generateAnswer(
        question: query,
        retrievedChunks: retrievedChunks,
        conversationHistory: _messages.where((m) => m != assistantPlaceholder).toList(),
        onToken: (token) {
          accumulated += token;
          if (mounted) {
            setState(() {
              final lastIdx = _messages.length - 1;
              if (lastIdx >= 0 && _messages[lastIdx].id == assistantPlaceholder.id) {
                _messages[lastIdx] = _messages[lastIdx].copyWith(
                  content: accumulated,
                );
              }
            });
            _scrollToBottom();
          }
        },
      );

      if (mounted) {
        setState(() {
          final lastIdx = _messages.length - 1;
          if (lastIdx >= 0 && _messages[lastIdx].id == assistantPlaceholder.id) {
            _messages[lastIdx] = _messages[lastIdx].copyWith(
              content: result.answer,
              citations: result.citations,
              isGenerating: false,
            );
          }
          _isGenerating = false;
        });
      }

      await _chatRepository.saveMessages(widget.document.id, _messages);
    } catch (e) {
      if (mounted) {
        setState(() {
          final lastIdx = _messages.length - 1;
          if (lastIdx >= 0 && _messages[lastIdx].id == assistantPlaceholder.id) {
            _messages[lastIdx] = _messages[lastIdx].copyWith(
              content: 'Failed to generate answer: ${e.toString()}',
              isError: true,
              isGenerating: false,
            );
          }
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _clearConversation() async {
    final confirm = await CustomDialogs.showConfirmDialog(
      context: context,
      title: 'Clear Chat History?',
      message: 'This will delete the conversation for "${widget.document.title}".',
      confirmLabel: 'Clear',
      isDestructive: true,
    );

    if (confirm && mounted) {
      await _chatRepository.clearMessages(widget.document.id);
      setState(() {
        _messages.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat history cleared')),
        );
      }
    }
  }

  void _openCitation(SourceCitation citation) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfCitationViewerScreen(
          document: widget.document,
          targetPageNumber: citation.pageNumber,
          snippet: citation.snippet,
        ),
      ),
    );
  }

  void _showModelInfoDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return FutureBuilder<bool>(
            future: _aiService.isModelDownloaded(),
            builder: (context, snapshot) {
              final isDownloaded = snapshot.data ?? false;

              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.auto_awesome,
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'On-Device AI Engine',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Scanora uses an on-device local model to answer questions privately without sending document contents to any external servers.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow('Engine Runtime', 'Llama (llama.cpp FFI)'),
                      _buildInfoRow('Model Architecture', 'SmolLM2-135M Instruct GGUF'),
                      _buildInfoRow('Storage Required', '~105 MB (Q4_K_M quantized)'),
                      _buildInfoRow(
                        'Model Status',
                        isDownloaded ? 'Downloaded & Ready' : 'Extractive Grounding Active',
                        valueColor: isDownloaded ? AppColors.success : AppColors.primary,
                      ),
                      _buildInfoRow('Indexed Chunks', '${_chunks.length} segments'),
                      const SizedBox(height: 20),
                      if (!isDownloaded) ...[
                        if (_isDownloadingModel) ...[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _modelDownloadStatus,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.lensOrange,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '${(_modelDownloadProgress * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.lensOrange,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: _modelDownloadProgress > 0 ? _modelDownloadProgress : null,
                                  minHeight: 6,
                                  backgroundColor: AppColors.lensOrange.withValues(alpha: 0.15),
                                  valueColor: const AlwaysStoppedAnimation(AppColors.lensOrange),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ] else ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                setSheetState(() {
                                  _isDownloadingModel = true;
                                  _modelDownloadStatus = 'Starting download...';
                                  _modelDownloadProgress = 0.0;
                                });
                                setState(() {});
                                try {
                                  await _aiService.downloadModel(
                                    onProgress: (p) {
                                      setSheetState(() {
                                        _modelDownloadProgress = p.progress;
                                        _modelDownloadStatus = p.statusMessage;
                                      });
                                    },
                                  );
                                  setSheetState(() {
                                    _isDownloadingModel = false;
                                  });
                                  setState(() {});
                                } catch (e) {
                                  setSheetState(() {
                                    _isDownloadingModel = false;
                                  });
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Download failed: $e')),
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.lensOrange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.download_rounded, size: 20),
                              label: const Text(
                                'Download Llama Model (~105 MB)',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                Navigator.pop(context);
                                await _indexDocument(forceRefresh: true);
                              },
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Re-index Text'),
                            ),
                          ),
                          if (isDownloaded) ...[
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                await _aiService.deleteModel();
                                setSheetState(() {});
                                setState(() {});
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('Model file removed')),
                                );
                              },
                              icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                              label: const Text('Delete Model', style: TextStyle(color: AppColors.error)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0F14) : const Color(0xFFF5F6FA),
      body: Column(
        children: [
          _buildPremiumHeader(context, isDark),
          if (_isExtracting) _buildExtractionBanner(isDark),
          if (_extractionError != null) _buildExtractionErrorBanner(),
          _buildModelStatusBanner(isDark),
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState(isDark)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _buildMessageItem(msg, isDark);
                    },
                  ),
          ),
          _buildInputArea(isDark),
        ],
      ),
    );
  }

  Widget _buildPremiumHeader(BuildContext context, bool isDark) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: Color(0x55EA580C),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              // Back button
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
              // AI avatar
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              // Title + doc name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chat with Document',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        const Icon(Icons.picture_as_pdf_rounded, color: Colors.white70, size: 12),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            widget.document.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          ' · ${widget.document.pageCount}p',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Actions
              IconButton(
                icon: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 22),
                tooltip: 'AI Info',
                onPressed: _showModelInfoDialog,
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white, size: 22),
                color: isDark ? const Color(0xFF1E222D) : Colors.white,
                onSelected: (val) {
                  if (val == 'clear') _clearConversation();
                  if (val == 'reindex') _indexDocument(forceRefresh: true);
                  if (val == 'info') _showModelInfoDialog();
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'clear',
                    child: Row(children: [
                      Icon(Icons.delete_sweep_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Clear Conversation'),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'reindex',
                    child: Row(children: [
                      Icon(Icons.refresh, size: 20),
                      SizedBox(width: 12),
                      Text('Re-extract Text'),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'info',
                    child: Row(children: [
                      Icon(Icons.auto_awesome, size: 20),
                      SizedBox(width: 12),
                      Text('Engine Info'),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModelStatusBanner(bool isDark) {
    if (!_isDownloadingModel) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isDark ? const Color(0xFF1E1E26) : const Color(0xFFF3F4F6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppColors.lensOrange),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _modelDownloadStatus.isNotEmpty
                        ? _modelDownloadStatus
                        : 'Preparing AI engine...',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.lensOrange,
                    ),
                  ),
                ],
              ),
              Text(
                '${(_modelDownloadProgress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.lensOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _modelDownloadProgress > 0 ? _modelDownloadProgress : null,
              minHeight: 4,
              backgroundColor: AppColors.lensOrange.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation(AppColors.lensOrange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtractionBanner(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1810) : const Color(0xFFFFF7ED),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFEA580C), width: 0.5),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: const AlwaysStoppedAnimation(AppColors.lensOrange),
                  value: _extractionProgress > 0 ? _extractionProgress : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _extractionStatus,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.lensOrange,
                  ),
                ),
              ),
            ],
          ),
          if (_extractionProgress > 0) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _extractionProgress,
                minHeight: 3,
                backgroundColor: AppColors.lensOrange.withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation(AppColors.lensOrange),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExtractionErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.error.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Extraction note: $_extractionError',
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () => _indexDocument(forceRefresh: true),
            child: const Text('Retry', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final suggestions = [
      ('Summarize this document', Icons.auto_stories_rounded),
      ('What are the key points?', Icons.lightbulb_outline_rounded),
      ('Are there any dates or deadlines?', Icons.calendar_today_rounded),
      ('Explain the main concept simply', Icons.school_outlined),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          // Glowing AI orb
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.lensOrange.withValues(alpha: 0.45),
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 42,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          // Title
          Text(
            'Ask anything about',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white60 : AppColors.secondaryText,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '"${widget.document.title}"',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF101828),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          FutureBuilder<bool>(
            future: _aiService.isModelDownloaded(),
            builder: (context, snapshot) {
              final isDownloaded = snapshot.data ?? false;
              return InkWell(
                onTap: _showModelInfoDialog,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isDownloaded
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.lensOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDownloaded
                          ? AppColors.success.withValues(alpha: 0.3)
                          : AppColors.lensOrange.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isDownloaded
                            ? Icons.auto_awesome_rounded
                            : Icons.lock_outline_rounded,
                        size: 13,
                        color: isDownloaded ? AppColors.success : AppColors.lensOrange,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isDownloaded
                            ? 'Llama AI Ready · 100% Offline'
                            : 'Private AI · Instant Extractive Active (Tap for Llama)',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDownloaded ? AppColors.success : AppColors.lensOrange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Suggested Questions',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : const Color(0xFF344054),
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...suggestions.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildSuggestionTile(item.$1, item.$2, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionTile(String text, IconData icon, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isExtracting ? null : () => _sendMessage(text),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1D24) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF2A2D38) : const Color(0xFFE9EAEF),
            ),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 15, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1D2939),
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: isDark ? Colors.white30 : AppColors.secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage msg, bool isDark) {
    final isUser = msg.sender == MessageSender.user;

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14, left: 60),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 12),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.lensOrange.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  msg.content,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── AI / Assistant message ──────────────────────────────────────────────
    return Container(
      margin: const EdgeInsets.only(bottom: 18, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + name row
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.lensOrange.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 9),
              ShaderMask(
                shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                child: const Text(
                  'Scanora AI',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Colors.white,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              const Spacer(),
              if (!msg.isGenerating && msg.content.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: msg.content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text('Copied to clipboard'),
                          ],
                        ),
                        backgroundColor: AppColors.lensOrange,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : AppColors.lensOrange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : AppColors.lensOrange.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy_rounded, size: 12, color: AppColors.lensOrange),
                        const SizedBox(width: 4),
                        Text(
                          'Copy',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.lensOrange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Message bubble
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1D26) : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(5),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF2A2F3E)
                    : AppColors.lensOrange.withValues(alpha: 0.12),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (msg.isGenerating && msg.content.isEmpty)
                  _buildTypingIndicator(isDark)
                else
                  _buildFormattedMessageContent(msg.content, msg.isError, isDark),

                // Source Citations
                if (msg.citations.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.lensOrange.withValues(alpha: 0.4),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.lensOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.menu_book_rounded,
                          size: 12,
                          color: AppColors.lensOrange,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'Sources in Document',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white60 : AppColors.secondaryText,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 7,
                    children: msg.citations.map((c) {
                      return GestureDetector(
                        onTap: () => _openCitation(c),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.lensOrange.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.open_in_new_rounded, size: 11, color: Colors.white),
                              const SizedBox(width: 5),
                              Text(
                                'Page ${c.pageNumber}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: const AlwaysStoppedAnimation(AppColors.lensOrange),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Searching document...',
          style: TextStyle(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            color: isDark ? Colors.white38 : AppColors.secondaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildFormattedMessageContent(String content, bool isError, bool isDark) {
    final clean = content.replaceAll('**', '').replaceAll('*', '');
    final textColor = isError
        ? AppColors.error
        : (isDark ? Colors.white : const Color(0xFF1D2939));

    final lines = clean.split('\n');
    final children = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        children.add(const SizedBox(height: 6));
        continue;
      }

      if (line.endsWith(':') && !line.startsWith('•')) {
        // Section header like "Document Summary:" or "Based on the document:"
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6, top: 2),
            child: Text(
              line,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: 0.1,
              ),
            ),
          ),
        );
      } else if (line.startsWith('• ') && line.contains(':')) {
        // Bullet with field like "• Course Name: Mobile App..."
        final colonIdx = line.indexOf(':');
        final keyPart = line.substring(2, colonIdx + 1); // e.g. "Course Name:"
        final valPart = line.substring(colonIdx + 1);

        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text(
                    '• ',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.lensOrange,
                    ),
                  ),
                ),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.45,
                        color: textColor,
                      ),
                      children: [
                        TextSpan(
                          text: '$keyPart ',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: valPart.trim()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (line.startsWith('• ')) {
        // Plain bullet
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text(
                    '• ',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.lensOrange,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    line.substring(2),
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.45,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (line.startsWith('Source:') || line.startsWith('Unfilled form fields:')) {
        // Muted footer line
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: Text(
              line,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ),
        );
      } else {
        // Regular line
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              line,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.5,
                color: textColor,
              ),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13151C) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? const Color(0xFF2A2F3E)
                : AppColors.lensOrange.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 46, maxHeight: 120),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E222D) : const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF2C3040)
                      : const Color(0xFFE5E7EB),
                  width: 1.2,
                ),
              ),
              child: TextField(
                controller: _textController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: null,
                minLines: 1,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white : const Color(0xFF1D2939),
                ),
                decoration: InputDecoration(
                  hintText: 'Ask about this document…',
                  hintStyle: TextStyle(
                    fontSize: 14.5,
                    color: isDark ? Colors.white30 : const Color(0xFFADB5C2),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Send button with gradient
          GestureDetector(
            onTap: (_isGenerating || _isExtracting) ? null : _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: (_isGenerating || _isExtracting)
                    ? LinearGradient(
                        colors: [
                          AppColors.lensOrange.withValues(alpha: 0.4),
                          AppColors.lensOrangeDark.withValues(alpha: 0.4),
                        ],
                      )
                    : AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: (_isGenerating || _isExtracting)
                    ? []
                    : [
                        BoxShadow(
                          color: AppColors.lensOrange.withValues(alpha: 0.45),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
              ),
              child: Center(
                child: _isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.secondaryText),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

