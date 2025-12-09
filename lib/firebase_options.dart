import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Platform      FirebaseOptions
/// web           firebase.google.com/docs/web/setup#config-object
/// android       firebase.google.com/docs/android/setup#configure_firebase_sdk
/// ios           firebase.google.com/docs/ios/setup#configure_firebase_sdk
/// macos         firebase.google.com/docs/ios/setup#configure_firebase_sdk
/// windows       firebase.google.com/docs/web/setup#config-object
/// linux         firebase.google.com/docs/web/setup#config-object
///
/// Update these Firebase configuration values with your own
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC6h-ELrDC9iAGOZjJ4-6sa5wlDHy9IRPg',
    appId: '1:1033751174368:web:d43edc44db0776a3018485',
    messagingSenderId: '1033751174368',
    projectId: 'quiz-application-66822',
    authDomain: 'quiz-application-66822.firebaseapp.com',
    storageBucket: 'quiz-application-66822.firebasestorage.app',
    measurementId: 'G-BWZY9594X1',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDnd3kcE-aTlV41Va6GQo27DFqzNROibk4',
    appId: '1:1033751174368:android:9d9d1db9f242a13b018485',
    messagingSenderId: '1033751174368',
    projectId: 'quiz-application-66822',
    storageBucket: 'quiz-application-66822.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBBjU2V4HB2wSRbAC5jo_lRBqAzQ7fJB04',
    appId: '1:1033751174368:ios:94bb58513cfc552f018485',
    messagingSenderId: '1033751174368',
    projectId: 'quiz-application-66822',
    storageBucket: 'quiz-application-66822.firebasestorage.app',
    iosBundleId: 'com.example.quizApplication',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBBjU2V4HB2wSRbAC5jo_lRBqAzQ7fJB04',
    appId: '1:1033751174368:ios:94bb58513cfc552f018485',
    messagingSenderId: '1033751174368',
    projectId: 'quiz-application-66822',
    storageBucket: 'quiz-application-66822.firebasestorage.app',
    iosBundleId: 'com.example.quizApplication',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyC6h-ELrDC9iAGOZjJ4-6sa5wlDHy9IRPg',
    appId: '1:1033751174368:web:7a3537a5f90f0bd3018485',
    messagingSenderId: '1033751174368',
    projectId: 'quiz-application-66822',
    authDomain: 'quiz-application-66822.firebaseapp.com',
    storageBucket: 'quiz-application-66822.firebasestorage.app',
    measurementId: 'G-MB35XL6F62',
  );

}