// Conditional import: use web JS interop on web, stub on other platforms
export 'web_js_interop_stub.dart'
    if (dart.library.js_interop) 'web_js_interop.dart';
