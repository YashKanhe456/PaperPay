import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCb2At1wQRhLgk40LaynKqbM_s1vGILTpg',
    appId: '1:59403709791:web:28d0368c3dcaba48469aea',
    messagingSenderId: '59403709791',
    projectId: 'paperpay-24bbf',
    authDomain: 'paperpay-24bbf.firebaseapp.com',
    storageBucket: 'paperpay-24bbf.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBhqib1ubFde1p-D1AwUHTL50qs5dgwyRw',
    appId: '1:59403709791:android:d648a8f85d2ed61a469aea',
    messagingSenderId: '59403709791',
    projectId: 'paperpay-24bbf',
    storageBucket: 'paperpay-24bbf.firebasestorage.app',
  );
}
