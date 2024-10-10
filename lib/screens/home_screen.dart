import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../auth/auth_bloc.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cobuild Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Logout action
              context.read<AuthBloc>().add(LogoutEvent());
            },
          ),
        ],
      ),
      backgroundColor: Color(0xFFF0F0F0),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          children: [
            _buildIconCard(context, Icons.attach_money, 'Add Deposit', () {
              Navigator.pushNamed(context, '/deposit_add');
            }),
            _buildIconCard(context, Icons.shopping_cart, 'Expense', () {
              Navigator.pushNamed(context, '/expense');
            }),
            _buildIconCard(context, Icons.report, 'Reports', () {
              // Navigate to Reports screen (if you have one)
            }),
            _buildIconCard(context, Icons.settings, 'Settings', () {
              // Navigate to Settings screen (if you have one)
            }),
            // Add more icons as needed
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home),label: 'Home'),
          BottomNavigationBarItem( icon: Icon(Icons.attach_money), label: 'Deposit'),
          BottomNavigationBarItem( icon: Icon(Icons.shopping_cart), label: 'Expense'),
          BottomNavigationBarItem( icon: Icon(Icons.account_circle), label: 'Account'),
          BottomNavigationBarItem( icon: Icon(Icons.settings), label: 'Settings'),
        ],
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
      )
    );
  }

  Widget _buildIconCard(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
