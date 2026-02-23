import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';

String valueOrNA(dynamic value, {String fallback = 'N/A'}) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
    return fallback;
  }
  return text;
}

String formatCurrency(dynamic value) {
  final amount = value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
  if (amount == null) return 'N/A';
  return '\$${amount.toStringAsFixed(2)}';
}

String formatDateTime(dynamic value, {bool includeTime = true}) {
  final text = value?.toString();
  if (text == null || text.trim().isEmpty) return 'N/A';

  try {
    final dateTime = DateTime.parse(text);
    if (includeTime) {
      return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
    }
    return DateFormat('dd MMM yyyy').format(dateTime);
  } catch (_) {
    return text;
  }
}

class DetailSection extends StatelessWidget {
  const DetailSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h3.copyWith(fontSize: 16)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 116,
          child: Text(label, style: AppTextStyles.bodySecondary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              value,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
