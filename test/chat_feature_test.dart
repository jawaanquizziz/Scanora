import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanora/features/chat/models/document_chunk.dart';
import 'package:scanora/features/chat/models/extracted_document_text.dart';
import 'package:scanora/features/chat/screens/pdf_citation_viewer_screen.dart';
import 'package:scanora/features/chat/services/document_chunking_service.dart';
import 'package:scanora/features/chat/services/document_retrieval_service.dart';
import 'package:scanora/features/chat/services/on_device_ai_service.dart';
import 'package:scanora/models/scanned_document.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return '.';
      },
    );
  });

  group('DocumentChunkingService Tests', () {
    final chunkingService = DocumentChunkingService();

    test('Preserves 1-based page numbers and document ID', () {
      final doc = ExtractedDocumentText(
        documentId: 'doc_101',
        filePath: '/test/path.pdf',
        totalPages: 2,
        extractedAt: DateTime.now(),
        fileModifiedTimestamp: 123456,
        pages: const [
          ExtractedPageText(
            pageNumber: 1,
            text: 'Chapter 1: Introduction to Physics. Energy is conserved in an isolated system.',
          ),
          ExtractedPageText(
            pageNumber: 2,
            text: 'Chapter 2: Quantum mechanics. Wave-particle duality of light and matter.',
          ),
        ],
      );

      final chunks = chunkingService.chunkDocument(doc);
      expect(chunks.length, 2);
      expect(chunks[0].pageNumber, 1);
      expect(chunks[0].documentId, 'doc_101');
      expect(chunks[1].pageNumber, 2);
      expect(chunks[1].documentId, 'doc_101');
    });

    test('Normalizes text while preserving formulas and line structure', () {
      const raw = 'Einstein Formula:\r\n\r\nE = mc^2\n\n\n\nWhere   m   is mass.';
      final normalized = chunkingService.normalizeText(raw);
      expect(normalized.contains('E = mc^2'), isTrue);
      expect(normalized.contains('\r'), isFalse);
      expect(normalized.contains('\n\n\n'), isFalse);
    });

    test('Splits large pages into overlapping chunks', () {
      final longText = List.generate(
        10,
        (i) => 'Section $i: This is a detailed paragraph discussing scientific topic number $i with plenty of relevant data points.',
      ).join('\n\n');

      final doc = ExtractedDocumentText(
        documentId: 'doc_long',
        filePath: '/test/long.pdf',
        totalPages: 1,
        extractedAt: DateTime.now(),
        fileModifiedTimestamp: 123456,
        pages: [
          ExtractedPageText(pageNumber: 1, text: longText),
        ],
      );

      final chunks = chunkingService.chunkDocument(doc, maxChunkChars: 200, overlapChars: 40);
      expect(chunks.length, greaterThan(1));
      for (final chunk in chunks) {
        expect(chunk.pageNumber, 1);
        expect(chunk.text.isNotEmpty, isTrue);
      }
    });
  });

  group('DocumentRetrievalService BM25 Tests', () {
    final retrievalService = DocumentRetrievalService();

    final testChunks = [
      const DocumentChunk(
        chunkId: 'c1',
        documentId: 'doc_bio',
        pageNumber: 1,
        text: 'Biology Overview: The cell is the basic structural and functional unit of all living organisms.',
      ),
      const DocumentChunk(
        chunkId: 'c2',
        documentId: 'doc_bio',
        pageNumber: 2,
        text: 'Photosynthesis: Process used by plants and other organisms to convert light energy into chemical energy.',
      ),
      const DocumentChunk(
        chunkId: 'c3',
        documentId: 'doc_bio',
        pageNumber: 3,
        text: 'Cellular Respiration: Metabolic reactions that take place in organisms to convert biochemical energy from nutrients into ATP.',
      ),
    ];

    test('Retrieves relevant chunks with high BM25 score', () {
      final results = retrievalService.retrieve(
        query: 'What is photosynthesis and how does light energy convert?',
        chunks: testChunks,
      );

      expect(results.isNotEmpty, isTrue);
      expect(results.first.pageNumber, 2);
      expect(results.first.text.contains('Photosynthesis'), isTrue);
    });

    test('Returns empty when answer is absent and score threshold is not met', () {
      final results = retrievalService.retrieve(
        query: 'quantum chromodynamics and quarks',
        chunks: testChunks,
      );

      expect(results.isEmpty, isTrue);
    });

    test('Handles summary queries by including opening overview chunks', () {
      final results = retrievalService.retrieve(
        query: 'Can you summarize this document for me?',
        chunks: testChunks,
      );

      expect(results.isNotEmpty, isTrue);
      expect(results.first.pageNumber, 1);
    });
  });

  group('OnDeviceAIService Grounded Answers & Citations Tests', () {
    final aiService = OnDeviceAIService();

    test('Generates clear refusal when no evidence chunks are found', () async {
      final result = await aiService.generateAnswer(
        question: 'What is the speed of sound?',
        retrievedChunks: const [],
      );

      expect(result.answer.contains('could not find relevant information'), isTrue);
      expect(result.citations.isEmpty, isTrue);
    });

    test('Generates grounded answer with validated source citation', () async {
      final chunk = const DocumentChunk(
        chunkId: 'chunk_1',
        documentId: 'doc_1',
        pageNumber: 4,
        text: 'Photosynthesis converts light energy into chemical energy.',
      );

      final result = await aiService.generateAnswer(
        question: 'What does photosynthesis do?',
        retrievedChunks: [chunk],
      );

      expect(result.answer.contains('Photosynthesis'), isTrue);
      expect(result.citations.isNotEmpty, isTrue);
      expect(result.citations.first.pageNumber, 4);
      expect(result.citations.first.isVerified, isTrue);
    });
  });

  group('ExtractedDocumentText Serialization Tests', () {
    test('Serializes to and from JSON preserving page data', () {
      final original = ExtractedDocumentText(
        documentId: 'doc_serial_1',
        filePath: '/storage/sample.pdf',
        totalPages: 2,
        extractedAt: DateTime(2026, 10, 20),
        fileModifiedTimestamp: 987654321,
        pages: const [
          ExtractedPageText(pageNumber: 1, text: 'First page text', isOcr: false),
          ExtractedPageText(pageNumber: 2, text: 'Second page OCR text', isOcr: true),
        ],
      );

      final json = original.toJson();
      final restored = ExtractedDocumentText.fromJson(json);

      expect(restored.documentId, original.documentId);
      expect(restored.filePath, original.filePath);
      expect(restored.totalPages, 2);
      expect(restored.pages.length, 2);
      expect(restored.pages[0].pageNumber, 1);
      expect(restored.pages[0].isOcr, isFalse);
      expect(restored.pages[1].pageNumber, 2);
      expect(restored.pages[1].isOcr, isTrue);
    });
  });

  group('PdfCitationViewerScreen Widget Tests', () {
    testWidgets('Renders citation banner and page header', (WidgetTester tester) async {
      final testDoc = ScannedDocument(
        id: 'test_doc_1',
        title: 'Biology Notes',
        filePath: 'non_existent_test.pdf',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        pageCount: 5,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PdfCitationViewerScreen(
            document: testDoc,
            targetPageNumber: 3,
            snippet: 'Photosynthesis converts light energy into chemical energy.',
          ),
        ),
      );

      expect(find.text('Page 3 Citation'), findsOneWidget);
      expect(find.text('Verified Source: Page 3 of 5'), findsOneWidget);
      expect(find.textContaining('Photosynthesis converts light energy'), findsOneWidget);
    });
  });
}
