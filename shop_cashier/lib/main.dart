import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart'; // <--- НОВОЕ
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'screens/cashier_terminal_screen.dart';
import 'logic/cart_cubit.dart'; // <--- НОВОЕ

void main() {
  WidgetsFlutterBinding.ensureInitialized();

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
    // ОБОРАЧИВАЕМ В BlocProvider
    return MultiBlocProvider(
      providers: [BlocProvider<CartCubit>(create: (context) => CartCubit())],
      child: MaterialApp(
        title: 'Терминал Кассира',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: const CashierTerminalScreen(),
      ),
    );
  }
}
