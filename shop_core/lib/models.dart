class Product {
  int? id;
  String barcode;
  String name;
  double costPrice;
  double price;
  double stock;
  int? categoryId;
  bool isWeight;
  String unit;
  String? imagePath;
  int popularity; // <--- НОВОЕ ПОЛЕ

  Product({
    this.id,
    required this.barcode,
    required this.name,
    required this.costPrice,
    required this.price,
    required this.stock,
    this.categoryId,
    required this.isWeight,
    this.unit = 'шт',
    this.imagePath,
    this.popularity = 0, // <--- НОВОЕ ПОЛЕ
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      barcode: map['barcode'],
      name: map['name'],
      costPrice: map['cost_price'],
      price: map['price'],
      stock: map['stock'],
      categoryId: map['category_id'],
      isWeight: map['is_weight'] == 1,
      unit: map['unit'] ?? 'шт',
      imagePath: map['image_path'],
      popularity: map['popularity'] ?? 0, // <--- ЧИТАЕМ ИЗ БАЗЫ
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'barcode': barcode,
      'name': name,
      'cost_price': costPrice,
      'price': price,
      'stock': stock,
      'category_id': categoryId,
      'is_weight': isWeight ? 1 : 0,
      'unit': unit,
      'image_path': imagePath,
      'popularity': popularity, // <--- ПИШЕМ В БАЗУ
    };
  }
}

class Category {
  final int id;
  final String name;
  final int prefix;

  Category({required this.id, required this.name, required this.prefix});

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(id: map['id'], name: map['name'], prefix: map['prefix']);
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'prefix': prefix};
  }
}

class CartItem {
  final Product product;
  double quantity;

  CartItem({required this.product, this.quantity = 1.0});

  double get total => product.price * quantity;

  // Удобный метод для создания копии (понадобится для стейт-менеджмента)
  CartItem copyWith({double? quantity}) {
    return CartItem(product: product, quantity: quantity ?? this.quantity);
  }
}
