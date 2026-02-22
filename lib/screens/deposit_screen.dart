import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'widgets/app_drawer.dart';
import 'widgets/empty_state.dart';

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  List<dynamic> deposits = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadDeposits();
  }

  Future<void> _loadDeposits() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final response = await ApiService.fetchDeposits();
      if (!mounted) return;
      setState(() {
        deposits = response['items'] ?? [];
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deposits'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/deposits/add').then((_) => _loadDeposits()),
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: '/deposits'),
      body: RefreshIndicator(
        onRefresh: _loadDeposits,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text('Failed to load deposits', style: AppTextStyles.h3),
                        const SizedBox(height: 8),
                        Text(error!, style: AppTextStyles.caption, textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadDeposits,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : deposits.isEmpty
                    ? EmptyState(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'No Deposits',
                        message: 'No deposits have been added yet',
                        action: ElevatedButton.icon(
                          onPressed: () => context.push('/deposits/add').then((_) => _loadDeposits()),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Deposit'),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: deposits.length,
                        itemBuilder: (context, index) {
                          final deposit = deposits[index];
                          return _buildDepositCard(deposit);
                        },
                      ),
      ),
      floatingActionButton: deposits.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => context.push('/deposits/add').then((_) => _loadDeposits()),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildDepositCard(dynamic deposit) {
    final amount = deposit['amount'] is num ? deposit['amount'] : (double.tryParse(deposit['amount']?.toString() ?? '0') ?? 0.0);
    final memberName = deposit['member']?['name']?.toString() ?? 'Unknown Member';
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

  Future<void> _showDepositDetails(dynamic deposit) async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await ApiService.fetchDepositDetails(deposit['id']);
      
      if (!mounted) return;
      Navigator.pop(context);

      if (!response.containsKey('items')) {
        throw Exception('Invalid response format');
      }

      final details = response['items'];

      if (!mounted) return;
      
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Deposit Details', style: AppTextStyles.h2),
                      const Divider(height: 24),
                      _buildDetailRow('Member', details['member']?['name'] ?? 'N/A'),
                      const SizedBox(height: 12),
                      _buildDetailRow('Amount', '\$${details['amount']?.toString() ?? '0.00'}'),
                      const SizedBox(height: 12),
                      _buildDetailRow('Type', details['deposit_type']?['name'] ?? 'N/A'),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        'Category',
                        details['deposit_type']?['deposit_type_category']?['name'] ?? 'N/A',
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow('Transaction ID', details['trx_unique_id'] ?? 'N/A'),
                      const SizedBox(height: 12),
                      _buildDetailRow('Added By', details['api_user']?['name'] ?? 'N/A'),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        'Date',
                        details['created_at'] != null
                            ? DateFormat('dd MMM yyyy, hh:mm a').format(
                                DateTime.parse(details['created_at']),
                              )
                            : 'N/A',
                      ),
                      if (details['description'] != null && details['description'].toString().isNotEmpty) ...[
                        const Divider(height: 24),
                        Text('Description', style: AppTextStyles.h3),
                        const SizedBox(height: 8),
                        Text(details['description'], style: AppTextStyles.body),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load deposit details: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: AppTextStyles.bodySecondary),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
