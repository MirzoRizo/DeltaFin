import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:shop_core/shop_core.dart';
import 'dart:io';
import 'dart:async';

import '../logic/cart_cubit.dart';
import 'widgets/cart_panel.dart';
import 'widgets/payment_dialogs.dart'; // <--- ПОДКЛЮЧИЛИ ДИАЛОГИ
import 'history_screen.dart';
import 'shift_screen.dart';

class CashierTerminalScreen extends StatefulWidget {
  const CashierTerminalScreen({Key? key}) : super(key: key);

  @override
  State<CashierTerminalScreen> createState() => _CashierTerminalScreenState();
}

class _CashierTerminalScreenState extends State<CashierTerminalScreen> {
  final Color _premiumGreen = const Color(0xFF0A7B54);

  // Репозитории
  final ProductRepository _productRepo = ProductRepository();
  final SaleRepository _saleRepo = SaleRepository();
  final HeldCartRepository _heldCartRepo =
      HeldCartRepository(); // <--- НОВЫЙ РЕПОЗИТОРИЙ

  final TextEditingController _scannerController = TextEditingController();
  final FocusNode _scannerFocus = FocusNode();

  // Сканер
  String _barcodeBuffer = '';
  DateTime? _lastKeyPress;

  int _currentTab = 0;
  String _searchQuery = '';
  bool _isSidebarCollapsed = false;
  Timer? _debounce;

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
    _debounce?.cancel();
    _scannerController.dispose();
    _scannerFocus.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.f12) {
        if (context.read<CartCubit>().state.isNotEmpty) _openPaymentSelection();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        context.read<CartCubit>().clearCart();
        return KeyEventResult.handled;
      }

      final now = DateTime.now();
      if (_lastKeyPress != null &&
          now.difference(_lastKeyPress!) > const Duration(milliseconds: 70)) {
        _barcodeBuffer = '';
      }
      _lastKeyPress = now;

      if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_barcodeBuffer.isNotEmpty) {
          _onScan(_barcodeBuffer);
          _barcodeBuffer = '';
          return KeyEventResult.handled;
        }
      } else if (event.character != null) {
        _barcodeBuffer += event.character!;
      }
    }
    return KeyEventResult.ignored;
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
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _categories = await _productRepo.getCategoriesWithProducts();
      _products = await _productRepo.getProducts(
        categoryId: _selectedCategory?.id,
        query: _searchQuery,
      );
    } catch (e) {
      _showErrorDialog('Ошибка', 'Не удалось загрузить товары: $e');
    } finally {
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
    setState(() => _selectedCategory = category);
    _loadData();
  }

  Future<void> _onScan(String barcode) async {
    if (barcode.trim().isEmpty) return;
    try {
      await _saleRepo.checkAndOpenShift();
      final product = await _productRepo.getProductByBarcode(barcode);

      if (product != null) {
        if (product.isWeight)
          await _showWeightDialog(product);
        else if (mounted)
          context.read<CartCubit>().addProduct(product);
      } else {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Товар не найден!'),
              backgroundColor: Colors.red,
            ),
          );
      }
    } catch (e) {
      _showErrorDialog('Ошибка сканера', 'Произошел сбой: $e');
    }
    _scannerController.clear();
    _scannerFocus.requestFocus();
  }

  Future<void> _showWeightDialog(Product product) async {
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
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
    final weight = double.tryParse(weightController.text.replaceAll(',', '.'));
    if (weight != null && weight > 0 && mounted)
      context.read<CartCubit>().addProduct(product, qty: weight);
    _scannerFocus.requestFocus();
  }

  void _openPaymentSelection() async {
    final totalSum = context.read<CartCubit>().totalSum;
    final paymentResult = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SizedBox(
          width: 500,
          child: PaymentSelectionForm(
            totalAmount: totalSum,
            premiumColor: _premiumGreen,
          ),
        ),
      ),
    );
    if (paymentResult != null)
      await _finalizeSale(paymentResult);
    else
      _scannerFocus.requestFocus();
  }

  Future<void> _finalizeSale(Map<String, dynamic> paymentData) async {
    try {
      final cubit = context.read<CartCubit>();
      final cartItems = cubit.state;
      final double totalSum = cubit.totalSum;
      final String paymentType = paymentData['type'];
      final double cashGiven = paymentData['cash_given'] ?? totalSum;
      final double change = paymentData['change'] ?? 0.0;

      final itemsToSave = cartItems
          .map(
            (item) => {
              'product_id': item.product.id,
              'quantity': item.quantity,
              'price': item.product.price,
            },
          )
          .toList();
      int newSaleId = await _saleRepo.finalizeSale(
        totalAmount: totalSum,
        paymentType: paymentType,
        items: itemsToSave,
      );

      final savedCart = List<CartItem>.from(cartItems);
      cubit.clearCart();
      _loadData();

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
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
      _showErrorDialog('Сбой оплаты', 'Произошла ошибка:\n$e');
    } finally {
      _scannerFocus.requestFocus();
    }
  }

  // === ЛОГИКА ОТЛОЖЕННЫХ ЧЕКОВ ===
  Future<void> _holdCurrentCart() async {
    final cubit = context.read<CartCubit>();
    if (cubit.state.isEmpty) return;

    try {
      final itemsToSave = cubit.state
          .map(
            (item) => {
              'product_id': item.product.id,
              'quantity': item.quantity,
            },
          )
          .toList();

      await _heldCartRepo.holdCart(cubit.totalSum, itemsToSave);
      cubit.clearCart();

      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Чек успешно отложен!'),
            backgroundColor: _premiumGreen,
          ),
        );
    } catch (e) {
      _showErrorDialog('Ошибка', 'Не удалось отложить чек: $e');
    }
  }

  Future<void> _showHeldCartsDialog() async {
    try {
      final heldCarts = await _heldCartRepo.getHeldCarts();
      if (!mounted) return;

      if (heldCarts.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Нет отложенных чеков')));
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
            width: 450,
            height: 350,
            child: ListView.separated(
              itemCount: heldCarts.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final cart = heldCarts[index];
                final dateStr = DateFormat(
                  'dd.MM.yyyy HH:mm',
                ).format(DateTime.parse(cart['date']));
                final amount = (cart['total_amount'] as double).toStringAsFixed(
                  2,
                );

                return ListTile(
                  leading: Icon(
                    Icons.shopping_cart_checkout,
                    color: _premiumGreen,
                    size: 30,
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
                      color: Colors.black,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context); // Закрываем диалог
                    final cartId = cart['id'] as int;

                    // Загружаем товары из БД
                    final itemsMap = await _heldCartRepo.getHeldCartItems(
                      cartId,
                    );
                    List<CartItem> restoredItems = itemsMap.map((row) {
                      return CartItem(
                        product: Product.fromMap(row),
                        quantity: row['quantity'] as double,
                      );
                    }).toList();

                    // Удаляем из отложенных и закидываем в активную корзину
                    await _heldCartRepo.deleteHeldCart(cartId);
                    if (mounted)
                      context.read<CartCubit>().restoreCart(restoredItems);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      );
    } catch (e) {
      _showErrorDialog('Ошибка', 'Сбой загрузки: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
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
        // ЛЕВАЯ ПАНЕЛЬ (КОРЗИНА)
        Expanded(
          flex: 3,
          child: CartPanel(
            scannerController: _scannerController,
            scannerFocus: _scannerFocus,
            onScan: _onScan,
            onPayPressed: _openPaymentSelection,
            premiumColor: _premiumGreen,
            onHoldTap: _holdCurrentCart, // <--- Привязали откладывание
            onHoldLongPress:
                _showHeldCartsDialog, // <--- Привязали загрузку отложенных (Долгое нажатие)
          ),
        ),

        // ПРАВАЯ ПАНЕЛЬ (КАТАЛОГ)
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
                              onTap: () {
                                if (product.isWeight)
                                  _showWeightDialog(product);
                                else
                                  context.read<CartCubit>().addProduct(product);
                              },
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
