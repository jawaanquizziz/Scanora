import 'dart:math';
import '../models/document_chunk.dart';

class DocumentRetrievalService {
  static const double k1 = 1.2;
  static const double b = 0.75;

  static const Set<String> _stopwords = {
    'a', 'about', 'above', 'after', 'again', 'against', 'all', 'am', 'an', 'and',
    'any', 'are', 'aren\'t', 'as', 'at', 'be', 'because', 'been', 'before', 'being',
    'below', 'between', 'both', 'but', 'by', 'can', 'can\'t', 'cannot', 'could',
    'couldn\'t', 'did', 'didn\'t', 'do', 'does', 'doesn\'t', 'doing', 'don\'t',
    'down', 'during', 'each', 'few', 'for', 'from', 'further', 'had', 'hadn\'t',
    'has', 'hasn\'t', 'have', 'haven\'t', 'having', 'he', 'he\'d', 'he\'ll', 'he\'s',
    'her', 'here', 'here\'s', 'hers', 'herself', 'him', 'himself', 'his', 'how',
    'how\'s', 'i', 'i\'d', 'i\'ll', 'i\'m', 'i\'ve', 'if', 'in', 'into', 'is',
    'isn\'t', 'it', 'it\'s', 'its', 'itself', 'let\'s', 'me', 'more', 'most',
    'mustn\'t', 'my', 'myself', 'no', 'nor', 'not', 'of', 'off', 'on', 'once',
    'only', 'or', 'other', 'ought', 'our', 'ours', 'ourselves', 'out', 'over',
    'own', 'same', 'shan\'t', 'she', 'she\'d', 'she\'ll', 'she\'s', 'should',
    'shouldn\'t', 'so', 'some', 'such', 'than', 'that', 'that\'s', 'the', 'their',
    'theirs', 'them', 'themselves', 'then', 'there', 'there\'s', 'these', 'they',
    'they\'d', 'they\'ll', 'they\'re', 'they\'ve', 'this', 'those', 'through',
    'to', 'too', 'under', 'until', 'up', 'very', 'was', 'wasn\'t', 'we', 'we\'d',
    'we\'ll', 'we\'re', 'we\'ve', 'were', 'weren\'t', 'what', 'what\'s', 'when',
    'when\'s', 'where', 'where\'s', 'which', 'while', 'who', 'who\'s', 'whom',
    'why', 'why\'s', 'with', 'won\'t', 'would', 'wouldn\'t', 'you', 'you\'d',
    'you\'ll', 'you\'re', 'you\'ve', 'your', 'yours', 'yourself', 'yourselves',
    // Document meta-words
    'document', 'doc', 'docs', 'documents', 'pdf', 'file', 'content', 'contents',
    'page', 'pages', 'scan', 'scanned', 'paper', 'text',
  };

  /// Tokenizes a string into lowercased terms.
  List<String> tokenize(String text, {bool filterStopwords = true}) {
    final matches = RegExp(r'[a-zA-Z0-9_\-]+').allMatches(text.toLowerCase());
    final tokens = <String>[];
    for (final m in matches) {
      final term = m.group(0)!;
      if (term.length > 1 && (!filterStopwords || !_stopwords.contains(term))) {
        tokens.add(term);
      }
    }
    return tokens;
  }

  /// Retrieves the top-k most relevant chunks for [query] from [chunks] using BM25 ranking.
  List<DocumentChunk> retrieve({
    required String query,
    required List<DocumentChunk> chunks,
    int topK = 4,
    int maxTotalCharacters = 2500,
  }) {
    if (chunks.isEmpty) return [];

    final queryTerms = tokenize(query);
    final isSummaryQuery = _isSummaryOrOverviewQuery(query) || queryTerms.isEmpty;

    // If it's a general summary query without specific search terms, return the opening chunks
    if (isSummaryQuery && queryTerms.isEmpty) {
      return chunks.take(topK).toList();
    }

    final int totalDocs = chunks.length;
    final Map<int, List<String>> chunkTokens = {};
    int totalWords = 0;

    for (int i = 0; i < totalDocs; i++) {
      final tokens = tokenize(chunks[i].text, filterStopwords: false);
      chunkTokens[i] = tokens;
      totalWords += tokens.length;
    }

    final double avgDocLength = totalDocs > 0 ? totalWords / totalDocs : 1.0;

    // Document frequencies for query terms
    final Map<String, int> docFreq = {};
    for (final term in queryTerms) {
      int count = 0;
      for (int i = 0; i < totalDocs; i++) {
        if (chunkTokens[i]!.contains(term)) {
          count++;
        }
      }
      docFreq[term] = count;
    }

    // Score each chunk
    final List<DocumentChunk> scoredChunks = [];
    final lowerQuery = query.toLowerCase().trim();

    for (int i = 0; i < totalDocs; i++) {
      final chunk = chunks[i];
      final tokens = chunkTokens[i]!;
      final docLen = tokens.length;

      // Term frequencies in this chunk
      final Map<String, int> termFreq = {};
      for (final t in tokens) {
        termFreq[t] = (termFreq[t] ?? 0) + 1;
      }

      double score = 0.0;
      for (final term in queryTerms) {
        final tf = termFreq[term] ?? 0;
        if (tf == 0) continue;

        final df = docFreq[term] ?? 0;
        // IDF with smoothing
        final idf = log(1.0 + (totalDocs - df + 0.5) / (df + 0.5));
        final tfComponent = (tf * (k1 + 1)) / (tf + k1 * (1 - b + b * (docLen / avgDocLength)));
        score += idf * tfComponent;
      }

      // Boost for exact phrase match
      if (lowerQuery.length > 3 && chunk.text.toLowerCase().contains(lowerQuery)) {
        score += 3.0;
      }

      // Boost for first page if asking for summary/overview
      if (isSummaryQuery && chunk.pageNumber == 1) {
        score += 1.5;
      }

      scoredChunks.add(chunk.copyWith(score: score));
    }

    // Sort by score descending
    scoredChunks.sort((a, b) => b.score.compareTo(a.score));

    // Filter to positive scores, or take first few if it's a summary or general question
    List<DocumentChunk> results = scoredChunks.where((c) => c.score > 0.05).toList();
    if (results.isEmpty) {
      if (isSummaryQuery) {
        results = scoredChunks.isNotEmpty ? scoredChunks.take(topK).toList() : chunks.take(topK).toList();
      } else {
        results = [];
      }
    }

    // Limit by topK and total character budget
    final List<DocumentChunk> budgeted = [];
    int currentChars = 0;

    for (final c in results.take(topK)) {
      if (currentChars + c.text.length > maxTotalCharacters && budgeted.isNotEmpty) {
        break;
      }
      budgeted.add(c);
      currentChars += c.text.length;
    }

    return budgeted;
  }

  bool _isSummaryOrOverviewQuery(String query) {
    final lower = query.toLowerCase().trim();
    return lower.contains('summar') ||
        lower.contains('overview') ||
        lower.contains('about') ||
        lower.contains('what is this') ||
        lower.contains('what is the') ||
        lower.contains('what is doc') ||
        lower.contains('what is document') ||
        lower.contains('what is it') ||
        lower == 'what is' ||
        lower.contains('main topic') ||
        lower.contains('tldr') ||
        lower.contains('explain') ||
        lower.contains('tell me');
  }
}
