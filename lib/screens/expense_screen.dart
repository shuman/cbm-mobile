import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_exceptions.dart';
import 'widgets/app_drawer.dart';
import 'widgets/detail_sheet_helpers.dart' as detailSheet;
import 'widgets/empty_state.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  List<dynamic> expenses = [];
  bool isLoading = true;
  String? error;
  bool isPermissionError = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedStatus;
  String? _selectedType;
  String? _selectedMethod;

  List<dynamic> get _filteredExpenses {
    final query = _searchQuery.trim().toLowerCase();

    return expenses.where((expense) {
      final status = detailSheet.valueOrNA(expense['payment_status']?['name']);
      final type = detailSheet.valueOrNA(expense['expense_type']?['name']);
      final method = detailSheet.valueOrNA(expense['payment_method']?['name']);

      if (_selectedStatus != null && _selectedStatus != status) return false;
      if (_selectedType != null && _selectedType != type) return false;
      if (_selectedMethod != null && _selectedMethod != method) return false;

      if (query.isEmpty) return true;

      final searchBlob = [
        _expenseDisplayTitle(expense),
        _extractVendorName(expense),
        type,
        detailSheet.valueOrNA(expense['expense_type']?['expense_type_category']?['name']),
        status,
        method,
        detailSheet.valueOrNA(expense['transaction_id']),
        detailSheet.valueOrNA(expense['payment_reference_number']),
        detailSheet.valueOrNA(expense['description']),
      ].join(' ').toLowerCase();

      return searchBlob.contains(query);
    }).toList();
  }

  List<String> _uniqueOptions(String keyPath) {
    final options = <String>{};
    for (final expense in expenses) {
      final value = _valueFromPath(expense, keyPath).toString().trim();
      if (value.isNotEmpty && value.toLowerCase() != 'n/a' && value.toLowerCase() != 'null') {
        options.add(value);
      }
    }
    final list = options.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  dynamic _valueFromPath(dynamic source, String keyPath) {
    dynamic current = source;
    for (final segment in keyPath.split('.')) {
      if (current is! Map || !current.containsKey(segment)) {
        return 'N/A';
      }
      current = current[segment];
    }
    return detailSheet.valueOrNA(current);
  }

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      error = null;
      isPermissionError = false;
    });

    try {
      final response = await ApiService.fetchExpenses();
      if (!mounted) return;
      setState(() {
        expenses = response['items'] ?? [];
        isLoading = false;
      });
    } on PermissionException catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.message;
        isPermissionError = true;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        isPermissionError = false;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredExpenses = _filteredExpenses;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/expenses/add').then((_) => _loadExpenses()),
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: '/expenses'),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isPermissionError ? Icons.lock_outline : Icons.error_outline,
                        size: 64,
                        color: isPermissionError ? AppColors.warning : AppColors.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isPermissionError ? 'Access Denied' : 'Failed to load expenses',
                        style: AppTextStyles.h3,
                      ),
                      const SizedBox(height: 8),
                      Text(error!, style: AppTextStyles.caption, textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      if (!isPermissionError)
                        ElevatedButton(
                          onPressed: _loadExpenses,
                          child: const Text('Retry'),
                        ),
                    ],
                  ),
                )
              : expenses.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _loadExpenses,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.65,
                            child: EmptyState(
                              icon: Icons.receipt_long_outlined,
                              title: 'No Expenses',
                              message: 'No expenses have been added yet',
                              action: ElevatedButton.icon(
                                onPressed: () => context.push('/expenses/add').then((_) => _loadExpenses()),
                                icon: const Icon(Icons.add),
                                label: const Text('Add Expense'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        _buildSearchAndFilterBar(),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _loadExpenses,
                            child: filteredExpenses.isEmpty
                                ? ListView(
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                                    children: [
                                      Icon(Icons.search_off, size: 48, color: AppColors.textDisabled),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No matching expenses found',
                                        style: AppTextStyles.h3,
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Try changing search or filters',
                                        style: AppTextStyles.caption,
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: filteredExpenses.length,
                                    itemBuilder: (context, index) {
                                      final expense = filteredExpenses[index];
                                      return _buildExpenseCard(expense);
                                    },
                                  ),
                          ),
                        ),
                      ],
                    ),
      floatingActionButton: expenses.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => context.push('/expenses/add').then((_) => _loadExpenses()),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildSearchAndFilterBar() {
    final statusOptions = _uniqueOptions('payment_status.name');
    final typeOptions = _uniqueOptions('expense_type.name');
    final methodOptions = _uniqueOptions('payment_method.name');

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: AppColors.background,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search expense, vendor, type, transaction...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                      icon: const Icon(Icons.clear),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterDropdown(
                  label: 'Status',
                  value: _selectedStatus,
                  options: statusOptions,
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value;
                    });
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterDropdown(
                  label: 'Type',
                  value: _selectedType,
                  options: typeOptions,
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value;
                    });
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterDropdown(
                  label: 'Method',
                  value: _selectedMethod,
                  options: methodOptions,
                  onChanged: (value) {
                    setState(() {
                      _selectedMethod = value;
                    });
                  },
                ),
                if (_selectedStatus != null || _selectedType != null || _selectedMethod != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedStatus = null;
                          _selectedType = null;
                          _selectedMethod = null;
                        });
                      },
                      child: const Text('Clear Filters'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(8),
        color: AppColors.surface,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(label, style: AppTextStyles.caption),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text('All $label', style: AppTextStyles.body),
            ),
            ...options.map(
              (option) => DropdownMenuItem<String>(
                value: option,
                child: Text(option, style: AppTextStyles.body),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildExpenseCard(dynamic expense) {
    final amount =
        expense['amount'] is num ? expense['amount'] : (double.tryParse(expense['amount']?.toString() ?? '0') ?? 0.0);
    final title = _expenseDisplayTitle(expense);
    final typeName = detailSheet.valueOrNA(expense['expense_type']?['name']);
    final categoryName = detailSheet.valueOrNA(expense['expense_type']?['expense_type_category']?['name']);
    final paymentStatus = detailSheet.valueOrNA(expense['payment_status']?['name']);
    final paymentMethod = detailSheet.valueOrNA(expense['payment_method']?['name']);
    final expenseDate =
        (expense['expense_date'] ?? expense['purchase_date'] ?? expense['created_at'])?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showExpenseDetails(expense),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _extractVendorName(expense),
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '\$${amount.toStringAsFixed(2)}',
                    style: AppTextStyles.h3.copyWith(color: AppColors.error),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildMetaChip('Type', typeName),
                  _buildMetaChip('Category', categoryName),
                  _buildMetaChip('Status', paymentStatus),
                  _buildMetaChip('Method', paymentMethod),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(expenseDate),
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $value',
        style: AppTextStyles.caption,
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _extractVendorName(dynamic source, {String fallback = 'N/A'}) {
    if (source is! Map) return fallback;

    final vendor = source['vendor'];
    if (vendor is Map) {
      final candidates = [
        vendor['business_name'],
        vendor['name'],
        vendor['invited_name'],
        vendor['user']?['name'],
      ];
      for (final candidate in candidates) {
        final text = candidate?.toString().trim();
        if (text != null && text.isNotEmpty) {
          return text;
        }
      }
    }

    final direct = source['vendor_name']?.toString().trim();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    return fallback;
  }

  String _expenseDisplayTitle(dynamic source) {
    if (source is! Map) return 'Expense';

    final explicitTitle = source['title']?.toString().trim();
    if (explicitTitle != null && explicitTitle.isNotEmpty) {
      return explicitTitle;
    }

    final typeName = source['expense_type']?['name']?.toString().trim();
    final vendorName = _extractVendorName(source, fallback: '');

    if (typeName != null && typeName.isNotEmpty && vendorName.isNotEmpty) {
      return '$typeName • $vendorName';
    }
    if (typeName != null && typeName.isNotEmpty) {
      return typeName;
    }
    if (vendorName.isNotEmpty) {
      return vendorName;
    }
    return 'Expense';
  }

  void _showExpenseDetails(dynamic expense) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Expense Details', style: AppTextStyles.h2),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      detailSheet.DetailSection(
                        title: 'Summary',
                        children: [
                          detailSheet.DetailRow(label: 'Title', value: _expenseDisplayTitle(expense)),
                          detailSheet.DetailRow(label: 'Vendor', value: _extractVendorName(expense)),
                          detailSheet.DetailRow(label: 'Amount', value: detailSheet.formatCurrency(expense['amount'])),
                          detailSheet.DetailRow(
                              label: 'Payment Status',
                              value: detailSheet.valueOrNA(expense['payment_status']?['name'])),
                          detailSheet.DetailRow(
                              label: 'Approval Status',
                              value: detailSheet.valueOrNA(expense['approval_status']?['name'])),
                          detailSheet.DetailRow(
                              label: 'Type', value: detailSheet.valueOrNA(expense['expense_type']?['name'])),
                        ],
                      ),
                      const SizedBox(height: 12),
                      detailSheet.DetailSection(
                        title: 'Type Info',
                        children: [
                          detailSheet.DetailRow(
                              label: 'Type', value: detailSheet.valueOrNA(expense['expense_type']?['name'])),
                          detailSheet.DetailRow(
                              label: 'Category',
                              value: detailSheet.valueOrNA(expense['expense_type']?['expense_type_category']?['name'])),
                        ],
                      ),
                      const SizedBox(height: 12),
                      detailSheet.DetailSection(
                        title: 'Timeline',
                        children: [
                          detailSheet.DetailRow(
                              label: 'Expense Date',
                              value: detailSheet.formatDateTime(expense['expense_date'], includeTime: false)),
                          detailSheet.DetailRow(
                              label: 'Purchase Date',
                              value: detailSheet.formatDateTime(expense['purchase_date'], includeTime: false)),
                          detailSheet.DetailRow(
                              label: 'Payment Date',
                              value: detailSheet.formatDateTime(expense['payment_date'], includeTime: false)),
                          detailSheet.DetailRow(
                              label: 'Created At', value: detailSheet.formatDateTime(expense['created_at'])),
                          detailSheet.DetailRow(
                              label: 'Updated At', value: detailSheet.formatDateTime(expense['updated_at'])),
                        ],
                      ),
                      const SizedBox(height: 12),
                      detailSheet.DetailSection(
                        title: 'Payment Info',
                        children: [
                          detailSheet.DetailRow(
                              label: 'Method', value: detailSheet.valueOrNA(expense['payment_method']?['name'])),
                          detailSheet.DetailRow(
                              label: 'Reference', value: detailSheet.valueOrNA(expense['payment_reference_number'])),
                          detailSheet.DetailRow(
                              label: 'Payment Note', value: detailSheet.valueOrNA(expense['payment_note'])),
                          detailSheet.DetailRow(
                              label: 'Transaction ID', value: detailSheet.valueOrNA(expense['transaction_id'])),
                        ],
                      ),
                      const SizedBox(height: 12),
                      detailSheet.DetailSection(
                        title: 'Meta',
                        children: [
                          detailSheet.DetailRow(
                              label: 'Added By',
                              value: detailSheet.valueOrNA(
                                expense['created_by_user']?['name'] ??
                                    expense['api_user']?['name'] ??
                                    expense['created_by'],
                              )),
                          detailSheet.DetailRow(
                              label: 'Work Package', value: detailSheet.valueOrNA(expense['work_package_id'])),
                          detailSheet.DetailRow(
                              label: 'Active', value: expense['is_active'] == true ? 'Yes' : 'No'),
                        ],
                      ),
                      if (expense['description'] != null && expense['description'].toString().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        detailSheet.DetailSection(
                          title: 'Description',
                          children: [
                            Text(expense['description'].toString(), style: AppTextStyles.body),
                          ],
                        ),
                      ],
                      if (expense['notes'] != null && expense['notes'].toString().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        detailSheet.DetailSection(
                          title: 'Notes',
                          children: [
                            Text(expense['notes'].toString(), style: AppTextStyles.body),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
