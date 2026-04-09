import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shop_core/shop_core.dart';
import '../logic/inventory_manager.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({Key? key}) : super(key: key);

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final InventoryManager _inventoryManager = InventoryManager();

  final _barcodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();

  final FocusNode _barcodeFocus = FocusNode();
  final FocusNode _stockFocus = FocusNode();

  bool _isLoading = false;
  bool _isExistingProduct = false;

  // Две независимые галочки для управления генерацией
  bool _isWeightMode = false;
  bool _isNoBarcodeMode = false;

  List<Category> _categories = [];
  Category? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    // При открытии экрана курсор сразу прыгает в штрихкод (готово к сканированию)
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _barcodeFocus.requestFocus(),
    );
  }

  Future<void> _loadCategories() async {
    final cats = await _inventoryManager.getCategories();
    setState(() => _categories = cats);
  }

  Future<void> _checkExistingBarcode(String barcode) async {
    if (barcode.trim().isEmpty) return;
    setState(() => _isLoading = true);
    final product = await _inventoryManager.getProductByBarcode(barcode.trim());

    if (product != null) {
      setState(() {
        _nameController.text = product.name;
        _costPriceController.text = product.costPrice.toString();
        _priceController.text = product.price.toString();
        _selectedCategory = _categories
            .where((c) => c.id == product.categoryId)
            .firstOrNull;
        _isExistingProduct = true;
      });
      _showMessage('Товар найден. Введите количество.', Colors.blue);
      _stockFocus.requestFocus();
    } else {
      setState(() {
        _isExistingProduct = false;
        _nameController.clear();
        _costPriceController.clear();
        _priceController.clear();
      });
    }
    setState(() => _isLoading = false);
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      _showMessage('Выберите группу товаров внизу списка!', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      String finalBarcode = _barcodeController.text.trim();
      bool isWeight = false;

      // Логика генерации перед сохранением
      if (_isWeightMode) {
        finalBarcode = await _inventoryManager.generateSmartPLU(
          _selectedCategory!.prefix,
        );
        isWeight = true; // Вылезет кнопкой на кассе
      } else if (_isNoBarcodeMode) {
        finalBarcode = await _inventoryManager.generateInternalEan13();
        isWeight = false; // Будем клеить этикетку
      }

      final product = Product(
        id: 0,
        unit: 'шт',
        barcode: finalBarcode,
        name: _nameController.text.trim(),
        costPrice: double.parse(_costPriceController.text.trim()),
        price: double.parse(_priceController.text.trim()),
        stock: double.parse(_stockController.text.trim()),
        categoryId: _selectedCategory!.id,
        isWeight: isWeight,
      );

      await _inventoryManager.saveProduct(product);

      if (mounted) {
        _showMessage('✅ Успешно сохранено! (Код: $finalBarcode)', Colors.green);
        _resetForm();
      }
    } catch (e) {
      if (mounted) _showMessage('🛑 Ошибка: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    _formKey.currentState!.reset();
    _barcodeController.clear();
    _nameController.clear();
    _costPriceController.clear();
    _priceController.clear();
    _stockController.clear();
    setState(() {
      _isExistingProduct = false;
      _isWeightMode = false;
      _isNoBarcodeMode = false;
      _selectedCategory = null; // Сбрасываем группу тоже
    });
    _barcodeFocus.requestFocus();
  }

  void _showMessage(String msg, Color color) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Приемка товара'), centerTitle: true),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    // 1. ПОЛЕ ШТРИХКОДА (В САМОМ ВЕРХУ)
                    TextFormField(
                      controller: _barcodeController,
                      focusNode: _barcodeFocus,
                      enabled:
                          !_isWeightMode &&
                          !_isNoBarcodeMode, // Блокируем, если нажата одна из галочек
                      decoration: InputDecoration(
                        labelText: 'Штрихкод',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.qr_code_scanner),
                        filled: _isWeightMode || _isNoBarcodeMode,
                        fillColor: Colors.grey.shade200,
                      ),
                      onFieldSubmitted: _checkExistingBarcode,
                      validator: (val) =>
                          (!_isWeightMode && !_isNoBarcodeMode && val!.isEmpty)
                          ? 'Пикните товар или выберите генерацию'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // 2. НАИМЕНОВАНИЕ
                    TextFormField(
                      controller: _nameController,
                      enabled: !_isExistingProduct,
                      decoration: InputDecoration(
                        labelText: 'Наименование товара',
                        border: const OutlineInputBorder(),
                        filled: _isExistingProduct,
                        fillColor: Colors.blue.shade50,
                      ),
                      validator: (val) =>
                          val!.isEmpty ? 'Обязательное поле' : null,
                    ),
                    const SizedBox(height: 16),

                    // 3. ЦЕНЫ
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _costPriceController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*'),
                              ),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Закупка',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*'),
                              ),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Розница',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 4. КОЛИЧЕСТВО
                    TextFormField(
                      controller: _stockController,
                      focusNode: _stockFocus,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Количество (Приход)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.add_box, color: Colors.green),
                      ),
                      validator: (val) =>
                          val!.isEmpty ? 'Обязательное поле' : null,
                    ),
                    const SizedBox(height: 24),

                    // 5. ДВЕ ГАЛОЧКИ В ОДИН РЯД (ВДОЛЬ)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blueGrey.shade200),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text(
                                'Весовой товар',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: const Text(
                                'В кассу как кнопка',
                                style: TextStyle(fontSize: 11),
                              ),
                              value: _isWeightMode,
                              activeColor: Colors.blueAccent,
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: _isExistingProduct
                                  ? null
                                  : (val) {
                                      setState(() {
                                        _isWeightMode = val ?? false;
                                        if (_isWeightMode) {
                                          _isNoBarcodeMode =
                                              false; // Отключаем соседнюю галочку
                                          _barcodeController.text =
                                              'АВТО КОД (PLU)';
                                        } else {
                                          _barcodeController.clear();
                                        }
                                      });
                                    },
                            ),
                          ),
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text(
                                'Без штрихкода',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: const Text(
                                'Генерация EAN-13',
                                style: TextStyle(fontSize: 11),
                              ),
                              value: _isNoBarcodeMode,
                              activeColor: Colors.blueAccent,
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: _isExistingProduct
                                  ? null
                                  : (val) {
                                      setState(() {
                                        _isNoBarcodeMode = val ?? false;
                                        if (_isNoBarcodeMode) {
                                          _isWeightMode =
                                              false; // Отключаем соседнюю галочку
                                          _barcodeController.text =
                                              'АВТО КОД (EAN-13)';
                                        } else {
                                          _barcodeController.clear();
                                        }
                                      });
                                    },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 6. ГРУППА ТОВАРОВ (В САМОМ НИЗУ ПЕРЕД КНОПКОЙ)
                    DropdownButtonFormField<Category>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Группа товаров',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories
                          .map(
                            (cat) => DropdownMenuItem(
                              value: cat,
                              child: Text(
                                '${cat.name} (Префикс ${cat.prefix})',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _isExistingProduct
                          ? null
                          : (val) => setState(() => _selectedCategory = val),
                      validator: (val) =>
                          val == null ? 'Обязательное поле' : null,
                    ),
                    const SizedBox(height: 24),

                    // 7. КНОПКА СОХРАНЕНИЯ
                    SizedBox(
                      height: 55,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _submitForm,
                        icon: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Icon(Icons.save, size: 28),
                        label: Text(
                          _isLoading ? 'ОБРАБОТКА...' : 'ПРИНЯТЬ ТОВАР',
                          style: const TextStyle(fontSize: 18),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
