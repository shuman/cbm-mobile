import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_exceptions.dart';
import 'widgets/app_drawer.dart';
import 'widgets/detail_sheet_helpers.dart' as detailSheet;
import 'widgets/empty_state.dart';

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  List<dynamic> deposits = [];
  List<dynamic> depositTypes = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  String? error;
  bool isPermissionError = false;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';
  String? _selectedTypeId;
  String? _selectedCategoryId;
  int _currentPage = 1;
  int _totalCount = 0;
  static const int _pageSize = 10;

  bool get _hasMore => deposits.length < _totalCount;
  bool get _hasActiveFilters =>
      _searchQuery.trim().isNotEmpty || _selectedTypeId != null || _selectedCategoryId != null;

  List<dynamic> get _categoryOptions {
    final categories = <String, Map<String, dynamic>>{};

    for (final type in depositTypes) {
      if (_selectedTypeId != null && type['id'] != _selectedTypeId) continue;
      final category = type['deposit_type_category'];
      if (category is Map && category['id'] != null) {
        categories[category['id'].toString()] = {
          'id': category['id'].toString(),
          'name': detailSheet.valueOrNA(category['name']),
        };
      }
    }

    final items = categories.values.toList();
    items.sort((a, b) => a['name'].toString().toLowerCase().compareTo(b['name'].toString().toLowerCase()));
    return items;
  }

  @override
  void initState() {
    super.initState();
    _loadFilterData();
    _loadDeposits(reset: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFilterData() async {
    try {
      final response = await ApiService.fetchDepositTypes();
      if (!mounted) return;
      final items = response['items'];
      setState(() {
        depositTypes = items is List ? items : [];
      });
    } catch (_) {}
  }

  Future<void> _loadDeposits({required bool reset}) async {
    if (!mounted) return;

    setState(() {
      if (reset) {
        isLoading = true;
      } else {
        isLoadingMore = true;
      }
      error = null;
      isPermissionError = false;
    });

    try {
      final response = await ApiService.fetchDeposits(
        page: _currentPage,
        limit: _pageSize,
        sort: 'created_at',
        order: 'desc',
        search: _searchQuery,
        depositTypeId: _selectedTypeId,
        depositTypeCategoryId: _selectedCategoryId,
      );
      if (!mounted) return;

      final items = response['items'];
      final pageItems = items is List ? items : <dynamic>[];
      final count = int.tryParse(response['count']?.toString() ?? '0') ?? 0;

      setState(() {
        _totalCount = count;
        if (reset) {
          deposits = pageItems;
        } else {
          deposits.addAll(pageItems);
        }
        isLoading = false;
        isLoadingMore = false;
      });
    } on PermissionException catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.message;
        isPermissionError = true;
        isLoading = false;
        isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        isPermissionError = false;
        isLoading = false;
        isLoadingMore = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    setState(() {
      _searchQuery = value;
    });

    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      _refreshFromFilters();
    });
  }

  Future<void> _refreshFromFilters() async {
    _currentPage = 1;
    await _loadDeposits(reset: true);
  }

  Future<void> _loadMore() async {
    if (!_hasMore || isLoadingMore || isLoading) return;
    _currentPage += 1;
    await _loadDeposits(reset: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deposits'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/deposits/add').then((_) => _refreshFromFilters()),
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: '/deposits'),
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
                        isPermissionError ? 'Access Denied' : 'Failed to load deposits',
                        style: AppTextStyles.h3,
                      ),
                      const SizedBox(height: 8),
                      Text(error!, style: AppTextStyles.caption, textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      if (!isPermissionError)
                        ElevatedButton(
                          onPressed: _refreshFromFilters,
                          child: const Text('Retry'),
                        ),
                    ],
                  ),
                )
              : !isLoading && deposits.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _refreshFromFilters,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.65,
                            child: _hasActiveFilters
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.search_off, size: 48, color: AppColors.textDisabled),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No matching deposits found',
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
                                : EmptyState(
                                    icon: Icons.account_balance_wallet_outlined,
                                    title: 'No Deposits',
                                    message: 'No deposits have been added yet',
                                    action: ElevatedButton.icon(
                                      onPressed: () => context.push('/deposits/add').then((_) => _refreshFromFilters()),
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add Deposit'),
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
                            onRefresh: _refreshFromFilters,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: deposits.length + (_hasMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == deposits.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4, bottom: 12),
                                    child: Center(
                                      child: ElevatedButton(
                                        onPressed: isLoadingMore ? null : _loadMore,
                                        child: isLoadingMore
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              )
                                            : const Text('Load More'),
                                      ),
                                    ),
                                  );
                                }

                                final deposit = deposits[index];
                                return _buildDepositCard(deposit);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
      floatingActionButton: deposits.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => context.push('/deposits/add').then((_) => _refreshFromFilters()),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildSearchAndFilterBar() {
    final categoryOptions = _categoryOptions;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: AppColors.background,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search member, type, transaction...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                        _refreshFromFilters();
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
                  label: 'Type',
                  value: _selectedTypeId,
                  options: depositTypes,
                  labelBuilder: (item) => detailSheet.valueOrNA(item['name']),
                  onChanged: (value) {
                    setState(() {
                      _selectedTypeId = value;
                      if (_selectedCategoryId != null &&
                          !categoryOptions.any((category) => category['id'].toString() == _selectedCategoryId)) {
                        _selectedCategoryId = null;
                      }
                    });
                    _refreshFromFilters();
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterDropdown(
                  label: 'Category',
                  value: _selectedCategoryId,
                  options: categoryOptions,
                  labelBuilder: (item) => detailSheet.valueOrNA(item['name']),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategoryId = value;
                    });
                    _refreshFromFilters();
                  },
                ),
                if (_selectedTypeId != null || _selectedCategoryId != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedTypeId = null;
                          _selectedCategoryId = null;
                        });
                        _refreshFromFilters();
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
    required List<dynamic> options,
    required String Function(dynamic item) labelBuilder,
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
        child: DropdownButton<String?>(
          value: value,
          hint: Text(label, style: AppTextStyles.caption),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text('All $label', style: AppTextStyles.body),
            ),
            ...options.map(
              (option) => DropdownMenuItem<String?>(
                value: option['id']?.toString(),
                child: Text(labelBuilder(option), style: AppTextStyles.body),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildDepositCard(dynamic deposit) {
    final amount =
        deposit['amount'] is num ? deposit['amount'] : (double.tryParse(deposit['amount']?.toString() ?? '0') ?? 0.0);
    final memberName = _extractMemberName(deposit);
    final typeName = deposit['deposit_type']?['name']?.toString() ?? 'Unknown Type';
    final createdAt = deposit['created_at']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showDepositDetails(deposit),
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
                          memberName,
                          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          typeName,
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '\$${amount.toStringAsFixed(2)}',
                    style: AppTextStyles.h3.copyWith(color: AppColors.success),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(createdAt),
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

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _extractMemberName(dynamic source, {String fallback = 'Unknown Member'}) {
    if (source is! Map) return fallback;

    final directName = source['member_name']?.toString().trim();
    if (directName != null && directName.isNotEmpty) {
      return directName;
    }

    final nestedMember = source['member'];
    if (nestedMember is Map) {
      final nestedName = nestedMember['name']?.toString().trim();
      if (nestedName != null && nestedName.isNotEmpty) {
        return nestedName;
      }

      final nestedUser = nestedMember['user'];
      if (nestedUser is Map) {
        final nestedUserName = nestedUser['name']?.toString().trim();
        if (nestedUserName != null && nestedUserName.isNotEmpty) {
          return nestedUserName;
        }
      }

      final invitedName = nestedMember['invited_name']?.toString().trim();
      if (invitedName != null && invitedName.isNotEmpty) {
        return invitedName;
      }
    }

    const directNameKeys = ['memberName', 'member'];
    for (final key in directNameKeys) {
      final value = source[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    final memberId = source['member_id']?.toString().trim();
    if (memberId != null && memberId.isNotEmpty) {
      return 'Member #$memberId';
    }

    return fallback;
  }

  Future<void> _showDepositDetails(dynamic deposit) async {
    if (!mounted) return;

    BuildContext? loadingDialogContext;

    Future<void> closeLoadingDialog() async {
      final dialogCtx = loadingDialogContext;
      if (dialogCtx == null) return;

      loadingDialogContext = null;
      if (Navigator.of(dialogCtx).canPop()) {
        Navigator.of(dialogCtx).pop();
        await Future<void>.delayed(Duration.zero);
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        loadingDialogContext = dialogContext;
        return const Center(child: CircularProgressIndicator());
      },
    );

    await Future<void>.delayed(Duration.zero);

    try {
      final response = await ApiService.fetchDepositDetails(deposit['id']);

      if (!mounted) return;
      await closeLoadingDialog();

      if (!response.containsKey('items')) {
        throw Exception('Invalid response format');
      }

      final items = response['items'];
      if (items is! List || items.isEmpty || items.first is! Map) {
        throw Exception('Invalid response data');
      }
      final details = items.first as Map;

      if (!mounted) return;

      await Future<void>.delayed(Duration.zero);

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
                        child: Text('Deposit Details', style: AppTextStyles.h2),
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
                            detailSheet.DetailRow(label: 'Member', value: _extractMemberName(details, fallback: 'N/A')),
                            detailSheet.DetailRow(
                                label: 'Total Amount', value: detailSheet.formatCurrency(details['total_amount'])),
                            detailSheet.DetailRow(label: 'Status', value: detailSheet.valueOrNA(details['status'])),
                            detailSheet.DetailRow(
                                label: 'Approval', value: detailSheet.valueOrNA(details['approval_status'])),
                          ],
                        ),
                        const SizedBox(height: 12),
                        detailSheet.DetailSection(
                          title: 'Member Info',
                          children: [
                            detailSheet.DetailRow(
                                label: 'Member Code', value: detailSheet.valueOrNA(details['member_code'])),
                            detailSheet.DetailRow(
                                label: 'Email', value: detailSheet.valueOrNA(details['member_email'])),
                            detailSheet.DetailRow(
                                label: 'Phone', value: detailSheet.valueOrNA(details['member_phone'])),
                          ],
                        ),
                        const SizedBox(height: 12),
                        detailSheet.DetailSection(
                          title: 'Deposit Info',
                          children: [
                            detailSheet.DetailRow(
                                label: 'Amount', value: detailSheet.formatCurrency(details['amount'])),
                            detailSheet.DetailRow(
                                label: 'Credit Applied', value: detailSheet.formatCurrency(details['credit_applied'])),
                            detailSheet.DetailRow(
                                label: 'Currency', value: detailSheet.valueOrNA(details['currency_code'])),
                            detailSheet.DetailRow(
                                label: 'Type', value: detailSheet.valueOrNA(details['deposit_type']?['name'])),
                            detailSheet.DetailRow(
                                label: 'Category',
                                value:
                                    detailSheet.valueOrNA(details['deposit_type']?['deposit_type_category']?['name'])),
                            detailSheet.DetailRow(
                                label: 'Receipt No', value: detailSheet.valueOrNA(details['receipt_no'])),
                            detailSheet.DetailRow(
                                label: 'TRX Unique ID', value: detailSheet.valueOrNA(details['trx_unique_id'])),
                            detailSheet.DetailRow(
                                label: 'Transaction ID', value: detailSheet.valueOrNA(details['transaction_id'])),
                          ],
                        ),
                        const SizedBox(height: 12),
                        detailSheet.DetailSection(
                          title: 'Timeline',
                          children: [
                            detailSheet.DetailRow(
                                label: 'Deposit Date',
                                value: detailSheet.formatDateTime(details['deposit_date'], includeTime: false)),
                            detailSheet.DetailRow(
                                label: 'Received At', value: detailSheet.formatDateTime(details['received_at'])),
                            detailSheet.DetailRow(
                                label: 'Settlement Date',
                                value: detailSheet.formatDateTime(details['settlement_date'])),
                            detailSheet.DetailRow(
                                label: 'Created At', value: detailSheet.formatDateTime(details['created_at'])),
                            detailSheet.DetailRow(
                                label: 'Updated At', value: detailSheet.formatDateTime(details['updated_at'])),
                          ],
                        ),
                        const SizedBox(height: 12),
                        detailSheet.DetailSection(
                          title: 'Users',
                          children: [
                            detailSheet.DetailRow(
                                label: 'Added By', value: detailSheet.valueOrNA(details['created_by_user']?['name'])),
                            detailSheet.DetailRow(
                                label: 'Received By',
                                value: detailSheet.valueOrNA(details['received_by_user']?['name'])),
                            detailSheet.DetailRow(
                                label: 'Updated By', value: detailSheet.valueOrNA(details['updated_by_user']?['name'])),
                          ],
                        ),
                        const SizedBox(height: 12),
                        detailSheet.DetailSection(
                          title: 'Payment Info',
                          children: [
                            detailSheet.DetailRow(
                                label: 'Payment Method',
                                value: detailSheet.valueOrNA(details['payment_method']?['name'])),
                            detailSheet.DetailRow(
                                label: 'Instrument No', value: detailSheet.valueOrNA(details['instrument_no'])),
                            detailSheet.DetailRow(
                                label: 'Instrument Date',
                                value: detailSheet.formatDateTime(details['instrument_date'], includeTime: false)),
                            detailSheet.DetailRow(
                                label: 'Payer Bank', value: detailSheet.valueOrNA(details['payer_bank_name'])),
                            detailSheet.DetailRow(
                                label: 'Payer Account', value: detailSheet.valueOrNA(details['payer_account_no'])),
                            detailSheet.DetailRow(
                                label: 'Branch', value: detailSheet.valueOrNA(details['branch_name'])),
                            detailSheet.DetailRow(
                                label: 'Bank Reference', value: detailSheet.valueOrNA(details['bank_reference'])),
                            detailSheet.DetailRow(
                                label: 'Bank Account',
                                value: detailSheet.valueOrNA(details['bank_account']?['account_name'])),
                          ],
                        ),
                        if (details['description'] != null && details['description'].toString().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          detailSheet.DetailSection(
                            title: 'Description',
                            children: [
                              Text(details['description'].toString(), style: AppTextStyles.body),
                            ],
                          ),
                        ],
                        if (details['notes'] != null && details['notes'].toString().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          detailSheet.DetailSection(
                            title: 'Notes',
                            children: [
                              Text(details['notes'].toString(), style: AppTextStyles.body),
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
    } catch (e) {
      if (!mounted) return;
      await closeLoadingDialog();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load deposit details: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
