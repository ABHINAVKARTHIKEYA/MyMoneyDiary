import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/account.dart';
import '../models/transaction_model.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';

class CsvImportScreen extends StatefulWidget {
  final Account? preselectedAccount;

  const CsvImportScreen({super.key, this.preselectedAccount});

  @override
  State<CsvImportScreen> createState() => _CsvImportScreenState();
}

class _CsvImportScreenState extends State<CsvImportScreen> {
  Account? _selectedAccount;
  String? _filePath;
  String? _fileName;
  List<List<dynamic>> _rawRows = [];
  List<String> _headers = [];

  // Column mapping indexes (-1 if not mapped)
  int _dateColIndex = -1;
  int _descColIndex = -1;
  int _amountColIndex = -1;
  int _debitColIndex = -1;
  int _creditColIndex = -1;
  int _categoryColIndex = -1;
  int _refColIndex = -1;

  bool _hasSeparateDebitCredit = false;
  bool _isImporting = false;
  String? _importStatusMessage;

  @override
  void initState() {
    super.initState();
    _selectedAccount = widget.preselectedAccount;
  }

  Future<void> _pickCsvFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );
      if (result == null || result.files.single.path == null) return;

      final path = result.files.single.path!;
      final file = File(path);
      final content = await file.readAsString();

      // Try CSV converter
      final converter = const CsvToListConverter(shouldParseNumbers: false, eol: '\n');
      var rows = converter.convert(content);
      if (rows.isEmpty || rows.length < 2) {
        // Try CRLF
        final converterCrlf = const CsvToListConverter(shouldParseNumbers: false, eol: '\r\n');
        rows = converterCrlf.convert(content);
      }

      if (rows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selected CSV file is empty.')),
          );
        }
        return;
      }

      // First row as headers
      final headerRow = rows.first.map((e) => e.toString().trim()).toList();
      final dataRows = rows.skip(1).where((r) => r.any((c) => c.toString().trim().isNotEmpty)).toList();

      setState(() {
        _filePath = path;
        _fileName = result.files.single.name;
        _headers = headerRow;
        _rawRows = dataRows;
        _autoDetectColumns(headerRow);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to read CSV: $e')),
        );
      }
    }
  }

  void _autoDetectColumns(List<String> headers) {
    for (int i = 0; i < headers.length; i++) {
      final h = headers[i].toLowerCase();
      if (_dateColIndex == -1 && (h.contains('date') || h.contains('txn date') || h.contains('time'))) {
        _dateColIndex = i;
      } else if (_descColIndex == -1 && (h.contains('desc') || h.contains('narration') || h.contains('particulars') || h.contains('remark') || h.contains('payee'))) {
        _descColIndex = i;
      } else if (_amountColIndex == -1 && (h == 'amount' || h.contains('net amount') || h.contains('transaction amount'))) {
        _amountColIndex = i;
      } else if (_debitColIndex == -1 && (h.contains('debit') || h.contains('withdrawal') || h.contains('dr'))) {
        _debitColIndex = i;
        _hasSeparateDebitCredit = true;
      } else if (_creditColIndex == -1 && (h.contains('credit') || h.contains('deposit') || h.contains('cr'))) {
        _creditColIndex = i;
        _hasSeparateDebitCredit = true;
      } else if (_categoryColIndex == -1 && (h.contains('cat') || h.contains('type') || h.contains('head'))) {
        _categoryColIndex = i;
      } else if (_refColIndex == -1 && (h.contains('ref') || h.contains('cheque') || h.contains('utr') || h.contains('chq'))) {
        _refColIndex = i;
      }
    }
  }

  DateTime? _parseDate(String raw) {
    final cleaned = raw.trim();
    if (cleaned.isEmpty) return null;

    final formats = [
      'yyyy-MM-dd',
      'dd/MM/yyyy',
      'dd-MM-yyyy',
      'MM/dd/yyyy',
      'dd MMM yyyy',
      'yyyy/MM/dd',
      'dd-MMM-yyyy',
    ];

    for (final f in formats) {
      try {
        return DateFormat(f).parse(cleaned);
      } catch (_) {}
    }
    return DateTime.tryParse(cleaned);
  }

  double _parseAmount(dynamic raw) {
    if (raw == null) return 0.0;
    var str = raw.toString().replaceAll(',', '').replaceAll('₹', '').replaceAll('\$', '').trim();
    // Handle CR/DR suffix
    bool isNeg = false;
    if (str.toUpperCase().endsWith('DR')) {
      str = str.substring(0, str.length - 2).trim();
    } else if (str.toUpperCase().endsWith('CR')) {
      str = str.substring(0, str.length - 2).trim();
    }
    final val = double.tryParse(str) ?? 0.0;
    return isNeg ? -val.abs() : val;
  }

  Future<void> _executeImport() async {
    if (_selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select the target account for this statement.')),
      );
      return;
    }

    if (_dateColIndex == -1 || (_amountColIndex == -1 && (_debitColIndex == -1 && _creditColIndex == -1))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please map at least Date and Amount (or Debit/Credit) columns.')),
      );
      return;
    }

    setState(() {
      _isImporting = true;
      _importStatusMessage = 'Importing statement rows...';
    });

    final finance = context.read<FinanceProvider>();
    int importedCount = 0;
    int skippedDuplicates = 0;
    int errorCount = 0;

    for (final row in _rawRows) {
      try {
        final dateStr = _dateColIndex >= 0 && _dateColIndex < row.length ? row[_dateColIndex].toString() : '';
        final date = _parseDate(dateStr) ?? DateTime.now();

        final desc = _descColIndex >= 0 && _descColIndex < row.length ? row[_descColIndex].toString().trim() : 'CSV Statement Entry';
        final category = _categoryColIndex >= 0 && _categoryColIndex < row.length ? row[_categoryColIndex].toString().trim() : 'Statement Import';
        final ref = _refColIndex >= 0 && _refColIndex < row.length ? row[_refColIndex].toString().trim() : null;

        double amount = 0.0;
        TransactionType type = TransactionType.expense;

        if (_hasSeparateDebitCredit && _debitColIndex >= 0 && _creditColIndex >= 0) {
          final debitVal = _debitColIndex < row.length ? _parseAmount(row[_debitColIndex]) : 0.0;
          final creditVal = _creditColIndex < row.length ? _parseAmount(row[_creditColIndex]) : 0.0;

          if (debitVal > 0) {
            amount = debitVal;
            type = TransactionType.expense;
          } else if (creditVal > 0) {
            amount = creditVal;
            type = TransactionType.income;
          } else {
            continue; // Skip zero line
          }
        } else if (_amountColIndex >= 0 && _amountColIndex < row.length) {
          final rawAmt = _parseAmount(row[_amountColIndex]);
          if (rawAmt == 0) continue;
          amount = rawAmt.abs();
          type = rawAmt < 0 ? TransactionType.expense : TransactionType.income;
        }

        if (amount <= 0) continue;

        // Deterministic reference id for duplicate prevention
        final externalRef = ref != null && ref.isNotEmpty
            ? ref
            : 'CSV-${_selectedAccount!.id}-${date.millisecondsSinceEpoch}-$amount-${desc.hashCode}';

        final tx = TransactionModel(
          accountId: _selectedAccount!.id!,
          type: type,
          amount: amount,
          category: category.isNotEmpty ? category : 'Statement Import',
          note: desc,
          date: date,
          externalRefId: externalRef,
          referenceNumber: ref,
          source: 'csv_import',
          debitAccountName: type == TransactionType.income ? 'Payer' : _selectedAccount!.name,
          creditAccountName: type == TransactionType.income ? _selectedAccount!.name : 'Payee',
        );

        final res = await finance.addTransaction(tx);
        if (res == -1) {
          skippedDuplicates++;
        } else {
          importedCount++;
        }
      } catch (e) {
        errorCount++;
      }
    }

    setState(() {
      _isImporting = false;
      _importStatusMessage = 'Finished: $importedCount imported, $skippedDuplicates duplicates skipped, $errorCount errors.';
    });

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.creditGreen),
              SizedBox(width: 8),
              Text('Import Complete'),
            ],
          ),
          content: Text(
            'Successfully imported $importedCount balanced double-entry transactions to ${_selectedAccount!.name}.\n\n'
            '• New Entries: $importedCount\n'
            '• Duplicates Skipped: $skippedDuplicates\n'
            '• Unparseable / Empty: $errorCount',
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emeraldPrimary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('View Ledgers'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final accounts = finance.accounts;

    if (_selectedAccount == null && accounts.isNotEmpty) {
      _selectedAccount = accounts.firstWhere(
        (a) => a.code == 'ASSET_SALARY_BANK',
        orElse: () => accounts.first,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import CSV Statement'),
        actions: [
          if (_rawRows.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.file_upload),
              tooltip: 'Start Import',
              onPressed: _isImporting ? null : _executeImport,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account & File Selector Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '1. Target Account & File Selection',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Account>(
                      value: _selectedAccount,
                      decoration: const InputDecoration(
                        labelText: 'Select Target Account *',
                        prefixIcon: Icon(Icons.account_balance, color: AppTheme.emeraldPrimary),
                        border: OutlineInputBorder(),
                      ),
                      items: accounts.map((acc) {
                        return DropdownMenuItem(
                          value: acc,
                          child: Text('${acc.name} (${acc.category.displayName})'),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedAccount = val),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.attach_file),
                            label: Text(_fileName ?? 'Choose Bank / Credit Card CSV File'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: AppTheme.emeraldPrimary),
                            ),
                            onPressed: _pickCsvFile,
                          ),
                        ),
                      ],
                    ),
                    if (_fileName != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Loaded ${_rawRows.length} rows from $_fileName',
                        style: const TextStyle(fontSize: 12, color: AppTheme.creditGreen, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            if (_headers.isNotEmpty) ...[
              const SizedBox(height: 20),

              // Column Mapping Card
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '2. Column Mapping',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          FilterChip(
                            label: const Text('Separate Dr / Cr Columns'),
                            selected: _hasSeparateDebitCredit,
                            onSelected: (val) => setState(() => _hasSeparateDebitCredit = val),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildColumnDropdown('Date Column *', _dateColIndex, (idx) => setState(() => _dateColIndex = idx)),
                      const SizedBox(height: 10),
                      _buildColumnDropdown('Description / Narration Column *', _descColIndex, (idx) => setState(() => _descColIndex = idx)),
                      const SizedBox(height: 10),
                      if (!_hasSeparateDebitCredit)
                        _buildColumnDropdown('Amount Column *', _amountColIndex, (idx) => setState(() => _amountColIndex = idx))
                      else ...[
                        _buildColumnDropdown('Debit / Withdrawal Column *', _debitColIndex, (idx) => setState(() => _debitColIndex = idx)),
                        const SizedBox(height: 10),
                        _buildColumnDropdown('Credit / Deposit Column *', _creditColIndex, (idx) => setState(() => _creditColIndex = idx)),
                      ],
                      const SizedBox(height: 10),
                      _buildColumnDropdown('Category Column (Optional)', _categoryColIndex, (idx) => setState(() => _categoryColIndex = idx)),
                      const SizedBox(height: 10),
                      _buildColumnDropdown('Reference / Cheque No (Optional)', _refColIndex, (idx) => setState(() => _refColIndex = idx)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Preview Section
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '3. Sample Preview (First 5 Rows)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: [
                            const DataColumn(label: Text('Date')),
                            const DataColumn(label: Text('Description')),
                            const DataColumn(label: Text('Amount')),
                            const DataColumn(label: Text('Category')),
                          ],
                          rows: _rawRows.take(5).map((row) {
                            final dStr = _dateColIndex >= 0 && _dateColIndex < row.length ? row[_dateColIndex].toString() : '-';
                            final desc = _descColIndex >= 0 && _descColIndex < row.length ? row[_descColIndex].toString() : '-';
                            final cat = _categoryColIndex >= 0 && _categoryColIndex < row.length ? row[_categoryColIndex].toString() : 'General';
                            String amtStr = '-';
                            if (_hasSeparateDebitCredit) {
                              final dr = _debitColIndex >= 0 && _debitColIndex < row.length ? row[_debitColIndex].toString() : '';
                              final cr = _creditColIndex >= 0 && _creditColIndex < row.length ? row[_creditColIndex].toString() : '';
                              amtStr = dr.isNotEmpty ? '- ₹$dr' : '+ ₹$cr';
                            } else if (_amountColIndex >= 0 && _amountColIndex < row.length) {
                              amtStr = '₹ ${row[_amountColIndex]}';
                            }
                            return DataRow(cells: [
                              DataCell(Text(dStr)),
                              DataCell(Text(desc, overflow: TextOverflow.ellipsis)),
                              DataCell(Text(amtStr)),
                              DataCell(Text(cat)),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Import CTA Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isImporting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.download_done),
                  label: Text(_isImporting ? 'Processing Import...' : 'Import ${_rawRows.length} Transactions'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emeraldPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isImporting ? null : _executeImport,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildColumnDropdown(String label, int selectedIndex, ValueChanged<int> onChanged) {
    return DropdownButtonFormField<int>(
      value: selectedIndex >= 0 && selectedIndex < _headers.length ? selectedIndex : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: [
        const DropdownMenuItem<int>(value: -1, child: Text('-- None --', style: TextStyle(color: Colors.grey))),
        ...List.generate(_headers.length, (i) {
          return DropdownMenuItem<int>(
            value: i,
            child: Text('Col ${i + 1}: ${_headers[i]}', overflow: TextOverflow.ellipsis),
          );
        }),
      ],
      onChanged: (val) {
        if (val != null) onChanged(val);
      },
    );
  }
}
