import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart'; // Import the flutter_svg package
import '../auth/auth_bloc.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Centered SVG logo
              SvgPicture.asset(
                'assets/images/logo-title-slogan.svg', // Path to your SVG file
                height: 100, // Adjust height and width as needed
              ),
              const SizedBox(height: 40), // Space between logo and form
              // Email TextField
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: Color.fromARGB(57, 62, 70, 1)),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Color.fromARGB(255, 253, 112, 20)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Password TextField
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: Color.fromARGB(57, 62, 70, 1)),
                  focusedBorder: UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: Color.fromARGB(255, 253, 112, 20)),
                  ),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 40),
              // BlocConsumer for authentication state
              BlocConsumer<AuthBloc, AuthState>(
                listener: (context, state) {
                  if (state is AuthAuthenticatedState) {
                    Navigator.pushReplacementNamed(context, '/home');
                  } else if (state is AuthErrorState) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(state.message)),
                    );
                  }
                },
                builder: (context, state) {
                  if (state is AuthLoadingState) {
                    return const CircularProgressIndicator();
                  }
                  return ElevatedButton(
                    onPressed: () {
                      context.read<AuthBloc>().add(LoginEvent(
                            email: _emailController.text,
                            password: _passwordController.text,
                          ));
                    },
                    child: const Text(
                      'Login',
                      style: TextStyle(color: Color.fromARGB(255, 253, 112, 20)),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
