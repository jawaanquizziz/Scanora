import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';

class DocumentChatRepository {
  static const String _prefix = 'scanora_chat_history_';

  String _getKey(String docId) => '$_prefix$docId';

  Future<List<ChatMessage>> getMessages(String docId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_getKey(docId));
    if (jsonStr == null || jsonStr.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveMessages(String docId, List<ChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(messages.map((m) => m.toJson()).toList());
    await prefs.setString(_getKey(docId), jsonStr);
  }

  Future<void> clearMessages(String docId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getKey(docId));
  }
}
