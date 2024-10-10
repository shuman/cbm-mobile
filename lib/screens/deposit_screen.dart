import 'package:flutter/material.dart';
import '../services/api_service.dart'; // Import your API service here

class DepositScreen extends StatelessWidget {
  const DepositScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Deposits')),
      body: const RecentDeposits(),
    );
  }
}

class RecentDeposits extends StatefulWidget {
  const RecentDeposits({super.key});

  @override
  _RecentDepositsState createState() => _RecentDepositsState();
}

class _RecentDepositsState extends State<RecentDeposits> {
  List<dynamic> deposits = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchDepositsData();
  }

  Future<void> fetchDepositsData() async {
    try {
      final response = await ApiService.fetchDeposits();
      if (response.containsKey('items')) {
        setState(() {
          deposits = response['items'];
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? Center(child: CircularProgressIndicator())
        : Table(
            border: TableBorder.all(),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              // Table header
              TableRow(
                children: <Widget>[
                  TableCell(
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      child: const Text('Date', textAlign: TextAlign.center),
                    ),
                  ),
                  TableCell(
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      child: const Text('Member', textAlign: TextAlign.center),
                    ),
                  ),
                  TableCell(
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      child: const Text('Amount', textAlign: TextAlign.center),
                    ),
                  ),
                  TableCell(
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      child: const Text('Description',
                          textAlign: TextAlign.center),
                    ),
                  ),
                ],
              ),
              // Data rows
              ...deposits.map((deposit) {
                return TableRow(
                  children: <Widget>[
                    TableCell(
                      child: Container(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          deposit['created_at'] != null ? DateTime.parse(deposit['created_at']).toLocal().toString().split(' ')[0] : 'N/A',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    TableCell(
                      child: Container(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          deposit['member']['name']?.toString() ??
                              'N/A', // Handle null values
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    TableCell(
                      child: Container(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          deposit['amount']?.toString() ??
                              '0.00', // Handle null values
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    TableCell(
                      child: Container(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          deposit['deposit_type']['name']?.toString() ??
                              'No type', // Handle null values
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ],
          );
  }
}
