import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

 class App extends StatelessWidget {
   const App({super.key});

   @override
    Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VYO Fitness',
      theme: ThemeData.dark(),
      home: const Scaffold(
        body: Center(
          child: Text('VYO Fitness'),
        ),
      ),
    );
  }
 }