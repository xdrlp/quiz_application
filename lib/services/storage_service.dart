import 'dart:typed_data';

import 'storage_service_io.dart'
    if (dart.library.html) 'storage_service_web.dart' as impl;

/// Upload raw bytes to storage and return download URL.
Future<String> uploadBytes(Uint8List data, String path, {String? contentType}) {
  return impl.uploadBytes(data, path, contentType: contentType);
}

/// Upload a local file (native only) from a path. On web this throws.
Future<String> uploadFileFromPath(String localPath, String path, {String? contentType}) {
  return impl.uploadFileFromPath(localPath, path, contentType: contentType);
}
