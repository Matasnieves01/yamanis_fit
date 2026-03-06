import 'package:flutter/material.dart';
import 'features/home/presentation/Client/home_page.dart';
import 'features/home/presentation/Client/main_navigation_bar.dart';
import 'features/home/presentation/Client/login_page.dart';

 class App extends StatelessWidget {
   const App({super.key});

   @override
   Widget build(BuildContext context) {
     // TODO: implement build
     return MaterialApp(
       title: 'VYO Fitness',
       debugShowCheckedModeBanner: false,
       theme: ThemeData.dark(),

       initialRoute: "/",

       routes: {
          "/": (context) => const LoginPage(),
          "/home": (context) => const MainNavigationBar(),
       },
     );
   }
 }