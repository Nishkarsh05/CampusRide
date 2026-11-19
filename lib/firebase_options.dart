import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class CampusRideFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('CampusRide is configured for Android.');
    }
    if (defaultTargetPlatform == TargetPlatform.android) return android;
    throw UnsupportedError('CampusRide is configured for Android.');
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDPl6uRrd7wWqISFFRDU1Vy8PQqztEww8w',
    appId: '1:679503535181:android:e27b83a5f904f2a3939004',
    messagingSenderId: '679503535181',
    projectId: 'campusride-89b00',
    databaseURL: 'https://campusride-89b00-default-rtdb.firebaseio.com',
    storageBucket: 'campusride-89b00.firebasestorage.app',
  );
}
