import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/transaction_model.dart';

class StatementExporterService {
  static final DateFormat _dateFormat = DateFormat('dd-MM-yyyy');
  static final DateFormat _timeFormat = DateFormat('hh:mm a');
  static final NumberFormat _numFormat = NumberFormat('#,##,###.##');

  /// Export transactions to an Excel-compatible CSV file and trigger Android Share/Save
  static Future<String> exportToCsv({
    required List<TransactionModel> transactions,
    required String accountName,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final buffer = StringBuffer();

    // 1. CSV Headers
    buffer.writeln(
      'Date,Time,Transaction ID,Type,Amount (INR),Category,Payment Mode,Other Mode Details,Debit Account,Credit Account,Remarks,Reference ID,Source'
    );

    // 2. CSV Data Rows
    for (final tx in transactions) {
      final dateStr = _dateFormat.format(tx.date);
      final timeStr = _timeFormat.format(tx.date);
      final idStr = tx.id?.toString() ?? '';
      final typeStr = tx.type.key.toUpperCase();
      final amountStr = tx.amount.toStringAsFixed(2);
      final catStr = _csvEscape(tx.category);
      final modeStr = _csvEscape(tx.paymentMode);
      final otherModeStr = _csvEscape(tx.otherPaymentModeDetails ?? '');
      final debitStr = _csvEscape(tx.debitAccountName ?? '');
      final creditStr = _csvEscape(tx.creditAccountName ?? '');
      final noteStr = _csvEscape(tx.note);
      final refStr = _csvEscape(tx.externalRefId ?? '');
      final srcStr = _csvEscape(tx.source);

      buffer.writeln('$dateStr,$timeStr,$idStr,$typeStr,$amountStr,$catStr,$modeStr,$otherModeStr,$debitStr,$creditStr,$noteStr,$refStr,$srcStr');
    }

    // 3. Save File
    final dir = await getApplicationDocumentsDirectory();
    final cleanName = accountName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final fileName = '${cleanName}_Statement_${_dateFormat.format(fromDate)}_to_${_dateFormat.format(toDate)}.csv';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(buffer.toString());

    // 4. Share / Save
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Account Statement for $accountName (${_dateFormat.format(fromDate)} to ${_dateFormat.format(toDate)})',
      subject: '$accountName Statement',
    );

    return file.path;
  }

  /// Export transactions to a formatted PDF Document and trigger Android Share/Save
  static Future<String> exportToPdf({
    required List<TransactionModel> transactions,
    required String accountName,
    required DateTime fromDate,
    required DateTime toDate,
    String currencySymbol = '₹',
  }) async {
    final pdf = pw.Document();

    double totalInflow = 0.0;
    double totalOutflow = 0.0;
    for (final tx in transactions) {
      if (tx.type == TransactionType.credit) {
        totalInflow += tx.amount;
      } else {
        totalOutflow += tx.amount;
      }
    }
    final netFlow = totalInflow - totalOutflow;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'MY MONEY DIARY',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#0F3E33'),
                      ),
                    ),
                    pw.Text(
                      'Account Statement • All at one place',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      accountName,
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'Period: ${_dateFormat.format(fromDate)} to ${_dateFormat.format(toDate)}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ],
            ),
            pw.Divider(thickness: 1, color: PdfColor.fromHex('#B37400')),
            pw.SizedBox(height: 8),

            // Summary Cards Row
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#E8F5E9'),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Total Inflow (Credits)', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        pw.Text(
                          '+ $currencySymbol ${_numFormat.format(totalInflow)}',
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#2E7D32')),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#FFEBEE'),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Total Outflow (Debits)', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        pw.Text(
                          '- $currencySymbol ${_numFormat.format(totalOutflow)}',
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#C62828')),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#F5F5F5'),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Net Period Movement', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        pw.Text(
                          '$currencySymbol ${_numFormat.format(netFlow)}',
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F3E33')),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // Transactions Table
            if (transactions.isEmpty)
              pw.Center(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(32),
                  child: pw.Text('No transactions recorded for the selected period.', style: const pw.TextStyle(color: PdfColors.grey600)),
                ),
              )
            else
              pw.TableHelper.fromTextArray(
                context: context,
                border: pw.TableBorder.symmetric(
                  inside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                ),
                headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#0F3E33')),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellAlignment: pw.Alignment.centerLeft,
                columnWidths: {
                  0: const pw.FixedColumnWidth(65), // Date
                  1: const pw.FlexColumnWidth(2),   // Category & Remarks
                  2: const pw.FixedColumnWidth(55), // Mode
                  3: const pw.FixedColumnWidth(50), // Type
                  4: const pw.FixedColumnWidth(65), // Amount
                },
                headers: ['Date & Time', 'Category / Remarks', 'Mode', 'Type', 'Amount (INR)'],
                data: transactions.map((tx) {
                  final isCredit = tx.type == TransactionType.credit;
                  final typeLabel = tx.type.displayName;
                  final remarks = tx.note.isNotEmpty ? ' • ${tx.note}' : '';
                  final details = '${tx.category}$remarks';

                  return [
                    '${_dateFormat.format(tx.date)}\n${_timeFormat.format(tx.date)}',
                    details,
                    tx.paymentMode,
                    typeLabel,
                    '${isCredit ? "+" : "-"} ${_numFormat.format(tx.amount)}',
                  ];
                }).toList(),
              ),

            pw.SizedBox(height: 24),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())} • Confidential & Offline',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Page 1 of 1',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                ),
              ],
            ),
          ];
        },
      ),
    );

    // Save File
    final dir = await getApplicationDocumentsDirectory();
    final cleanName = accountName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final fileName = '${cleanName}_Statement_${_dateFormat.format(fromDate)}_to_${_dateFormat.format(toDate)}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    // Share / Save
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'PDF Statement for $accountName (${_dateFormat.format(fromDate)} to ${_dateFormat.format(toDate)})',
      subject: '$accountName Statement',
    );

    return file.path;
  }

  static String _csvEscape(String input) {
    if (input.contains(',') || input.contains('"') || input.contains('\n')) {
      return '"${input.replaceAll('"', '""')}"';
    }
    return input;
  }
}
