import 'package:firebase_core/firebase_core.dart';

class FirebaseConfig {
  // Set to true to use real Firebase, false for local mock data
  static const bool useFirebase = true;

  // Firebase Android credentials from google-services.json
  static const FirebaseOptions androidOptions = FirebaseOptions(
    apiKey: 'AIzaSyCXdjL45zm9Dj7XraOnYzqSjI6XsvIbodc',
    appId: '1:461659639574:android:52293dcd5c1139f6f94a37',
    messagingSenderId: '461659639574',
    projectId: 'church-inventory-12bb1',
    storageBucket: 'church-inventory-12bb1.firebasestorage.app',
  );
}
