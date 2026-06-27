// Stub for non-web platforms – these functions are never called
// because kIsWeb is false, but the signatures must exist.

void downloadFileWeb(List<int> bytes, String fileName, String mimeType) {
  throw UnsupportedError('downloadFileWeb is only supported on web');
}
