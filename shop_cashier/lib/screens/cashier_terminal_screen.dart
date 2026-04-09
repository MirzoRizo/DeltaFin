import 'package:flutter/material.dart';
import 'package:shop_core/shop_core.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:async';
import 'history_screen.dart';
import 'shift_screen.dart';
import 'printer_service.dart';

class CartItem {
  final Product product;
  double quantity;
  CartItem({required this.product, this.quantity = 1.0});
  double get total => product.price * quantity;
}

class CashierTerminalScreen extends StatefulWidget {
  const CashierTerminalScreen({Key? key}) : super(key: key);

  @override
  State<CashierTerminalScreen> createState() => _CashierTerminalScreenState();
}

class _CashierTerminalScreenState extends State<CashierTerminalScreen> {
  final Color _premiumGreen = const Color(0xFF0A7B54);

  final TextEditingController _scannerController = TextEditingController();
  final FocusNode _scannerFocus = FocusNode();

  int _currentTab = 0;
  String _searchQuery = '';
  bool _isSidebarCollapsed = false;
  Timer? _holdTimer;
  Timer? _debounce;

  List<CartItem> _cart = [];
  List<Product> _products = [];
  List<Category> _categories = [];
  Category? _selectedCategory;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scannerFocus.requestFocus(),
    );
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _debounce?.cancel();
    _scannerController.dispose();
    _scannerFocus.dispose();
    super.dispose();
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 16)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _premiumGreen),
            onPressed: () => Navigator.pop(context),
            child: const Text('Понятно', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper.instance.database;
      final catMaps = await db.rawQuery(
        'SELECT DISTINCT c.* FROM categories c JOIN products p ON c.id = p.category_id WHERE p.is_weight = 1',
      );
      _categories = catMaps.map((c) => Category.fromMap(c)).toList();

      String whereClause = 'is_weight = 1';
      List<dynamic> whereArgs = [];

      if (_selectedCategory != null) {
        whereClause += ' AND category_id = ?';
        whereArgs.add(_selectedCategory!.id);
      }

      if (_searchQuery.isNotEmpty) {
        whereClause += ' AND name LIKE ?';
        whereArgs.add('%$_searchQuery%');
      }

      final prodMaps = await db.query(
        'products',
        where: whereClause,
        whereArgs: whereArgs.isEmpty ? null : whereArgs,
        orderBy: 'popularity DESC, name ASC',
        limit: 100,
      );

      setState(() {
        _products = prodMaps.map((map) => Product.fromMap(map)).toList();
        _isLoading = false;
      });
    } catch (e) {
      _showErrorDialog('Ошибка базы данных', 'Не удалось загрузить товары: $e');
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() => _searchQuery = val.trim());
      _loadData();
    });
  }

  void _filterByCategory(Category? category) {
    setState(() {
      _selectedCategory = category;
    });
    _loadData();
  }

  Future<void> _checkAndOpenShift() async {
    final db = await DatabaseHelper.instance.database;
    final shiftResult = await db.query(
      'shifts',
      where: 'is_open = ?',
      whereArgs: [1],
    );
    if (shiftResult.isEmpty) {
      await db.insert('shifts', {
        'opened_at': DateTime.now().toIso8601String(),
        'is_open': 1,
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Смена открыта автоматически!'),
            backgroundColor: _premiumGreen,
          ),
        );
    }
  }

  Future<void> _onScan(String barcode) async {
    if (barcode.trim().isEmpty) return;
    try {
      await _checkAndOpenShift();
      final db = await DatabaseHelper.instance.database;
      final result = await db.query(
        'products',
        where: 'barcode = ?',
        whereArgs: [barcode.trim()],
      );
      if (result.isNotEmpty)
        _addToCart(Product.fromMap(result.first));
      else
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Товар не найден!'),
            backgroundColor: Colors.red,
          ),
        );
    } catch (e) {
      _showErrorDialog(
        'Ошибка сканера',
        'Произошел сбой при поиске товара: $e',
      );
    }
    _scannerController.clear();
    _scannerFocus.requestFocus();
  }

  void _addToCart(Product product, {double qty = 1.0}) {
    setState(() {
      final existingIndex = _cart.indexWhere(
        (item) => item.product.id == product.id,
      );
      if (existingIndex >= 0)
        _cart[existingIndex].quantity += qty;
      else
        _cart.add(CartItem(product: product, quantity: qty));
    });
  }

  void _incrementCartItem(int index) => setState(() => _cart[index].quantity++);
  void _decrementCartItem(int index) => setState(() {
    if (_cart[index].quantity > 1)
      _cart[index].quantity--;
    else
      _cart.removeAt(index);
  });
  void _clearCart() => setState(() => _cart.clear());
  double get _totalSum => _cart.fold(0, (sum, item) => sum + item.total);

  Future<void> _showWeightDialog(Product product) async {
    await _checkAndOpenShift();
    final weightController = TextEditingController();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Вес: ${product.name}'),
        content: TextField(
          controller: weightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          onSubmitted: (_) => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: _premiumGreen),
            child: const Text(
              'Добавить',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    final weight = double.tryParse(weightController.text.replaceAll(',', '.'));
    if (weight != null && weight > 0) _addToCart(product, qty: weight);
    _scannerFocus.requestFocus();
  }

  Future<void> _holdCurrentCart() async {
    if (_cart.isEmpty) return;
    try {
      final db = await DatabaseHelper.instance.database;
      await db.transaction((txn) async {
        final heldId = await txn.insert('held_carts', {
          'date': DateTime.now().toIso8601String(),
          'total_amount': _totalSum,
        });
        for (var item in _cart)
          await txn.insert('held_cart_items', {
            'held_cart_id': heldId,
            'product_id': item.product.id,
            'quantity': item.quantity,
          });
      });
      setState(() => _cart.clear());
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Чек отложен!'),
            backgroundColor: _premiumGreen,
          ),
        );
    } catch (e) {
      _showErrorDialog('Ошибка', 'Не удалось отложить чек: $e');
    } finally {
      _scannerFocus.requestFocus();
    }
  }

  Future<void> _showHeldCartsDialog() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final heldCarts = await db.query('held_carts', orderBy: 'id DESC');
      if (!mounted) return;
      if (heldCarts.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Нет отложенных чеков')));
        _scannerFocus.requestFocus();
        return;
      }
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            'Отложенные чеки',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 400,
            height: 300,
            child: ListView.separated(
              itemCount: heldCarts.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final cart = heldCarts[index];
                final dateStr = DateFormat(
                  'dd.MM.yyyy HH:mm',
                ).format(DateTime.parse(cart['date'] as String));
                final amount = (cart['total_amount'] as double).toStringAsFixed(
                  2,
                );
                return ListTile(
                  leading: Icon(
                    Icons.shopping_cart_checkout,
                    color: _premiumGreen,
                  ),
                  title: Text(
                    'Чек от $dateStr',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: Text(
                    '$amount руб.',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final cartId = cart['id'] as int;
                    final itemsMap = await db.rawQuery(
                      'SELECT hci.quantity, p.* FROM held_cart_items hci JOIN products p ON hci.product_id = p.id WHERE hci.held_cart_id = ?',
                      [cartId],
                    );
                    setState(() {
                      _cart.clear();
                      for (var row in itemsMap)
                        _cart.add(
                          CartItem(
                            product: Product.fromMap(row),
                            quantity: row['quantity'] as double,
                          ),
                        );
                    });
                    await db.delete(
                      'held_carts',
                      where: 'id = ?',
                      whereArgs: [cartId],
                    );
                    await db.delete(
                      'held_cart_items',
                      where: 'held_cart_id = ?',
                      whereArgs: [cartId],
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Закрыть',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      _showErrorDialog('Ошибка', 'Сбой загрузки отложенных чеков: $e');
    }
    _scannerFocus.requestFocus();
  }

  void _openPaymentSelection() async {
    if (_cart.isEmpty) return;

    // Возвращает Map: {'type': 'Наличные', 'cash_given': 500.0, 'change': 120.0}
    final paymentResult = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SizedBox(
          width: 500,
          child: PaymentSelectionForm(
            totalAmount: _totalSum,
            premiumColor: _premiumGreen,
          ),
        ),
      ),
    );

    if (paymentResult != null) {
      await _finalizeSale(paymentResult);
    } else {
      _scannerFocus.requestFocus();
    }
  }

  // === ОБНОВЛЕННАЯ ЛОГИКА СОХРАНЕНИЯ И ВЫЗОВ ЧЕКА ===
  Future<void> _finalizeSale(Map<String, dynamic> paymentData) async {
    try {
      final db = await DatabaseHelper.instance.database;
      int newSaleId = 0;

      // 1. Сохраняем в базу текущие товары чека (копируем, чтобы передать в дизайн чека)
      final savedCart = List<CartItem>.from(_cart);
      final double totalSum = _totalSum;
      final String paymentType = paymentData['type'];
      final double cashGiven = paymentData['cash_given'] ?? totalSum;
      final double change = paymentData['change'] ?? 0.0;

      await db.transaction((txn) async {
        // БЕЗОПАСНОСТЬ: Ищем открытую смену прямо внутри транзакции
        final shiftResult = await txn.query(
          'shifts',
          where: 'is_open = ?',
          whereArgs: [1],
          limit: 1,
        );

        // Запрещаем пробивать чеки "в пустоту" (shift_id = 0)
        if (shiftResult.isEmpty) {
          throw Exception('Смена закрыта. Пожалуйста, откройте смену в меню.');
        }
        int currentShiftId = shiftResult.first['id'] as int;

        newSaleId = await txn.insert('sales', {
          'shift_id': currentShiftId,
          'date': DateTime.now().toIso8601String(),
          'total_amount': totalSum,
          'payment_type': paymentType,
          'is_synced': 0,
        });

        for (var item in _cart) {
          await txn.insert('sale_items', {
            'sale_id': newSaleId,
            'product_id': item.product.id,
            'quantity': item.quantity,
            'price': item.product.price,
            'returned_quantity': 0,
          });
          await txn.rawUpdate(
            'UPDATE products SET stock = stock - ?, popularity = popularity + 1 WHERE id = ?',
            [item.quantity, item.product.id],
          );
        }
      });

      // 2. Очищаем интерфейс кассы
      setState(() => _cart.clear());
      _loadData();

      // 3. ПОКАЗЫВАЕМ ВИЗУАЛЬНЫЙ ЧЕК
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            backgroundColor:
                Colors.transparent, // Прозрачный фон для красивого чека
            child: ReceiptPreviewDialog(
              saleId: newSaleId,
              cartItems: savedCart,
              totalAmount: totalSum,
              paymentType: paymentType,
              cashGiven: cashGiven,
              change: change,
              premiumColor: _premiumGreen,
            ),
          ),
        );
      }
    } catch (e) {
      _showErrorDialog(
        'Сбой оплаты',
        'Произошла ошибка при сохранении чека в базу данных:\n$e',
      );
    } finally {
      _scannerFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: IndexedStack(
              index: _currentTab,
              children: [
                _buildPosTerminal(),
                _currentTab == 1
                    ? ShiftScreen(key: UniqueKey())
                    : const SizedBox(),
                _currentTab == 2
                    ? HistoryScreen(key: UniqueKey())
                    : const SizedBox(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _isSidebarCollapsed ? 80 : 120,
      color: const Color(0xFF1E232E),
      child: Column(
        children: [
          const SizedBox(height: 16),
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () =>
                setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
            tooltip: 'Свернуть/Развернуть',
          ),
          const SizedBox(height: 16),
          Icon(
            Icons.storefront,
            color: _premiumGreen,
            size: _isSidebarCollapsed ? 32 : 40,
          ),
          const SizedBox(height: 48),
          _buildNavItem(Icons.point_of_sale, 'Касса', 0),
          _buildNavItem(Icons.access_time, 'Смена', 1),
          _buildNavItem(Icons.history, 'История', 2),
          const Spacer(),
          _buildNavItem(Icons.settings, 'Настройки', 3),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    bool isActive = _currentTab == index;
    return InkWell(
      onTap: () => setState(() => _currentTab = index),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isActive
              ? _premiumGreen.withOpacity(0.15)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isActive ? _premiumGreen : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? _premiumGreen : Colors.grey.shade500,
              size: 28,
            ),
            if (!_isSidebarCollapsed) ...[
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.grey.shade500,
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPosTerminal() {
    return Row(
      children: [
        // === КОРЗИНА ===
        Expanded(
          flex: 3,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                SizedBox(
                  height: 50,
                  child: TextField(
                    controller: _scannerController,
                    focusNode: _scannerFocus,
                    decoration: InputDecoration(
                      hintText: 'Штрихкод...',
                      prefixIcon: const Icon(Icons.qr_code_scanner),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onSubmitted: _onScan,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'В чеке: ${_cart.length} поз.',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      InkWell(
                        onTap: _clearCart,
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _cart.isEmpty
                      ? const Center(
                          child: Text(
                            'Корзина пуста',
                            style: TextStyle(color: Colors.grey, fontSize: 18),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _cart.length,
                          separatorBuilder: (context, index) =>
                              Divider(height: 1, color: Colors.grey.shade200),
                          itemBuilder: (context, index) {
                            final item = _cart[index];
                            String displayQty = item.product.isWeight
                                ? item.quantity.toStringAsFixed(2)
                                : item.quantity.toInt().toString();
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12.0,
                                horizontal: 8.0,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.product.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${item.product.price.toStringAsFixed(2)} руб.',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      InkWell(
                                        onTap: () => _decrementCartItem(index),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: _premiumGreen,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.remove,
                                            color: _premiumGreen,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        child: Text(
                                          displayQty,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () => _incrementCartItem(index),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _premiumGreen,
                                          ),
                                          child: const Icon(
                                            Icons.add,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  height: 70,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: _premiumGreen, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTapDown: (_) {
                                _holdTimer = Timer(
                                  const Duration(seconds: 3),
                                  () => _showHeldCartsDialog(),
                                );
                              },
                              onTapUp: (_) {
                                if (_holdTimer != null &&
                                    _holdTimer!.isActive) {
                                  _holdTimer!.cancel();
                                  if (_cart.isNotEmpty) _holdCurrentCart();
                                }
                              },
                              onTapCancel: () => _holdTimer?.cancel(),
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4.0,
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Отложить',
                                      style: TextStyle(
                                        color: _premiumGreen,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _premiumGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _cart.isEmpty
                              ? null
                              : _openPaymentSelection,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'ОПЛАТИТЬ  ${_totalSum.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // === ПРАВАЯ ПАНЕЛЬ (ТОВАРЫ) ===
        Expanded(
          flex: 7,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                SizedBox(
                  height: 50,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Поиск товаров...',
                      prefixIcon: Icon(Icons.search, color: _premiumGreen),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 45,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildCategoryChip(
                        'Все',
                        _selectedCategory == null,
                        () => _filterByCategory(null),
                      ),
                      ..._categories.map(
                        (cat) => _buildCategoryChip(
                          cat.name,
                          _selectedCategory?.id == cat.id,
                          () => _filterByCategory(cat),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _products.isEmpty
                      ? const Center(
                          child: Text(
                            'Ничего не найдено',
                            style: TextStyle(color: Colors.grey, fontSize: 18),
                          ),
                        )
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 5,
                                childAspectRatio: 0.9,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemCount: _products.length,
                          itemBuilder: (context, index) {
                            final product = _products[index];
                            return InkWell(
                              onTap: () => product.isWeight
                                  ? _showWeightDialog(product)
                                  : _addToCart(product),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(8),
                                              ),
                                          image:
                                              product.imagePath != null &&
                                                  product
                                                      .imagePath!
                                                      .isNotEmpty &&
                                                  File(
                                                    product.imagePath!,
                                                  ).existsSync()
                                              ? DecorationImage(
                                                  image: FileImage(
                                                    File(product.imagePath!),
                                                  ),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child:
                                            product.imagePath == null ||
                                                product.imagePath!.isEmpty ||
                                                !File(
                                                  product.imagePath!,
                                                ).existsSync()
                                            ? Center(
                                                child: Icon(
                                                  Icons.image_outlined,
                                                  size: 40,
                                                  color: Colors.grey.shade300,
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${product.price.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              color: _premiumGreen,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
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
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String label, bool isActive, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isActive,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: _premiumGreen,
        labelStyle: TextStyle(
          color: isActive ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
        ),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isActive ? _premiumGreen : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }
}

// === ФОРМА ОПЛАТЫ (Возвращает Map с данными оплаты) ===
class PaymentSelectionForm extends StatelessWidget {
  final double totalAmount;
  final Color premiumColor;
  const PaymentSelectionForm({
    Key? key,
    required this.totalAmount,
    required this.premiumColor,
  }) : super(key: key);

  Widget _buildPaymentButton(
    BuildContext context,
    String text,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: onTap,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedSum = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '',
      decimalDigits: 2,
    ).format(totalAmount);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Оплата',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context, null),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Итого: $formattedSum',
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 24),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'НАЛИЧНЫМИ',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          Row(
            children: [
              _buildPaymentButton(
                context,
                'Без сдачи',
                premiumColor,
                () => Navigator.pop(context, {
                  'type': 'Наличные',
                  'cash_given': totalAmount,
                  'change': 0.0,
                }),
              ),
              _buildPaymentButton(
                context,
                'Другая сумма',
                premiumColor,
                () async {
                  final result = await showDialog<Map<String, dynamic>>(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => Dialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SizedBox(
                        width: 600,
                        child: ChangeCalculatorDialog(
                          totalAmount: totalAmount,
                          premiumColor: premiumColor,
                        ),
                      ),
                    ),
                  );
                  if (result != null) Navigator.pop(context, result);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'КАРТОЙ',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          Row(
            children: [
              _buildPaymentButton(
                context,
                'Картой',
                Colors.blue.shade600,
                () => Navigator.pop(context, {
                  'type': 'Карта',
                  'cash_given': totalAmount,
                  'change': 0.0,
                }),
              ),
              _buildPaymentButton(
                context,
                'Безналичная',
                Colors.blue.shade600,
                () => Navigator.pop(context, {
                  'type': 'Безналичные',
                  'cash_given': totalAmount,
                  'change': 0.0,
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// === КАЛЬКУЛЯТОР СДАЧИ ===
class ChangeCalculatorDialog extends StatefulWidget {
  final double totalAmount;
  final Color premiumColor;
  const ChangeCalculatorDialog({
    Key? key,
    required this.totalAmount,
    required this.premiumColor,
  }) : super(key: key);
  @override
  State<ChangeCalculatorDialog> createState() => _ChangeCalculatorDialogState();
}

class _ChangeCalculatorDialogState extends State<ChangeCalculatorDialog> {
  String _inputAmount = '';

  void _onKeyPressed(String val) {
    setState(() {
      if (val == 'C') {
        _inputAmount = '';
      } else if (val == '⌫') {
        if (_inputAmount.isNotEmpty)
          _inputAmount = _inputAmount.substring(0, _inputAmount.length - 1);
      } else if (val == '.') {
        if (!_inputAmount.contains('.')) _inputAmount += val;
      } else {
        _inputAmount += val;
      }
    });
  }

  void _addQuickCash(double amount) {
    setState(() {
      _inputAmount = amount.toStringAsFixed(0);
    });
  }

  Widget _buildNumKey(String label, {Color? color}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: InkWell(
          onTap: () => _onKeyPressed(label),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 75,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color ?? Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              label,
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickCashKey(double amount) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: InkWell(
          onTap: () => _addQuickCash(amount),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Text(
              amount.toStringAsFixed(0),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double enteredAmount = double.tryParse(_inputAmount) ?? 0.0;
    double change = enteredAmount - widget.totalAmount;
    bool canPay = enteredAmount >= widget.totalAmount;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Расчет сдачи',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context, null),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 16),
                const Text(
                  'К ОПЛАТЕ:',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.totalAmount.toStringAsFixed(2),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'ВНЕСЕНО:',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border.all(color: widget.premiumColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _inputAmount.isEmpty ? '0.00' : _inputAmount,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: canPay ? widget.premiumColor : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'СДАЧА',
                        style: TextStyle(
                          color: canPay ? Colors.white70 : Colors.grey.shade500,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        canPay ? change.toStringAsFixed(2) : '0.00',
                        style: TextStyle(
                          color: canPay ? Colors.white : Colors.grey.shade500,
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.premiumColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: canPay
                        ? () => Navigator.pop(context, {
                            'type': 'Наличные',
                            'cash_given': enteredAmount,
                            'change': change,
                          })
                        : null,
                    child: const Text(
                      'ОПЛАТИТЬ',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _buildQuickCashKey(50),
                    _buildQuickCashKey(100),
                    _buildQuickCashKey(200),
                    _buildQuickCashKey(500),
                  ],
                ),
                const SizedBox(height: 12),
                Column(
                  children: [
                    Row(
                      children: [
                        _buildNumKey('7'),
                        _buildNumKey('8'),
                        _buildNumKey('9'),
                      ],
                    ),
                    Row(
                      children: [
                        _buildNumKey('4'),
                        _buildNumKey('5'),
                        _buildNumKey('6'),
                      ],
                    ),
                    Row(
                      children: [
                        _buildNumKey('1'),
                        _buildNumKey('2'),
                        _buildNumKey('3'),
                      ],
                    ),
                    Row(
                      children: [
                        _buildNumKey('C', color: Colors.red.shade100),
                        _buildNumKey('0'),
                        _buildNumKey('⌫', color: Colors.orange.shade100),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// === НОВЫЙ КЛАСС: ВИЗУАЛЬНЫЙ ДВИЖОК ЧЕКА (RECEIPT PREVIEW) ===
class ReceiptPreviewDialog extends StatelessWidget {
  final int saleId;
  final List<CartItem> cartItems;
  final double totalAmount;
  final String paymentType;
  final double cashGiven;
  final double change;
  final Color premiumColor;

  const ReceiptPreviewDialog({
    Key? key,
    required this.saleId,
    required this.cartItems,
    required this.totalAmount,
    required this.paymentType,
    required this.cashGiven,
    required this.change,
    required this.premiumColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now());

    return Center(
      child: Container(
        width: 350, // Ширина типичной чековой ленты
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4), // Острые углы как у бумаги
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 15,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ШАПКА ЧЕКА
            const Text(
              'РАШТ ЭКСПРЕСС КАРГО',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Courier',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Кассовый чек',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontFamily: 'Courier'),
            ),
            Text(
              'Чек №: ${saleId.toString().padLeft(5, '0')}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontFamily: 'Courier'),
            ),
            Text(
              'Дата: $dateStr',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontFamily: 'Courier'),
            ),
            const SizedBox(height: 16),
            const Text(
              '--------------------------------',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Courier', color: Colors.grey),
            ),
            const SizedBox(height: 8),

            // ТОВАРЫ
            SizedBox(
              height: 200, // Ограничение высоты, чтобы чек не вылез за экран
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: cartItems.length,
                itemBuilder: (context, index) {
                  final item = cartItems[index];
                  String displayQty = item.product.isWeight
                      ? item.quantity.toStringAsFixed(3)
                      : item.quantity.toInt().toString();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.product.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Courier',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '$displayQty x ${item.product.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Courier',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          item.total.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'Courier',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),
            const Text(
              '--------------------------------',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Courier', color: Colors.grey),
            ),
            const SizedBox(height: 8),

            // ИТОГИ
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ИТОГО:',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Courier',
                  ),
                ),
                Text(
                  totalAmount.toStringAsFixed(2),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Courier',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ОПЛАТА ($paymentType):',
                  style: const TextStyle(fontSize: 14, fontFamily: 'Courier'),
                ),
                Text(
                  cashGiven.toStringAsFixed(2),
                  style: const TextStyle(fontSize: 14, fontFamily: 'Courier'),
                ),
              ],
            ),
            if (change > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'СДАЧА:',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    change.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            const Text(
              'СПАСИБО ЗА ПОКУПКУ!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Courier',
              ),
            ),
            const SizedBox(height: 24),

            // КНОПКИ УПРАВЛЕНИЯ
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: premiumColor),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Новый чек',
                      style: TextStyle(
                        color: premiumColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: premiumColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ищем принтер...')),
                      );

                      List<Map<String, dynamic>> itemsForPrinter = cartItems
                          .map(
                            (item) => {
                              'name': item.product.name,
                              'qty': item.product.isWeight
                                  ? item.quantity.toStringAsFixed(3)
                                  : item.quantity.toInt().toString(),
                              'price': item.product.price.toStringAsFixed(2),
                              'total': item.total.toStringAsFixed(2),
                            },
                          )
                          .toList();

                      String status = await PrinterService.instance
                          .printReceipt(
                            saleId: saleId,
                            items: itemsForPrinter,
                            totalAmount: totalAmount,
                            cashGiven: cashGiven,
                            change: change,
                            paymentType: paymentType,
                          );

                      if (status == "OK") {
                        Navigator.pop(context); // Закрываем чек при успехе
                      } else {
                        // ПОКАЗЫВАЕМ ТОЧНУЮ ОШИБКУ КРАСНЫМ ЦВЕТОМ
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('🛑 Ошибка: $status'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'Печать',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
