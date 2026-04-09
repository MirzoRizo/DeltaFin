import 'package:flutter/material.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Подключаем наши созданные экраны
import 'features/inventory/screens/add_product_screen.dart';
import 'features/inventory/screens/product_list_screen.dart';
import 'features/inventory/screens/category_screen.dart';

void main() {
  // 1. ОБЯЗАТЕЛЬНЫЙ ПРЕДОХРАНИТЕЛЬ для десктопных приложений
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Инициализация локальной базы данных для ПК (Windows/Linux/Mac)
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const WarehouseApp());
}

class WarehouseApp extends StatelessWidget {
  const WarehouseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Склад - Управление',
      debugShowCheckedModeBanner: false, // Убираем красную ленту DEBUG
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const WarehouseDashboard(),
    );
  }
}

class WarehouseDashboard extends StatelessWidget {
  const WarehouseDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ПАНЕЛЬ УПРАВЛЕНИЯ СКЛАДОМ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildMenuButton(
              context,
              title: 'Приемка товара',
              icon: Icons.add_box_rounded,
              color: Colors.green,
              screen: const AddProductScreen(),
            ),
            const SizedBox(height: 20),

            _buildMenuButton(
              context,
              title: 'Остатки на складе',
              icon: Icons.inventory_2_outlined,
              color: Colors.blue,
              screen: const ProductListScreen(),
            ),
            const SizedBox(height: 20),

            _buildMenuButton(
              context,
              title: 'Группы товаров (Настройки)',
              icon: Icons.category_rounded,
              color: Colors.orange,
              screen: const CategoryScreen(),
            ),
          ],
        ),
      ),
    );
  }

  // Вспомогательный метод для рисования красивых кнопок
  Widget _buildMenuButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required Widget screen,
  }) {
    return SizedBox(
      width: 350,
      height: 70,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 32, color: Colors.white),
        label: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => screen),
          );
        },
      ),
    );
  }
}
