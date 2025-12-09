import 'dart:typed_data';

Future<String> uploadBytes(Uint8List data, String path, {String? contentType}) async {
  throw UnsupportedError('File upload support was removed.');
}

Future<String> uploadFileFromPath(String localPath, String path, {String? contentType}) async {
  throw UnsupportedError('File upload support was removed.');
}
