import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'screens/cashier_terminal_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация базы для десктопа (Windows)
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const CashierApp());
}

class CashierApp extends StatelessWidget {
  const CashierApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Терминал Кассира',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
        ), // Сделаем кассу в зеленоватых (денежных) тонах
        useMaterial3: true,
      ),
      home: const CashierTerminalScreen(),
    );
  }
}
