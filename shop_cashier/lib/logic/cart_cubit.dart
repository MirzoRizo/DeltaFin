import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shop_core/shop_core.dart';

class CartCubit extends Cubit<List<CartItem>> {
  CartCubit() : super([]);

  // Добавление товара
  void addProduct(Product product, {double qty = 1.0}) {
    final currentState = List<CartItem>.from(state);
    final existingIndex = currentState.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (existingIndex >= 0) {
      // Если товар уже есть, увеличиваем количество
      currentState[existingIndex] = currentState[existingIndex].copyWith(
        quantity: currentState[existingIndex].quantity + qty,
      );
    } else {
      // Иначе добавляем новый
      currentState.add(CartItem(product: product, quantity: qty));
    }

    emit(currentState); // Отправляем новое состояние в UI
  }

  // Увеличение количества на 1
  void incrementItem(int index) {
    final currentState = List<CartItem>.from(state);
    currentState[index] = currentState[index].copyWith(
      quantity: currentState[index].quantity + 1,
    );
    emit(currentState);
  }

  // Уменьшение количества или удаление
  void decrementItem(int index) {
    final currentState = List<CartItem>.from(state);
    if (currentState[index].quantity > 1) {
      currentState[index] = currentState[index].copyWith(
        quantity: currentState[index].quantity - 1,
      );
    } else {
      currentState.removeAt(index);
    }
    emit(currentState);
  }

  // Очистка корзины
  void clearCart() {
    emit([]);
  }

  // Восстановление корзины из отложенных
  void restoreCart(List<CartItem> items) {
    emit(items); // Просто заменяем текущее состояние на пришедший список
  }

  // Подсчет общей суммы
  double get totalSum => state.fold(0, (sum, item) => sum + item.total);
}
