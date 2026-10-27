import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/chat_message.dart';
import '../models/document_chunk.dart';
import '../models/source_citation.dart';
import '../providers/llamafu_ai_provider.dart';
import '../providers/on_device_ai_provider.dart';

class ModelDownloadProgress {
  final double progress; // 0.0 to 1.0
  final int bytesDownloaded;
  final int totalBytes;
  final String statusMessage;

  const ModelDownloadProgress({
    required this.progress,
    required this.bytesDownloaded,
    required this.totalBytes,
    required this.statusMessage,
  });
}

class GenerationResult {
  final String answer;
  final List<SourceCitation> citations;
  final bool usedOnDeviceLlm;

  const GenerationResult({
    required this.answer,
    required this.citations,
    required this.usedOnDeviceLlm,
  });
}

/// Internal helper for sentence-level scoring in the grounded fallback.
class _ScoredSentence {
  final String sentence;
  final double score;
  final int page;

  const _ScoredSentence({
    required this.sentence,
    required this.score,
    required this.page,
  });
}

class OnDeviceAIService {
  static final OnDeviceAIService _instance = OnDeviceAIService._internal();
  factory OnDeviceAIService() => _instance;
  OnDeviceAIService._internal();

  static const String modelFileName = 'SmolLM2-135M-Instruct-Q4_K_M.gguf';
  static const String modelDownloadUrl =
      'https://huggingface.co/bartowski/SmolLM2-135M-Instruct-GGUF/resolve/main/SmolLM2-135M-Instruct-Q4_K_M.gguf';
  static const int estimatedModelSizeBytes = 105454432; // ~105 MB

  final OnDeviceAIProvider _provider = LlamafuAIProvider();
  bool _isDownloading = false;

  bool get isModelReady => _provider.isReady;
  bool get isDownloading => _isDownloading;

  Future<String> getModelDirectoryPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${appDir.path}/scanora_ai_models');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    return modelDir.path;
  }

  Future<String> getModelFilePath() async {
    final dir = await getModelDirectoryPath();
    return '$dir/$modelFileName';
  }

  Future<bool> isModelDownloaded() async {
    final path = await getModelFilePath();
    final file = File(path);
    if (!await file.exists()) return false;
    final length = await file.length();
    // Verify file size is roughly valid (> 50 MB)
    return length > 50 * 1024 * 1024;
  }

  /// Downloads the lightweight on-device GGUF model with real-time progress callbacks.
  Future<void> downloadModel({
    required void Function(ModelDownloadProgress progress) onProgress,
  }) async {
    if (_isDownloading) return;
    _isDownloading = true;

    HttpClient? httpClient;
    IOSink? sink;

    try {
      final targetPath = await getModelFilePath();
      final tempPath = '$targetPath.part';
      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      httpClient = HttpClient();
      httpClient.connectionTimeout = const Duration(seconds: 20);
      final request = await httpClient.getUrl(Uri.parse(modelDownloadUrl));
      request.followRedirects = true;
      request.maxRedirects = 10;
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Download failed with status: ${response.statusCode}');
      }

      final totalBytes = response.contentLength > 0
          ? response.contentLength
          : estimatedModelSizeBytes;
      int receivedBytes = 0;

      sink = tempFile.openWrite();

      await for (final chunk in response) {
        receivedBytes += chunk.length;
        sink.add(chunk);

        final ratio = totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
        final mbDownloaded = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
        final mbTotal = (totalBytes / (1024 * 1024)).toStringAsFixed(1);

        onProgress(
          ModelDownloadProgress(
            progress: ratio,
            bytesDownloaded: receivedBytes,
            totalBytes: totalBytes,
            statusMessage: 'Downloading Llama model ($mbDownloaded MB / $mbTotal MB)...',
          ),
        );
      }

      await sink.flush();
      await sink.close();
      sink = null;

      // Rename temp file to target path
      final targetFile = File(targetPath);
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tempFile.rename(targetPath);

      onProgress(
        ModelDownloadProgress(
          progress: 1.0,
          bytesDownloaded: totalBytes,
          totalBytes: totalBytes,
          statusMessage: 'Model downloaded successfully!',
        ),
      );
    } catch (e) {
      final tempPath = '${await getModelFilePath()}.part';
      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      rethrow;
    } finally {
      httpClient?.close();
      _isDownloading = false;
    }
  }

  Future<void> deleteModel() async {
    _provider.dispose();
    final path = await getModelFilePath();
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Initializes the on-device model if downloaded.
  Future<void> ensureModelInitialized({
    void Function(String status, double progress)? onProgress,
  }) async {
    if (_provider.isReady) return;

    final isDownloaded = await isModelDownloaded();
    if (!isDownloaded) {
      throw StateError('Model file is not downloaded yet.');
    }

    final isSupported = await _provider.isPlatformSupported();
    if (!isSupported) {
      throw UnsupportedError('Llamafu on-device inference is only supported on Android and iOS.');
    }

    final modelPath = await getModelFilePath();
    await _provider.initialize(
      modelPath: modelPath,
      onProgress: onProgress,
    );
  }

  /// Generates a grounded answer from retrieved chunks and user question.
  Future<GenerationResult> generateAnswer({
    required String question,
    required List<DocumentChunk> retrievedChunks,
    List<ChatMessage> conversationHistory = const [],
    void Function(String token)? onToken,
  }) async {
    if (retrievedChunks.isEmpty) {
      final noEvidenceText =
          'I could not find relevant information in the selected document to answer this question.';
      onToken?.call(noEvidenceText);
      return GenerationResult(
        answer: noEvidenceText,
        citations: const [],
        usedOnDeviceLlm: false,
      );
    }

    // Check if on-device model can be used
    bool useNativeModel = false;
    if (await isModelDownloaded() && await _provider.isPlatformSupported()) {
      try {
        if (!_provider.isReady) {
          await ensureModelInitialized();
        }
        useNativeModel = _provider.isReady;
      } catch (_) {
        useNativeModel = false;
      }
    }

    String answerText;
    bool usedLlm = false;

    if (useNativeModel) {
      try {
        final prompt = _buildLlmPrompt(
          question: question,
          chunks: retrievedChunks,
          history: conversationHistory,
        );

        answerText = await _provider.generateAnswer(
          prompt: prompt,
          onToken: onToken,
        );
        usedLlm = true;
      } catch (e) {
        // Fallback to grounded extractive engine if native LLM failed
        answerText = _generateGroundedFallback(question, retrievedChunks);
        onToken?.call(answerText);
      }
    } else {
      // Fast on-device grounded extractive answering
      answerText = _generateGroundedFallback(question, retrievedChunks);
      onToken?.call(answerText);
    }

    // Strip raw asterisks and markdown formatting that irritate the user
    final cleanAnswer = answerText
        .replaceAll('**', '')
        .replaceAll(RegExp(r'^\*\s+', multiLine: true), '• ')
        .trim();

    // Validate and build verified source citations
    final citations = _extractAndValidateCitations(
      answer: cleanAnswer,
      availableChunks: retrievedChunks,
    );

    return GenerationResult(
      answer: cleanAnswer,
      citations: citations,
      usedOnDeviceLlm: usedLlm,
    );
  }

  String _buildLlmPrompt({
    required String question,
    required List<DocumentChunk> chunks,
    required List<ChatMessage> history,
  }) {
    final buffer = StringBuffer();

    // System instruction strictly according to specification Section 7
    buffer.writeln('<|im_start|>system');
    buffer.writeln(
      'You are Scanora, an assistant that answers questions about the user\'s selected PDF. '
      'Use the supplied passages as your evidence. Do not invent facts, quotations, formulas, or page numbers. '
      'If the supplied passages do not contain enough information, clearly state that the answer could not be found in the document. '
      'Explain concepts clearly and cite the source pages supplied in the context.',
    );
    buffer.writeln('<|im_end|>');

    // Limited conversation history (last 2 turns)
    final recentHistory = history
        .where((m) => !m.isError && m.content.isNotEmpty)
        .toList();
    final limitedHistory = recentHistory.length > 4
        ? recentHistory.sublist(recentHistory.length - 4)
        : recentHistory;

    for (final msg in limitedHistory) {
      if (msg.sender == MessageSender.user) {
        buffer.writeln('<|im_start|>user\n${msg.content}<|im_end|>');
      } else if (msg.sender == MessageSender.assistant) {
        buffer.writeln('<|im_start|>assistant\n${msg.content}<|im_end|>');
      }
    }

    // Current query with grounded passages
    buffer.writeln('<|im_start|>user');
    buffer.writeln('Passages from the document:\n');
    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      buffer.writeln('[Passage ${i + 1} - Source: Page ${chunk.pageNumber}]');
      buffer.writeln(chunk.text);
      buffer.writeln();
    }

    buffer.writeln('Question: $question');
    buffer.writeln('Answer using only the passages above, and cite the source page(s):');
    buffer.writeln('<|im_end|>');
    buffer.write('<|im_start|>assistant\n');

    return buffer.toString();
  }

  /// Robust on-device grounded fallback that synthesizes retrieved passages
  /// without requiring an external server or heavy GGUF file.
  String _generateGroundedFallback(String question, List<DocumentChunk> chunks) {
    if (chunks.isEmpty) {
      return 'I could not find information about that in the document.';
    }

    final lowerQ = question.toLowerCase().trim();

    const stopwords = {
      'a', 'an', 'the', 'is', 'are', 'was', 'were', 'what', 'who', 'where',
      'when', 'why', 'how', 'which', 'in', 'on', 'at', 'to', 'for', 'of',
      'and', 'or', 'do', 'does', 'did', 'tell', 'me', 'about', 'this', 'that',
      'these', 'those', 'can', 'you', 'give', 'any', 'my', 'your', 'it',
      'there', 'anyone', 'someone', 'named', 'name', 'person', 'find', 'show',
      // Document meta-words
      'document', 'doc', 'docs', 'documents', 'pdf', 'file', 'content', 'contents',
      'page', 'pages', 'scan', 'scanned', 'text', 'line', 'lines', 'paper',
    };

    final queryWords = lowerQ
        .split(RegExp(r'[^a-zA-Z0-9]+'))
        .where((w) => w.length > 1 && !stopwords.contains(w))
        .toSet();

    // ── Summary / overview questions ───────────────────────────────────────
    final isSummary = lowerQ.contains('summar') ||
        lowerQ.contains('overview') ||
        lowerQ.contains('what is this') ||
        lowerQ.contains('what is the') ||
        lowerQ.contains('what is it') ||
        lowerQ.contains('what is doc') ||
        lowerQ.contains('what is document') ||
        lowerQ.contains('explain') ||
        lowerQ.contains('tell me about') ||
        lowerQ.contains('tell me') ||
        lowerQ.contains('main topic') ||
        lowerQ.contains('tldr') ||
        lowerQ.contains('about the') ||
        lowerQ == 'what is' ||
        queryWords.isEmpty;

    if (isSummary) {
      final buffer = StringBuffer();
      buffer.writeln('Document Summary:\n');
      final seen = <String>{};
      int pointCount = 0;
      final blankFields = <String>[];

      for (final chunk in chunks) {
        final sentences = _splitSentences(chunk.text);
        for (final sentence in sentences) {
          final s = sentence.trim();
          if (s.length < 3 || seen.contains(s.toLowerCase())) continue;
          seen.add(s.toLowerCase());

          if (s.contains(':')) {
            final idx = s.indexOf(':');
            final k = s.substring(0, idx).trim();
            final v = s.substring(idx + 1).trim();

            if (v.isEmpty) {
              if (k.isNotEmpty && !blankFields.contains(k)) {
                blankFields.add(k);
              }
              continue;
            }
            buffer.writeln('• $k: $v');
            pointCount++;
          } else {
            // Skip noisy OCR fragments (pure numbers or tiny symbols)
            if (s.length < 4 || RegExp(r'^[0-9./_\- ]+$').hasMatch(s)) continue;
            buffer.writeln('• $s');
            pointCount++;
          }
          if (pointCount >= 8) break;
        }
        if (pointCount >= 8) break;
      }

      if (blankFields.isNotEmpty) {
        buffer.writeln('\nUnfilled form fields: ${blankFields.join(', ')}');
      }

      if (pointCount == 0 && blankFields.isEmpty) {
        buffer.writeln(chunks.first.text.trim());
      }
      final pages = chunks.map((c) => c.pageNumber).toSet();
      buffer.writeln('\nSource: Page ${pages.join(', ')}');
      return buffer.toString().trim();
    }

    // ── Question-specific answer ────────────────────────────────────────────
    // Detect if this is an explicit entity / person lookup query (e.g., "Is there anyone named rajiv", "Who is Samuel", "find 5024101")
    final isEntityLookup = lowerQ.contains('anyone named') ||
        lowerQ.contains('someone named') ||
        lowerQ.contains('person named') ||
        lowerQ.startsWith('who is') ||
        lowerQ.startsWith('find ');

    // Score each line/sentence in all chunks
    final List<_ScoredSentence> scored = [];
    for (final chunk in chunks) {
      final sentences = _splitSentences(chunk.text);
      for (final sentence in sentences) {
        final sLower = sentence.toLowerCase();
        double hits = 0.0;

        for (final word in queryWords) {
          if (sLower.contains(word)) {
            // Whole-word match bonus
            final isWord = RegExp(r'\b' + RegExp.escape(word) + r'\b').hasMatch(sLower);
            hits += isWord ? 3.0 : 1.5;
          }
        }

        // Exact query terms combination match
        if (queryWords.isNotEmpty && queryWords.every((w) => sLower.contains(w))) {
          hits += 5.0;
        }

        // Exact question phrase match bonus
        if (lowerQ.length > 3 && sLower.contains(lowerQ)) {
          hits += 8.0;
        }

        // Form field bonus (Key: Value structure)
        if (hits > 0 && sentence.contains(':')) {
          hits += 2.0;
        }

        if (hits > 0) {
          scored.add(_ScoredSentence(
            sentence: sentence.trim(),
            score: hits,
            page: chunk.pageNumber,
          ));
        }
      }
    }

    // Sort by relevance score descending
    scored.sort((a, b) => b.score.compareTo(a.score));

    // If no sentence scored and user specifically asked for an entity/person
    if (scored.isEmpty) {
      if (isEntityLookup) {
        final searchedTerms = queryWords.isNotEmpty ? queryWords.join(', ') : question;
        return 'I searched the document, but could not find any entry or person matching "$searchedTerms".';
      }

      // General question with low exact match: provide helpful document overview and excerpt
      final buffer = StringBuffer();
      final terms = queryWords.isNotEmpty ? queryWords.join(' ') : question;
      buffer.writeln('I could not find a specific section directly mentioning "$terms". Here is what the document covers:\n');
      final sentences = _splitSentences(chunks.first.text);
      int added = 0;
      for (final s in sentences) {
        final clean = s.trim();
        if (clean.length > 4 && !RegExp(r'^[0-9./_\- ]+$').hasMatch(clean)) {
          buffer.writeln('• $clean');
          added++;
          if (added >= 5) break;
        }
      }
      final pages = chunks.map((c) => c.pageNumber).toSet();
      buffer.writeln('\nSource: Page ${pages.join(', ')}');
      return buffer.toString().trim();
    }

    final buffer = StringBuffer();
    final usedSentences = <String>{};
    int added = 0;

    buffer.writeln('Based on the document:\n');
    for (final s in scored) {
      final clean = s.sentence;
      if (clean.length < 3 || usedSentences.contains(clean.toLowerCase())) continue;
      usedSentences.add(clean.toLowerCase());

      if (clean.contains(':')) {
        final idx = clean.indexOf(':');
        final k = clean.substring(0, idx).trim();
        final v = clean.substring(idx + 1).trim();

        if (v.isEmpty) {
          final keyWords = k.toLowerCase().split(RegExp(r'[^a-zA-Z0-9]+'));
          if (keyWords.any((kw) => queryWords.contains(kw))) {
            buffer.writeln('• The $k field is present on Page ${s.page}, but it is blank / not filled in.');
            added++;
          }
          continue;
        }

        buffer.writeln('• $k: $v');
        added++;
      } else {
        buffer.writeln('• $clean');
        added++;
      }

      if (added >= 5) break;
    }

    // Fallback only if no specific entity was searched
    if (added == 0) {
      if (isEntityLookup) {
        final term = queryWords.join(' ');
        return 'I could not find "$term" mentioned in the document.';
      }
      final sentences = _splitSentences(chunks.first.text);
      buffer.writeln('Relevant excerpt from the document:\n');
      for (final s in sentences.take(4)) {
        if (s.trim().length > 10) {
          buffer.writeln('• ${s.trim()}');
          added++;
        }
      }
      if (added == 0) {
        buffer.writeln(chunks.first.text.trim());
      }
    }

    // Citation footer
    final pages = scored.take(3).map((s) => s.page).toSet();
    if (pages.isEmpty) pages.add(chunks.first.pageNumber);
    buffer.writeln('\nSource: Page ${pages.join(', ')}');

    return buffer.toString().trim();
  }

  /// Splits text into individual sentences or form lines on \n or . ! ? boundaries.
  /// Preserves key-value form lines and abbreviations without breaking them.
  List<String> _splitSentences(String text) {
    final lines = text.split(RegExp(r'\r?\n+'));
    final results = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // If the line is a key-value form line, preserve it completely
      if (trimmed.contains(':')) {
        results.add(trimmed);
        continue;
      }

      // Protect honorifics and abbreviations from being split
      String protected = trimmed
          .replaceAll(RegExp(r'\bMr\.\s+', caseSensitive: false), 'Mr__SPACE__')
          .replaceAll(RegExp(r'\bMrs\.\s+', caseSensitive: false), 'Mrs__SPACE__')
          .replaceAll(RegExp(r'\bMs\.\s+', caseSensitive: false), 'Ms__SPACE__')
          .replaceAll(RegExp(r'\bDr\.\s+', caseSensitive: false), 'Dr__SPACE__')
          .replaceAll(RegExp(r'\bProf\.\s+', caseSensitive: false), 'Prof__SPACE__')
          .replaceAll(RegExp(r'\bFr\.\s+', caseSensitive: false), 'Fr__SPACE__')
          .replaceAll(RegExp(r'\bSr\.\s+', caseSensitive: false), 'Sr__SPACE__')
          .replaceAll(RegExp(r'\bNo\.\s+', caseSensitive: false), 'No__SPACE__')
          .replaceAll(RegExp(r'\be\.g\.\s+', caseSensitive: false), 'eg__SPACE__')
          .replaceAll(RegExp(r'\bi\.e\.\s+', caseSensitive: false), 'ie__SPACE__');

      final subs = protected.split(RegExp(r'(?<=[.!?])\s+'));
      for (final s in subs) {
        final restored = s
            .replaceAll('Mr__SPACE__', 'Mr. ')
            .replaceAll('Mrs__SPACE__', 'Mrs. ')
            .replaceAll('Ms__SPACE__', 'Ms. ')
            .replaceAll('Dr__SPACE__', 'Dr. ')
            .replaceAll('Prof__SPACE__', 'Prof. ')
            .replaceAll('Fr__SPACE__', 'Fr. ')
            .replaceAll('Sr__SPACE__', 'Sr. ')
            .replaceAll('No__SPACE__', 'No. ')
            .replaceAll('eg__SPACE__', 'e.g. ')
            .replaceAll('ie__SPACE__', 'i.e. ')
            .trim();
        if (restored.isNotEmpty) {
          results.add(restored);
        }
      }
    }
    return results;
  }


  /// Validates citations against actual retrieved page metadata to prevent hallucinated references.
  List<SourceCitation> _extractAndValidateCitations({
    required String answer,
    required List<DocumentChunk> availableChunks,
  }) {
    final Map<int, DocumentChunk> pageToChunk = {};
    for (final c in availableChunks) {
      pageToChunk[c.pageNumber] = c;
    }

    final validPageNumbers = pageToChunk.keys.toSet();
    final Set<int> citedPages = {};

    // Match patterns like "Page 3", "page 3", "[Page 3]", "Source: Page 3"
    final regex = RegExp(r'(?:(?:Source:?\s*)?(?:\[\s*)?Page\s*(\d+)(?:\s*\])?)', caseSensitive: false);
    final matches = regex.allMatches(answer);

    for (final m in matches) {
      final pageNumStr = m.group(1);
      if (pageNumStr != null) {
        final pageNum = int.tryParse(pageNumStr);
        if (pageNum != null && validPageNumbers.contains(pageNum)) {
          citedPages.add(pageNum);
        }
      }
    }

    // If no explicit page citation was detected in text, default to the top retrieved chunks
    if (citedPages.isEmpty) {
      for (final c in availableChunks.take(2)) {
        citedPages.add(c.pageNumber);
      }
    }

    final List<SourceCitation> citations = [];
    for (final page in citedPages) {
      final chunk = pageToChunk[page];
      final snippet = chunk != null && chunk.text.length > 120
          ? '${chunk.text.substring(0, 120)}...'
          : (chunk?.text ?? '');

      citations.add(
        SourceCitation(
          pageNumber: page,
          snippet: snippet,
          isVerified: true,
          relevanceScore: chunk?.score ?? 1.0,
        ),
      );
    }

    citations.sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
    return citations;
  }

  void dispose() {
    _provider.dispose();
  }
}
