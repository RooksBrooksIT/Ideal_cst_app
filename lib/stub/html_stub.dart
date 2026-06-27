// Stub for dart:html – used on non-web platforms so the conditional
// import `if (dart.library.io) 'package:ideal_cst/stub/html_stub.dart'`
// compiles without errors on Android / iOS / Desktop.

class Blob {
  Blob(List<dynamic> parts, [String? type]);
}

class Url {
  static String createObjectUrlFromBlob(Blob blob) => '';
  static void revokeObjectUrl(String url) {}
}

class AnchorElement {
  AnchorElement({String? href});
  void setAttribute(String name, String value) {}
  void click() {}
}
