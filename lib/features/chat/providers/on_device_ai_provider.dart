abstract class OnDeviceAIProvider {
  bool get isReady;

  Future<bool> isPlatformSupported();

  Future<void> initialize({
    required String modelPath,
    void Function(String status, double progress)? onProgress,
  });

  Future<String> generateAnswer({
    required String prompt,
    void Function(String token)? onToken,
  });

  void dispose();
}
