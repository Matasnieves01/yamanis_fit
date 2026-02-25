import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'features/home/presentation/home_page.dart';

 class App extends StatelessWidget {
   const App({super.key});

   @override
   Widget build(BuildContext context) {
     // TODO: implement build
     return MaterialApp(
       title: 'VYO Fitness',
       debugShowCheckedModeBanner: false,
       theme: ThemeData.dark(),

       home: const HomePage(),
     );
   }
 }