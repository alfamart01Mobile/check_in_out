import 'package:FaceNetAuthentication/views/loginView.dart';
import 'package:flutter/material.dart';
import 'package:FaceNetAuthentication/config/constant.dart';
import 'package:FaceNetAuthentication/views/home.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';

Future<void> main() async {
  runApp(Phoenix(child: MyApp()));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "APP_TITLE",
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      home: ISADMIN == 1 ? LoginPage() : Home(),
    );
  }
}
