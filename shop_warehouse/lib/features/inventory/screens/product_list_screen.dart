import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shop_core/shop_core.dart';
import '../logic/inventory_manager.dart';
import 'product_info_dialog.dart'; // <--- ПОДКЛЮЧАЕМ НАШУ АДМИНКУ

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final InventoryManager _inventoryManager = InventoryManager();

  List<Product> _products = [];
  List<Category> _categories = [];
  Map<int, String> _categoryMap = {};

  String _searchQuery = '';
  int? _selectedCategoryId;
  bool _isLoading = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _categories = await _inventoryManager.getCategories();
    // Трансформируем список в Map для мгновенного доступа
    _categoryMap = {for (var c in _categories) c.id: c.name};
    await _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      final results = await _inventoryManager.getProducts(
        query: _searchQuery,
        categoryId: _selectedCategoryId,
      );
      setState(() => _products = results);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() => _searchQuery = value.trim());
      _fetchProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Остатки на складе'), centerTitle: true),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      onChanged: _onSearchChanged,
                      decoration: const InputDecoration(
                        labelText: 'Поиск (Название или Штрихкод)',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<int?>(
                      initialValue: _selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Группа товаров',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Все группы'),
                        ),
                        ..._categories.map(
                          (cat) => DropdownMenuItem(
                            value: cat.id,
                            child: Text(cat.name),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedCategoryId = val);
                        _fetchProducts();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                ? const Center(
                    child: Text(
                      'Товары не найдены. Измените фильтры.',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _products.length,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemBuilder: (context, index) {
                      final p = _products[index];
                      final catName =
                          _categoryMap[p.categoryId] ?? 'Без группы';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                p.isWeight ? Icons.scale : Icons.qr_code,
                                color: Colors.blueGrey,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                p.barcode,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          title: Text(
                            p.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Группа: $catName | Закуп: ${p.costPrice} | Розница: ${p.price}',
                          ),
                          // === НОВЫЙ БЛОК: ОСТАТОК + КНОПКА "ИНФО" ===
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: p.stock <= 0
                                      ? Colors.red.shade100
                                      : Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Остаток: ${p.stock}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: p.stock <= 0
                                        ? Colors.red.shade900
                                        : Colors.green.shade900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(
                                  Icons.info_outline,
                                  color: Colors.blue,
                                  size: 28,
                                ),
                                tooltip: 'Карточка товара и Ценник',
                                onPressed: () {
                                  // ОТКРЫВАЕМ НАШУ АДМИНКУ
                                  showDialog(
                                    context: context,
                                    builder: (context) => ProductInfoDialog(
                                      product: p,
                                      onProductUpdated: () {
                                        _fetchProducts(); // Перезагружаем список, если фото изменилось
                                      },
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
