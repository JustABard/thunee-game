import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB1Wvmmnlt24HDhVbwWaML3aAZOvyiuh2g',
    appId: '1:122711594378:android:433d03517718e3beeb6473',
    messagingSenderId: '122711594378',
    projectId: 'thunne-game',
    storageBucket: 'thunne-game.firebasestorage.app',
    databaseURL: 'https://thunne-game-default-rtdb.europe-west1.firebasedatabase.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB6nGe5X8g6lbiFzggPGB3FfIeh7uKfFeM',
    appId: '1:122711594378:ios:3f546cce672b9d87eb6473',
    messagingSenderId: '122711594378',
    projectId: 'thunne-game',
    storageBucket: 'thunne-game.firebasestorage.app',
    databaseURL: 'https://thunne-game-default-rtdb.europe-west1.firebasedatabase.app',
    iosBundleId: 'com.justabard.thunee',
  );
}
