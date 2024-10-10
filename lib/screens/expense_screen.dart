import 'package:flutter/material.dart';

class ExpenseScreen extends StatelessWidget {
  const ExpenseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Expenses')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () {
              // Navigate to Add Expense Page
            },
            child: Text('Add Expense'),
          ),
          ElevatedButton(
            onPressed: () {
              // Navigate to List Expenses Page
            },
            child: Text('List Expenses'),
          ),
        ],
      ),
    );
  }
}
