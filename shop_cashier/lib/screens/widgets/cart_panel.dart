import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shop_core/shop_core.dart';
import '../../logic/cart_cubit.dart';

class CartPanel extends StatelessWidget {
  final TextEditingController scannerController;
  final FocusNode scannerFocus;
  final Function(String) onScan;
  final VoidCallback onPayPressed;
  final Color premiumColor;
  final VoidCallback onHoldTap;
  final VoidCallback onHoldLongPress;

  const CartPanel({
    Key? key,
    required this.scannerController,
    required this.scannerFocus,
    required this.onScan,
    required this.onPayPressed,
    required this.premiumColor,
    required this.onHoldTap,
    required this.onHoldLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // BlocBuilder слушает изменения только в CartCubit
    return BlocBuilder<CartCubit, List<CartItem>>(
      builder: (context, cart) {
        final cubit = context.read<CartCubit>();
        final totalSum = cubit.totalSum;

        return Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // Поле сканера
              SizedBox(
                height: 50,
                child: TextField(
                  controller: scannerController,
                  focusNode: scannerFocus,
                  decoration: InputDecoration(
                    hintText: 'Штрихкод...',
                    prefixIcon: const Icon(Icons.qr_code_scanner),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onSubmitted: onScan,
                ),
              ),

              // Шапка корзины
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'В чеке: ${cart.length} поз.',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    InkWell(
                      onTap: () => cubit.clearCart(),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              // Список товаров
              Expanded(
                child: cart.isEmpty
                    ? const Center(
                        child: Text(
                          'Корзина пуста',
                          style: TextStyle(color: Colors.grey, fontSize: 18),
                        ),
                      )
                    : ListView.separated(
                        itemCount: cart.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: Colors.grey.shade200),
                        itemBuilder: (context, index) {
                          final item = cart[index];
                          String displayQty = item.product.isWeight
                              ? item.quantity.toStringAsFixed(3)
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
                                      onTap: () => cubit.decrementItem(index),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: premiumColor,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.remove,
                                          color: premiumColor,
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
                                      onTap: () => cubit.incrementItem(index),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: premiumColor,
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

              // Кнопки внизу (Отложить / Оплатить)
              Container(
                margin: const EdgeInsets.only(top: 8),
                height: 70,
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: premiumColor, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: cart.isEmpty
                                ? null
                                : onHoldTap, // Клик для сохранения
                            onLongPress:
                                onHoldLongPress, // Удержание для просмотра списка
                            child: Center(
                              child: Text(
                                'Отложить',
                                style: TextStyle(
                                  color: cart.isEmpty
                                      ? Colors.grey
                                      : premiumColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
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
                          backgroundColor: premiumColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: cart.isEmpty ? null : onPayPressed,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'ОПЛАТИТЬ  ${totalSum.toStringAsFixed(2)}',
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
        );
      },
    );
  }
}
