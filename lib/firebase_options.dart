import 'package:firebase_core/firebase_core.dart';

/// Firebase configuration for the CAC web application.
///
/// Native platforms continue to read their configuration from their bundled
/// Google service files.
abstract final class DefaultFirebaseOptions {
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBEKcBs39KbIii-Hcpj4feYGTMQvL29ORU',
    appId: '1:958809412045:web:226158a702998a63c57484',
    messagingSenderId: '958809412045',
    projectId: 'cacapp-3a771',
    authDomain: 'cacapp-3a771.firebaseapp.com',
    storageBucket: 'cacapp-3a771.firebasestorage.app',
  );
}
