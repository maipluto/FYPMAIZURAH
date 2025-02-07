import 'package:flutter/material.dart';
import 'package:intellifruit/page/welcome_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IntelliFruit',
      home: WelcomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
