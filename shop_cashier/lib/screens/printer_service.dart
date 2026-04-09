import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PrinterService {
  static final PrinterService instance = PrinterService._init();
  PrinterService._init();

  Future<String> printReceipt({
    required int saleId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required double cashGiven,
    required double change,
    required String paymentType,
  }) async {
    try {
      // 1. ПОЛУЧАЕМ СПИСОК ВСЕХ ПРИНТЕРОВ В WINDOWS
      final printers = await Printing.listPrinters();
      if (printers.isEmpty) return "Принтеры не найдены в системе Windows.";

      // 2. УМНЫЙ ПОИСК НУЖНОГО ПРИНТЕРА
      Printer? targetPrinter;
      for (var p in printers) {
        if (p.name.toLowerCase().contains('xp') ||
            p.name.toLowerCase().contains('pos') ||
            p.name.toLowerCase().contains('xprinter')) {
          targetPrinter = p;
          break;
        }
      }
      targetPrinter ??= printers.firstWhere(
        (p) => p.isDefault,
        orElse: () => printers.first,
      );

      // 3. ПОДГОТОВКА ШРИФТА (Roboto Mono отлично поддерживает кириллицу)
      final font = await PdfGoogleFonts.robotoMonoRegular();
      final boldFont = await PdfGoogleFonts.robotoMonoBold();

      // Формат ленты: ширина 80мм, высота бесконечная
      // Официальный стандартный формат для чековой ленты 80мм
      final format = PdfPageFormat.roll80.copyWith(
        marginBottom: 10 * PdfPageFormat.mm,
      );

      final pdf = pw.Document();

      // 4. ВЕРСТКА ЧЕКА
      pdf.addPage(
        pw.Page(
          pageFormat: format,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  'РАШТ ЭКСПРЕСС КАРГО',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: boldFont, fontSize: 18),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'Кассовый чек',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: font, fontSize: 14),
                ),
                pw.Text(
                  'Чек №: ${saleId.toString().padLeft(5, '0')}',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: font, fontSize: 12),
                ),
                pw.SizedBox(height: 5),
                pw.Divider(borderStyle: pw.BorderStyle.dashed),

                // СПИСОК ТОВАРОВ (Синее предупреждение toList убрано)
                ...items.map((item) {
                  return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        item['name'],
                        style: pw.TextStyle(font: boldFont, fontSize: 12),
                      ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '${item['qty']} x ${item['price']}',
                            style: pw.TextStyle(font: font, fontSize: 12),
                          ),
                          pw.Text(
                            '${item['total']}',
                            style: pw.TextStyle(font: boldFont, fontSize: 12),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                    ],
                  );
                }),

                pw.Divider(borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 5),

                // ИТОГИ
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'ИТОГО:',
                      style: pw.TextStyle(font: boldFont, fontSize: 16),
                    ),
                    pw.Text(
                      totalAmount.toStringAsFixed(2),
                      style: pw.TextStyle(font: boldFont, fontSize: 16),
                    ),
                  ],
                ),
                pw.SizedBox(height: 5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Оплата ($paymentType):',
                      style: pw.TextStyle(font: font, fontSize: 12),
                    ),
                    pw.Text(
                      cashGiven.toStringAsFixed(2),
                      style: pw.TextStyle(font: font, fontSize: 12),
                    ),
                  ],
                ),
                if (change > 0) ...[
                  pw.SizedBox(height: 2),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Сдача:',
                        style: pw.TextStyle(font: boldFont, fontSize: 12),
                      ),
                      pw.Text(
                        change.toStringAsFixed(2),
                        style: pw.TextStyle(font: boldFont, fontSize: 12),
                      ),
                    ],
                  ),
                ],

                pw.SizedBox(height: 15),
                pw.Text(
                  'СПАСИБО ЗА ПОКУПКУ!',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: boldFont, fontSize: 14),
                ),
                pw.SizedBox(height: 10),
              ],
            );
          },
        ),
      );

      // 5. ТИХАЯ ПЕЧАТЬ ЧЕРЕЗ ЯДРО WINDOWS
      final success = await Printing.directPrintPdf(
        printer: targetPrinter,
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );

      return success ? "OK" : "Windows отменила задание печати.";
    } catch (e) {
      return "Системная ошибка: $e";
    }
  }
}
