import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'on_device_ai_provider.dart';

/// Provider for local on-device inference using llama_cpp_dart.
///
/// Executes GGUF models (e.g. SmolLM2, Llama, Qwen) inside a background isolate
/// via [LlamaParent] without blocking the Flutter UI thread.
class LlamafuAIProvider implements OnDeviceAIProvider {
  bool _isReady = false;
  bool _isInitializing = false;
  String? _modelPath;
  LlamaParent? _llamaParent;

  @override
  bool get isReady => _isReady && _llamaParent != null;

  String? get modelPath => _modelPath;

  @override
  Future<bool> isPlatformSupported() async {
    if (kIsWeb) return false;
    // Android is verified with bundled libmtmd.so!
    // iOS and macOS are also supported.
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  @override
  Future<void> initialize({
    required String modelPath,
    void Function(String status, double progress)? onProgress,
  }) async {
    if (_isReady && _llamaParent != null) return;
    if (_isInitializing) return;

    final file = File(modelPath);
    if (!await file.exists()) {
      throw FileNotFoundException('GGUF Model file does not exist at: $modelPath');
    }

    _isInitializing = true;
    onProgress?.call('Loading Llama model into memory...', 0.3);

    try {
      final modelParams = ModelParams()..nGpuLayers = 0; // CPU is safest and most compatible
      final contextParams = ContextParams()
        ..nCtx = 2048
        ..nPredict = 512
        ..nBatch = 512
        ..nThreads = 4;
      final samplerParams = SamplerParams()
        ..temp = 0.7
        ..topP = 0.9;

      final loadCmd = LlamaLoad(
        path: modelPath,
        modelParams: modelParams,
        contextParams: contextParams,
        samplingParams: samplerParams,
      );

      final parent = LlamaParent(loadCmd);
      onProgress?.call('Starting AI background engine...', 0.7);
      await parent.init();

      _llamaParent = parent;
      _modelPath = modelPath;
      _isReady = true;
      onProgress?.call('Llama AI Ready', 1.0);
    } catch (e, stack) {
      debugPrint('Error initializing Llama engine: $e\n$stack');
      _isReady = false;
      try {
        await _llamaParent?.dispose();
      } catch (_) {}
      _llamaParent = null;
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  @override
  Future<String> generateAnswer({
    required String prompt,
    void Function(String token)? onToken,
  }) async {
    final parent = _llamaParent;
    if (!_isReady || parent == null) {
      throw StateError('Model is not initialized. Call initialize() first.');
    }

    final buffer = StringBuffer();
    final sub = parent.stream.listen((token) {
      buffer.write(token);
      onToken?.call(token);
    });

    try {
      final promptId = await parent.sendPrompt(prompt);
      await parent.waitForCompletion(promptId).timeout(
        const Duration(seconds: 45),
        onTimeout: () => '',
      );
      final result = buffer.toString().trim();
      return result.isNotEmpty ? result : 'I could not generate an answer for this document.';
    } finally {
      await sub.cancel();
    }
  }

  @override
  void dispose() {
    _isReady = false;
    _modelPath = null;
    try {
      _llamaParent?.dispose();
    } catch (_) {}
    _llamaParent = null;
  }
}

class FileNotFoundException implements Exception {
  final String message;
  FileNotFoundException(this.message);
  @override
  String toString() => message;
}
