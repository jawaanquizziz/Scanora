import 'source_citation.dart';

enum MessageSender { user, assistant, system }

class ChatMessage {
  final String id;
  final String documentId;
  final MessageSender sender;
  final String content;
  final DateTime timestamp;
  final List<SourceCitation> citations;
  final bool isError;
  final bool isGenerating;

  const ChatMessage({
    required this.id,
    required this.documentId,
    required this.sender,
    required this.content,
    required this.timestamp,
    this.citations = const [],
    this.isError = false,
    this.isGenerating = false,
  });

  ChatMessage copyWith({
    String? id,
    String? documentId,
    MessageSender? sender,
    String? content,
    DateTime? timestamp,
    List<SourceCitation>? citations,
    bool? isError,
    bool? isGenerating,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      sender: sender ?? this.sender,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      citations: citations ?? this.citations,
      isError: isError ?? this.isError,
      isGenerating: isGenerating ?? this.isGenerating,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'documentId': documentId,
    'sender': sender.name,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    'citations': citations.map((c) => c.toJson()).toList(),
    'isError': isError,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String? ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
    documentId: json['documentId'] as String? ?? '',
    sender: MessageSender.values.firstWhere(
      (e) => e.name == json['sender'],
      orElse: () => MessageSender.assistant,
    ),
    content: json['content'] as String? ?? '',
    timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    citations: (json['citations'] as List<dynamic>?)
            ?.map((e) => SourceCitation.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    isError: json['isError'] as bool? ?? false,
    isGenerating: false,
  );
}
