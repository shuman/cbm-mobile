import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../auth/auth_bloc.dart'; // Assuming your AuthBloc is here
import './widgets/custom_bottom_nav_bar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Trigger the LogoutEvent in the AuthBloc
              context.read<AuthBloc>().add(LogoutEvent());
              // Navigate to the login screen
              Navigator.pushNamed(context, '/login');
            },
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _buildIconCard(context, Icons.add_circle_outline, 'Add Deposit',
                () {
              Navigator.pushNamed(context, '/deposit_add');
            }),
            _buildIconCard(context, Icons.receipt, 'Add Expense', () {
              Navigator.pushNamed(context, '/expense');
            }),
            _buildIconCard(context, Icons.local_atm, 'Member Invoice', () {
              // Add your logic here
            }),
            _buildIconCard(context, Icons.build, 'Vendors', () {
              // Add your logic here
            }),
            _buildIconCard(context, Icons.playlist_add_check, 'Bill Payment',
                () {
              // Add your logic here
            }),
            _buildIconCard(context, Icons.money_off, 'Utility Payment', () {
              // Add your logic here
            }),
            _buildIconCard(context, Icons.local_post_office, 'SMS', () {
              // Add your logic here
            }),
            // Add more icons as needed
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 0, // Set the active index for this screen
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

  Widget _buildIconCard(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: Color.fromARGB(255, 253, 112, 20)),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
