import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class MemberDetailSheet extends StatelessWidget {
  final String? memberId;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String role;
  final String? memberCode;
  final String? joinedAt;
  final bool isActive;
  final String? invitationStatus;

  const MemberDetailSheet({
    super.key,
    required this.memberId,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.role,
    this.memberCode,
    this.joinedAt,
    required this.isActive,
    this.invitationStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
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
            child: memberId == null
                ? _buildBasicInfo(context)
                : FutureBuilder<Map<String, dynamic>>(
                    future: ApiService.fetchMemberDetails(memberId!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                                const SizedBox(height: 16),
                                Text(
                                  'Failed to load member details',
                                  style: AppTextStyles.body,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final data = snapshot.data ?? {};
                      final items = data['items'] is Map<String, dynamic>
                          ? data['items'] as Map<String, dynamic>
                          : <String, dynamic>{};

                      return _buildDetailContent(context, items);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfo(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          Text('No additional details available', style: AppTextStyles.bodySecondary),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailContent(BuildContext context, Map<String, dynamic> items) {
    final memberDetail = items['member'] is Map<String, dynamic>
        ? items['member'] as Map<String, dynamic>
        : <String, dynamic>{};

    final detailName = memberDetail['name']?.toString() ?? name;
    final detailEmail = memberDetail['email']?.toString() ?? email;
    final detailPhone = memberDetail['phone']?.toString() ?? phone;
    final detailAddress = memberDetail['address']?.toString() ?? address;

    final scheduledPayable = items['deposit_schedules_total_payable_amount'];
    final actualPayable = items['actual_payable_amount'];
    final scheduledPaid = items['deposit_schedules_total_paid_amount'];
    final depositsPaid = items['deposits_total_paid_amount'];
    final scheduledDue = items['deposit_schedules_total_due_amount'];
    final actualDue = items['actual_total_due_amount'];
    final totalPropertyShare = items['total_property_share'];
    final scheduledProgress = items['deposit_schedules_progress_percentage'];
    final actualProgress = items['actual_progress_percentage'];

    final propertyDetails = items['property_details'] is List ? items['property_details'] as List : [];
    final depositSchedules = items['deposit_schedules'] is List ? items['deposit_schedules'] as List : [];
    final deposits = items['deposits'] is List ? items['deposits'] as List : [];

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Member Information Card
                _buildSectionCard(
                  title: 'Member Information',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Name', detailName),
                      _buildInfoRow('Email', detailEmail),
                      _buildInfoRow('Phone', detailPhone),
                      _buildInfoRow('Address', detailAddress.isEmpty ? '-' : detailAddress),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Payment Summary
                _buildSectionCard(
                  title: 'Payment Summary',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCardWithSecondary(
                              'Scheduled Payable',
                              scheduledPayable,
                              'Actual',
                              actualPayable,
                              AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCardWithSecondary(
                              'Scheduled Paid',
                              scheduledPaid,
                              'Deposits',
                              depositsPaid,
                              AppColors.success,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCardWithSecondary(
                              'Scheduled Due',
                              scheduledDue,
                              'Actual',
                              actualDue,
                              AppColors.error,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              'Property Share',
                              totalPropertyShare != null ? '$totalPropertyShare%' : 'N/A',
                              AppColors.info,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (scheduledProgress != null) ...[
                        Row(
                          children: [
                            Text('Scheduled Progress', style: AppTextStyles.caption),
                            const SizedBox(width: 4),
                            Tooltip(
                              message: 'Progress based on scheduled deposit payments',
                              child: Icon(Icons.info_outline, size: 14, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: (scheduledProgress is num ? scheduledProgress.toDouble() : 0.0) / 100,
                          backgroundColor: AppColors.divider,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                        const SizedBox(height: 4),
                        Text('$scheduledProgress%', style: AppTextStyles.caption),
                      ],
                      if (actualProgress != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text('Actual Progress', style: AppTextStyles.caption),
                            const SizedBox(width: 4),
                            Tooltip(
                              message: 'Progress based on actual payments received',
                              child: Icon(Icons.info_outline, size: 14, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: (actualProgress is num ? actualProgress.toDouble() : 0.0) / 100,
                          backgroundColor: AppColors.divider,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.error),
                        ),
                        const SizedBox(height: 4),
                        Text('$actualProgress%', style: AppTextStyles.caption),
                      ],
                    ],
                  ),
                ),

                // Property Ownership
                if (propertyDetails.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildSectionCard(
                    title: 'Property Ownership',
                    child: Column(
                      children: [
                        ...propertyDetails.map<Widget>((property) => _buildPropertyRow(property)),
                      ],
                    ),
                  ),
                ],

                // Deposit Schedules
                if (depositSchedules.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildSectionCard(
                    title: 'Deposit Schedules',
                    child: _buildDepositSchedulesTable(depositSchedules),
                  ),
                ],

                // Payment History
                if (deposits.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildSectionCard(
                    title: 'Payment History',
                    child: _buildPaymentHistoryTable(deposits),
                  ),
                ],

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
        // Close button
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h3),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCardWithSecondary(
    String label,
    dynamic primaryValue,
    String secondaryLabel,
    dynamic secondaryValue,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                primaryValue != null ? '৳${_formatAmount(primaryValue)}' : '৳0',
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: '$secondaryLabel: ${secondaryValue != null ? '৳${_formatAmount(secondaryValue)}' : '৳0'}',
                child: Icon(Icons.info_outline, size: 14, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$secondaryLabel: ${secondaryValue != null ? '৳${_formatAmount(secondaryValue)}' : '৳0'}',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: 'Total property share in the project',
                child: Icon(Icons.info_outline, size: 14, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }

  Widget _buildPropertyRow(Map<String, dynamic> property) {
    final propName = property['property_name']?.toString() ?? 'Unknown';
    final ownership = property['ownership_percentage']?.toString() ?? '0';
    final propShare = property['property_share_of_project']?.toString() ?? '0';
    final effectiveShare = property['effective_share'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(propName, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  'Ownership: ${_formatPercentage(ownership)}% | Property Share: ${_formatPercentage(propShare)}%',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.info.withOpacity(0.3)),
            ),
            child: Text(
              '${effectiveShare ?? 0}%',
              style: const TextStyle(
                color: AppColors.info,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPercentage(String value) {
    final numVal = double.tryParse(value) ?? 0;
    if (numVal == numVal.roundToDouble()) {
      return numVal.toInt().toString();
    }
    return value;
  }

  Widget _buildDepositSchedulesTable(List depositSchedules) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        dataRowMinHeight: 56,
        dataRowMaxHeight: 56,
        headingRowColor: WidgetStateProperty.all(AppColors.background),
        columns: const [
          DataColumn(label: Text('Schedule Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
          DataColumn(label: Text('Period', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
          DataColumn(label: Text('Payable', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
          DataColumn(label: Text('Paid', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
          DataColumn(label: Text('Outstanding', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
          DataColumn(label: Text('Progress', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
        ],
        rows: depositSchedules.map<DataRow>((schedule) {
          final scheduleName = schedule['name']?.toString() ?? 'Unknown';
          final depositType = schedule['deposit_type']?.toString() ?? '';
          final startDate = schedule['start_date']?.toString() ?? '';
          final endDate = schedule['end_date']?.toString() ?? '';
          final amount = schedule['amount'];
          final payable = schedule['member_payable_amount'];
          final paid = schedule['member_paid_amount'];
          final outstanding = schedule['member_outstanding_amount'];
          final progress = schedule['member_progress_percentage'];
          final isOverdue = schedule['is_overdue'] == true;

          return DataRow(
            cells: [
              DataCell(
                SizedBox(
                  width: 120,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(scheduleName, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (depositType.isNotEmpty)
                        Text(depositType, style: AppTextStyles.caption.copyWith(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
              DataCell(Text('${_formatDate(startDate)} to ${_formatDate(endDate)}', style: AppTextStyles.caption)),
              DataCell(
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('৳${_formatAmount(payable)}', style: AppTextStyles.body),
                    Text('Total: ৳${_formatAmount(amount)}', style: AppTextStyles.caption.copyWith(fontSize: 10)),
                  ],
                ),
              ),
              DataCell(Text('৳${_formatAmount(paid)}', style: AppTextStyles.body)),
              DataCell(Text('৳${_formatAmount(outstanding)}', style: AppTextStyles.body.copyWith(color: AppColors.error))),
              DataCell(
                SizedBox(
                  width: 80,
                  height: 24,
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: LinearProgressIndicator(
                            value: (progress is num ? progress.toDouble() : 0.0) / 100,
                            backgroundColor: AppColors.divider,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                          ),
                        ),
                      ),
                      Text('${progress ?? 0}%', style: AppTextStyles.caption.copyWith(fontSize: 10)),
                    ],
                  ),
                ),
              ),
              DataCell(
                isOverdue
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Overdue',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      )
                    : const Text('-', style: AppTextStyles.caption),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPaymentHistoryTable(List deposits) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.background),
        columns: const [
          DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
          DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
          DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
          DataColumn(label: Text('Description', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
        ],
        rows: deposits.map<DataRow>((deposit) {
          final receivedAt = deposit['received_at']?.toString();
          final dateStr = receivedAt != null && receivedAt.isNotEmpty ? receivedAt : null;
          final amount = deposit['amount'];
          final depositType = deposit['deposit_type']?.toString() ?? 'Deposit';
          final description = deposit['description']?.toString() ?? '';

          return DataRow(
            cells: [
              DataCell(Text(_formatDate(dateStr ?? 'N/A'), style: AppTextStyles.caption)),
              DataCell(Text('৳${_formatAmount(amount)}', style: AppTextStyles.body.copyWith(color: AppColors.success, fontWeight: FontWeight.w600))),
              DataCell(Text(depositType, style: AppTextStyles.body)),
              DataCell(Text(description, style: AppTextStyles.caption)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(name, style: AppTextStyles.h2, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        if (phone.isNotEmpty) Text('Phone: $phone', style: AppTextStyles.caption),
        if (email.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Email: $email', style: AppTextStyles.caption),
        ],
      ],
    );
  }

  String _formatAmount(dynamic amount) {
    if (amount == null) return '0';
    final numAmount = amount is num ? amount : double.tryParse(amount.toString()) ?? 0;
    if (numAmount >= 1000000) {
      return '${(numAmount / 1000000).toStringAsFixed(1)}M';
    } else if (numAmount >= 1000) {
      return '${(numAmount / 1000).toStringAsFixed(1)}K';
    }
    return numAmount.toStringAsFixed(0);
  }

  String _formatDate(String dateStr) {
    if (dateStr == 'N/A') return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}
