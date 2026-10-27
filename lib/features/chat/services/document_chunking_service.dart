import '../models/document_chunk.dart';
import '../models/extracted_document_text.dart';

class DocumentChunkingService {
  static const int defaultMaxChunkCharacters = 450;
  static const int defaultOverlapCharacters = 75;

  /// Chunks an extracted document into overlapping text segments with preserved 1-based page numbers.
  List<DocumentChunk> chunkDocument(
    ExtractedDocumentText document, {
    int maxChunkChars = defaultMaxChunkCharacters,
    int overlapChars = defaultOverlapCharacters,
  }) {
    final List<DocumentChunk> allChunks = [];
    int chunkCounter = 0;

    for (final page in document.pages) {
      final normalized = normalizeText(page.text);
      if (normalized.trim().isEmpty) continue;

      final pageChunks = _chunkPageText(
        text: normalized,
        documentId: document.documentId,
        pageNumber: page.pageNumber,
        startIndex: chunkCounter,
        maxChunkChars: maxChunkChars,
        overlapChars: overlapChars,
      );

      chunkCounter += pageChunks.length;
      allChunks.addAll(pageChunks);
    }

    return allChunks;
  }

  /// Normalizes whitespace and standardizes line breaks without stripping mathematical symbols, formulas, or headings.
  String normalizeText(String raw) {
    if (raw.isEmpty) return '';

    // Replace carriage returns
    String text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Replace multiple empty lines with a double newline to preserve paragraph boundaries
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // Normalize horizontal whitespace (tabs, multiple spaces) while keeping line structure
    text = text.replaceAll(RegExp(r'[ \t]{2,}'), ' ');

    return text.trim();
  }

  List<DocumentChunk> _chunkPageText({
    required String text,
    required String documentId,
    required int pageNumber,
    required int startIndex,
    required int maxChunkChars,
    required int overlapChars,
  }) {
    final List<DocumentChunk> chunks = [];

    // If page is short, keep as single chunk
    if (text.length <= maxChunkChars) {
      chunks.add(
        DocumentChunk(
          chunkId: '${documentId}_p${pageNumber}_c$startIndex',
          documentId: documentId,
          pageNumber: pageNumber,
          text: text,
          tokenEstimate: (text.length / 4).ceil(),
        ),
      );
      return chunks;
    }

    // Split page text into paragraphs
    final paragraphs = text.split('\n\n');
    String currentBuffer = '';
    int localIndex = startIndex;

    for (final para in paragraphs) {
      final trimmedPara = para.trim();
      if (trimmedPara.isEmpty) continue;

      if (currentBuffer.isEmpty) {
        currentBuffer = trimmedPara;
      } else if (currentBuffer.length + trimmedPara.length + 2 <= maxChunkChars) {
        currentBuffer += '\n\n$trimmedPara';
      } else {
        // Buffer is full, emit chunk
        chunks.add(
          DocumentChunk(
            chunkId: '${documentId}_p${pageNumber}_c$localIndex',
            documentId: documentId,
            pageNumber: pageNumber,
            text: currentBuffer,
            tokenEstimate: (currentBuffer.length / 4).ceil(),
          ),
        );
        localIndex++;

        // Add overlap from end of previous buffer
        final overlap = currentBuffer.length > overlapChars
            ? currentBuffer.substring(currentBuffer.length - overlapChars)
            : currentBuffer;

        currentBuffer = '$overlap\n\n$trimmedPara';
      }
    }

    // Emit remaining buffer
    if (currentBuffer.isNotEmpty) {
      chunks.add(
        DocumentChunk(
          chunkId: '${documentId}_p${pageNumber}_c$localIndex',
          documentId: documentId,
          pageNumber: pageNumber,
          text: currentBuffer,
          tokenEstimate: (currentBuffer.length / 4).ceil(),
        ),
      );
    }

    return chunks;
  }
}
