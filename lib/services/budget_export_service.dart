import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import '../core/services/logger_service.dart';
import '../models/budget.dart';
import '../models/budget_transaction.dart';
import '../models/budget_category.dart';
import 'budget_transaction_service.dart';
import 'budget_category_service.dart';
import 'budget_analytics_service.dart';
import 'package:share_plus/share_plus.dart';

/// Service for exporting budget data to PDF and CSV
class BudgetExportService {
  final BudgetTransactionService _transactionService = BudgetTransactionService();
  final BudgetCategoryService _categoryService = BudgetCategoryService();
  final BudgetAnalyticsService _analyticsService = BudgetAnalyticsService();

  /// Export budget to PDF
  Future<File> exportBudgetToPdf({
    required Budget budget,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final transactions = await _transactionService.getTransactions(
        budgetId: budget.id,
        startDate: startDate ?? budget.startDate,
        endDate: endDate ?? budget.endDate,
      );

      final categories = await _categoryService.getCategories(budgetId: budget.id);
      final health = await _analyticsService.getBudgetHealth(
        budget: budget,
        startDate: startDate,
        endDate: endDate,
      );

      final pdf = pw.Document();
      final dateFormat = DateFormat('MMM dd, yyyy');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              // Header
              pw.Header(
                level: 0,
                child: pw.Text(
                  budget.name,
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 20),

              // Budget Summary
              pw.Text(
                'Budget Summary',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                children: [
                  _buildTableRow('Total Budget', '\$${budget.totalAmount.toStringAsFixed(2)}'),
                  _buildTableRow('Spent', '\$${health.spent.toStringAsFixed(2)}'),
                  _buildTableRow('Remaining', '\$${health.remaining.toStringAsFixed(2)}'),
                  _buildTableRow('Percent Used', '${health.percentUsed.toStringAsFixed(1)}%'),
                  _buildTableRow('Period', '${dateFormat.format(budget.startDate)} - ${dateFormat.format(budget.endDate)}'),
                ],
              ),
              pw.SizedBox(height: 20),

              // Transactions
              pw.Text(
                'Transactions',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  _buildTableRow('Date', 'Description', 'Category', 'Amount', isHeader: true),
                  ...transactions.map((t) => _buildTableRow(
                        dateFormat.format(t.date),
                        t.description,
                        categories.firstWhere((c) => c.id == t.categoryId, orElse: () => categories.first).name,
                        '${t.type == TransactionType.income ? '+' : '-'}\$${t.amount.toStringAsFixed(2)}',
                      )),
                ],
              ),
            ];
          },
        ),
      );

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/budget_${budget.id}_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      Logger.info('Exported budget to PDF: ${file.path}', tag: 'BudgetExportService');
      return file;
    } catch (e) {
      Logger.error('Error exporting budget to PDF', error: e, tag: 'BudgetExportService');
      rethrow;
    }
  }

  pw.TableRow _buildTableRow(String col1, [String? col2, String? col3, String? col4, bool isHeader = false]) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(
            col1,
            style: isHeader ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null,
          ),
        ),
        if (col2 != null)
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              col2,
              style: isHeader ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null,
            ),
          ),
        if (col3 != null)
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              col3,
              style: isHeader ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null,
            ),
          ),
        if (col4 != null)
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              col4,
              style: isHeader ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null,
            ),
          ),
      ],
    );
  }

  /// Export budget transactions to CSV
  Future<File> exportTransactionsToCsv({
    required Budget budget,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final transactions = await _transactionService.getTransactions(
        budgetId: budget.id,
        startDate: startDate ?? budget.startDate,
        endDate: endDate ?? budget.endDate,
      );

      final categories = await _categoryService.getCategories(budgetId: budget.id);
      final categoryMap = {for (var c in categories) c.id: c};

      final dateFormat = DateFormat('yyyy-MM-dd');
      final csvData = [
        ['Date', 'Type', 'Description', 'Category', 'Amount'],
        ...transactions.map((t) => [
              dateFormat.format(t.date),
              t.type.name,
              t.description,
              categoryMap[t.categoryId]?.name ?? 'Uncategorized',
              t.amount.toStringAsFixed(2),
            ]),
      ];

      final csvString = const ListToCsvConverter().convert(csvData);
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/budget_transactions_${budget.id}_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csvString);

      Logger.info('Exported transactions to CSV: ${file.path}', tag: 'BudgetExportService');
      return file;
    } catch (e) {
      Logger.error('Error exporting transactions to CSV', error: e, tag: 'BudgetExportService');
      rethrow;
    }
  }

  /// Share exported file
  Future<void> shareExportedFile(File file) async {
    try {
      await Share.shareXFiles([XFile(file.path)], text: 'Budget Export');
    } catch (e) {
      Logger.error('Error sharing exported file', error: e, tag: 'BudgetExportService');
      rethrow;
    }
  }
}

