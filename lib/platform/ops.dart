// 平台操作：按编译目标选择实现。
export 'ops_stub.dart' if (dart.library.io) 'ops_io.dart' if (dart.library.js_interop) 'ops_web.dart';
