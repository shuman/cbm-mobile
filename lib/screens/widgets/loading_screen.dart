import 'package:flutter/material.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  _LoadingScreenState createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  bool isLoading = true; // Track loading state

  @override
  void initState() {
    super.initState();
    _fetchData(); // Simulate a data fetch
  }

  Future<void> _fetchData() async {
    // Simulate a network call or some async task
    await Future.delayed(const Duration(seconds: 3)); // Simulate delay
    setState(() {
      isLoading = false; // Set loading to false once the data is fetched
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loading ...')),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(), // Show loading spinner
            )
          : Center(
              child: const Text('Loading Done!'), // Show actual content
            ),
    );
  }
}