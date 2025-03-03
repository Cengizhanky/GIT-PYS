import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://yxtfsucckffljllaoksh.supabase.co', // Yeni Supabase URL
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl4dGZzdWNja2ZmbGpsbGFva3NoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzkxODIxOTMsImV4cCI6MjA1NDc1ODE5M30.-cDUOAWv31HgdHaw3FVPYoDY8pe9QsLFQZ0VTf-iikk', // Yeni Supabase Anon Key
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'User App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LoginScreen(),
    );
  }
}