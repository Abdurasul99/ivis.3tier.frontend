// lib/utils/stubs/js_stub.dart
library js_stub;

class JsContext {
  void callMethod(String method, List args) {}
}

JsContext get context => JsContext();

void allowInterop(Function f) {}
