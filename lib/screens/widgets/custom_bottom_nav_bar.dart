import 'package:flutter/material.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Color.fromARGB(255, 253, 112, 20),
      currentIndex: currentIndex, // Set the current active index
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.attach_money), label: 'Deposits'),
        BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Expenses'),
        BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: 'Reports'),
        BottomNavigationBarItem(icon: Icon(Icons.view_headline), label: 'More'),
      ],

      onTap: (index) {
        if (index != currentIndex) {
          onTap(index); // Only trigger onTap if it's a different page
        }
      }
    );
  }
}
