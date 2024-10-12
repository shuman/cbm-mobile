import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart'; // Import your API service here
import './widgets/custom_bottom_nav_bar.dart';

class DepositScreen extends StatelessWidget {
  const DepositScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Deposits',
            style: TextStyle(color: Color.fromARGB(255, 253, 112, 20))),
      ),
      body: const RecentDeposits(),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 1, // Set the active index for this screen
        onTap: (index) {
          if (index == 0) {
            Navigator.pushNamed(context, '/home');
          } else if (index == 1) {
            Navigator.pushNamed(context, '/deposit');
          } else if (index == 2) {
            Navigator.pushNamed(context, '/expense');
          } else if (index == 3) {
            Navigator.pushNamed(context, '/account');
          } else if (index == 4) {
            Navigator.pushNamed(context, '/settings');
          }
        },
      ),
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
  bool isDetailsLoading = false;

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

  Future<Map<String, dynamic>> fetchDepositDetails(String transactionId) async {
    // API call to fetch detailed information
    final details = await ApiService.fetchDepositDetails(transactionId);
    return details;
  }

  String formatDate(String? date, String format) {
    if (date == null) {
      return 'N/A'; // Handle empty values
    }
    DateTime parsedDate =
        DateTime.parse(date).toLocal(); // Convert to DateTime and local time

    return DateFormat(format).format(parsedDate);
  }

  void showDepositDetails(BuildContext context, dynamic deposit) async {
    setState(() {
      isDetailsLoading = true; // Show semi-transparent loading screen
    });

    try {
      // Fetch detailed data (keep loading)
      final response =
          await fetchDepositDetails(deposit['id']); // Fetch details using ID

      setState(() {
        isDetailsLoading = false; // Stop showing loading screen
      });

      if (response.containsKey('items')) {
        final details = response['items'];

        // Now show the actual details once data is loaded
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (context) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Details',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  buildDetailRow(
                      'Name:', details['member']?['name']?.toString() ?? 'N/A'),
                  buildDetailRow(
                      'Amount:', details['amount']?.toString() ?? 'N/A'),
                  buildDetailRow(
                    'Date:',
                    details['created_at'] != null
                        ? formatDate(
                            details['created_at'], "yyyy-MM-dd hh:mm a")
                        : 'N/A',
                  ),
                  buildDetailRow('Type:',
                      details['deposit_type']?['name']?.toString() ?? 'N/A'),
                  buildDetailRow(
                    'Category:',
                    details['deposit_type']?['deposit_type_category']?['name']
                            ?.toString() ??
                        'N/A',
                  ),
                  buildDetailRow('Added By:',
                      details['api_user']?['name']?.toString() ?? 'N/A'),
                  buildDetailRow('Description:',
                      details['description']?.toString() ?? 'N/A'),
                  buildDetailRow('Transaction ID:',
                      details['trx_unique_id']?.toString() ?? 'N/A'),
                  SizedBox(height: 16),
                  Center(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Close'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }
    } catch (error) {
      // Stop showing loading screen on error
      setState(() {
        isDetailsLoading = false;
      });

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load deposit details')),
      );
    }
  }

  Widget buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Text(value ?? 'N/A'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        isLoading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(0),
                child: Column(
                  children: [
                    Table(
                      border: TableBorder(
                        horizontalInside: BorderSide(
                          color: Colors
                              .orange.shade500, // Light deep horizontal border
                          width: 1,
                        ),
                        top: BorderSide(
                          color: Colors.orange.shade100, // Apply to top border
                          width: 1,
                        ),
                        bottom: BorderSide(
                          color:
                              Colors.orange.shade100, // Apply to bottom border
                          width: 1,
                        ),
                        verticalInside: BorderSide.none, // No vertical borders
                      ),
                      defaultVerticalAlignment:
                          TableCellVerticalAlignment.middle,
                      children: [
                        // Table header
                        TableRow(
                          decoration: BoxDecoration(
                            color: Color.fromARGB(255, 253, 112, 20),
                          ),
                          children: <Widget>[
                            buildTableCell('Date'),
                            buildTableCell('Member'),
                            buildTableCell('Amount'),
                            buildTableCell('Type'),
                          ],
                        ),
                        // Data rows
                        ...deposits.map((deposit) {
                          return TableRow(
                            decoration: BoxDecoration(
                              color: Colors.yellow.shade50,
                            ),
                            children: <Widget>[
                              buildClickableTableCell(
                                  context,
                                  deposit,
                                  formatDate(
                                      deposit['created_at'], "dd MMM yy")),
                              buildClickableTableCell(
                                  context,
                                  deposit,
                                  deposit['member']['name']?.toString() ??
                                      'N/A'),
                              buildClickableTableCell(context, deposit,
                                  deposit['amount']?.toString() ?? '0.00'),
                              buildClickableTableCell(
                                  context,
                                  deposit,
                                  deposit['deposit_type']['name']?.toString() ??
                                      'No type'),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                  ],
                ),
              ),
        // Semi-transparent loading screen overlay for details
        if (isDetailsLoading)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Text(
                'Loading details...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Table header style
  Widget buildTableCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontSize: 14),
      ),
    );
  }

  // Table rows style
  Widget buildClickableTableCell(
      BuildContext context, dynamic deposit, String text) {
    return GestureDetector(
      onTap: () => showDepositDetails(context, deposit),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Text(
          text,
          textAlign: TextAlign.left,
          style: TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}
