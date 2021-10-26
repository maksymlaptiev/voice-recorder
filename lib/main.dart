import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:routines_app/app/home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseOptions firebaseOptions = FirebaseOptions(
    appId: '1:924219822273:android:19ed432f79242c0d9ec440',
    apiKey: 'AIzaSyDzqSFJ9g79XwR4YfviNZLo9bt7esGmsN4',
    projectId: 'fcmessaging-f46ae',
    messagingSenderId: '924219822273',
  );
  final FirebaseApp app =
      await Firebase.initializeApp(options: firebaseOptions);
  print("app is : $app");
  runApp(MyApp(app: app));
}

class MyApp extends StatelessWidget {
  final FirebaseApp app;
  const MyApp({Key? key, required this.app}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Home(app: this.app),
    );
  }
}
