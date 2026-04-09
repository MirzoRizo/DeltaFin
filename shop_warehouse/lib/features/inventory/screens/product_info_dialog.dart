import 'package:flutter/material.dart';
import 'package:shop_core/shop_core.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import '../logic/inventory_manager.dart'; // ВНИМАНИЕ: Проверь, правильный ли путь до твоего inventory_manager.dart

// === КАРТОЧКА ТОВАРА (МИНИ-АДМИНКА) ===
class ProductInfoDialog extends StatefulWidget {
  final Product product;
  final VoidCallback onProductUpdated;

  const ProductInfoDialog({
    Key? key,
    required this.product,
    required this.onProductUpdated,
  }) : super(key: key);

  @override
  State<ProductInfoDialog> createState() => _ProductInfoDialogState();
}

class _ProductInfoDialogState extends State<ProductInfoDialog> {
  final InventoryManager _inventoryManager = InventoryManager();
  late String? _currentImagePath;

  @override
  void initState() {
    super.initState();
    _currentImagePath = widget.product.imagePath;
  }

  // Логика загрузки и сохранения фото
  Future<void> _pickAndSaveImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );

      if (result != null && result.files.single.path != null) {
        File sourceFile = File(result.files.single.path!);

        // Папка для хранения картинок (общая с кассой)
        final String sharedDir = 'C:\\ProgramData\\ShopSystem\\Images';
        final dir = Directory(sharedDir);
        if (!await dir.exists()) await dir.create(recursive: true);

        // Генерируем уникальное имя файла
        final String fileExt = p.extension(sourceFile.path);
        final String newFileName =
            'prod_${widget.product.id}_${DateTime.now().millisecondsSinceEpoch}$fileExt';
        final String newPath = p.join(sharedDir, newFileName);

        // Копируем файл в системную папку
        await sourceFile.copy(newPath);

        // Обновляем базу данных через твой менеджер
        await _inventoryManager.updateProductImage(widget.product.id!, newPath);

        setState(() {
          _currentImagePath = newPath;
        });

        widget.onProductUpdated(); // Говорим списку товаров обновиться
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Фото успешно сохранено!'),
              backgroundColor: Colors.green,
            ),
          );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки фото: $e'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  void _printPriceTag() {
    Navigator.pop(context); // Скрываем инфо-панель
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: PriceTagPreviewDialog(product: widget.product),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasImage =
        _currentImagePath != null &&
        _currentImagePath!.isNotEmpty &&
        File(_currentImagePath!).existsSync();
    final Color accentColor = Colors.blue.shade700; // Строгий цвет для Склада

    return Container(
      width: 650,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Карточка товара',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ЛЕВАЯ ЧАСТЬ: Изображение
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Container(
                      height: 220,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                        image: hasImage
                            ? DecorationImage(
                                image: FileImage(File(_currentImagePath!)),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: !hasImage
                          ? Center(
                              child: Icon(
                                Icons.inventory_2_outlined,
                                size: 80,
                                color: Colors.grey.shade300,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _pickAndSaveImage,
                        icon: const Icon(Icons.camera_alt),
                        label: Text(
                          hasImage ? 'Изменить фото' : 'Добавить фото',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 32),

              // ПРАВАЯ ЧАСТЬ: Информация и кнопка ценника
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      'Штрихкод:',
                      widget.product.barcode,
                      isMono: true,
                    ),
                    _buildInfoRow(
                      'Себестоимость:',
                      '${widget.product.costPrice.toStringAsFixed(2)} руб.',
                    ),
                    _buildInfoRow(
                      'Цена (Розница):',
                      '${widget.product.price.toStringAsFixed(2)} руб.',
                      isBold: true,
                      color: Colors.green.shade700,
                    ),
                    _buildInfoRow(
                      'Остаток:',
                      '${widget.product.stock.toStringAsFixed(widget.product.isWeight ? 3 : 0)} ${widget.product.unit}',
                      isBold: true,
                    ),
                    _buildInfoRow(
                      'Тип товара:',
                      widget.product.isWeight ? 'Весовой' : 'Штучный',
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          side: const BorderSide(color: Colors.black, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _printPriceTag,
                        icon: const Icon(Icons.print, size: 28),
                        label: const Text(
                          'ПЕЧАТЬ ЦЕННИКА',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool isBold = false,
    bool isMono = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: color ?? Colors.black,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                fontFamily: isMono ? 'Courier' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// === ДИЗАЙН ЦЕННИКА (КАК В СУПЕРМАРКЕТАХ) ===
class PriceTagPreviewDialog extends StatelessWidget {
  final Product product;

  const PriceTagPreviewDialog({Key? key, required this.product})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final priceStr = product.price.toStringAsFixed(2);
    final parts = priceStr.split('.');
    final dateStr = DateFormat('dd.MM.yyyy').format(DateTime.now());

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 450,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'РАШТ ЭКСПРЕСС',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
                const Divider(color: Colors.black, thickness: 1),
                const SizedBox(height: 12),
                Text(
                  product.name.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.qr_code_2, size: 48),
                        const SizedBox(height: 4),
                        Text(
                          product.barcode,
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'Courier',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'за 1 ${product.unit}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          parts[0],
                          style: const TextStyle(
                            fontSize: 80,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                            letterSpacing: -3,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                parts[1],
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0,
                                ),
                              ),
                              const Text(
                                ' руб',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 450,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Colors.grey, width: 2),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Закрыть',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Отправка ценника на принтер...'),
                        ),
                      );
                      Navigator.pop(context);
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.print, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Печать',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
