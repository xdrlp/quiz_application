import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadProfileImage(String userId, Uint8List iconBytes) async {
    try {
      final ref = _storage.ref().child('user_profiles').child('$userId.jpg');
      
      // Ensure the file is treated as a JPEG
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'userId': userId},
      );

      await ref.putData(iconBytes, metadata);
      return await ref.getDownloadURL();
    } catch (e) {
      rethrow;
    }
  }
}
