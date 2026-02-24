import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../auth/auth_bloc.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _twoFaCodeController = TextEditingController();
  bool _obscurePassword = true;
  String? _twoFaToken;
  String? _lastSnackbarMessage;
  DateTime? _lastSnackbarAt;
  bool _isOtpFallbackLoading = false;

  Future<void> _verifyTwoFaFallback() async {
    if (_twoFaToken == null) return;

    setState(() {
      _isOtpFallbackLoading = true;
    });

    try {
      final result = await AuthService().verify2FA(
        _twoFaToken!,
        _twoFaCodeController.text.trim(),
      );

      if (!mounted) return;

      if (result['success'] == true) {
        context.read<AuthBloc>().add(CheckAuthStatusEvent());
      } else {
        _showDedupedSnackbar(
          result['error']?.toString() ?? '2FA verification failed',
          AppColors.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showDedupedSnackbar(
        '2FA verification failed: ${e.toString()}',
        AppColors.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isOtpFallbackLoading = false;
        });
      }
    }
  }

  void _showDedupedSnackbar(String message, Color backgroundColor) {
    final now = DateTime.now();
    final isDuplicate = _lastSnackbarMessage == message &&
        _lastSnackbarAt != null &&
        now.difference(_lastSnackbarAt!).inMilliseconds < 1500;

    if (isDuplicate) return;

    _lastSnackbarMessage = message;
    _lastSnackbarAt = now;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (SessionService.instance.consumeSessionExpiredNotice()) {
        _showDedupedSnackbar(
          'Session expired, please sign in again.',
          AppColors.warning,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SvgPicture.asset(
                  'assets/images/logo-title-slogan.svg',
                  height: 100,
                ),
                const SizedBox(height: 48),
                Text(
                  'Welcome Back',
                  style: AppTextStyles.h2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to continue',
                  style: AppTextStyles.bodySecondary,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                if (_twoFaToken == null)
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (value) {
                      if (_twoFaToken != null) return null;
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  )
                else
                  TextFormField(
                    controller: _twoFaCodeController,
                    decoration: const InputDecoration(
                      labelText: '2FA Code',
                      prefixIcon: Icon(Icons.verified_user_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (_twoFaToken == null) return null;
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your 2FA code';
                      }
                      return null;
                    },
                  ),
                const SizedBox(height: 32),
                BlocConsumer<AuthBloc, AuthState>(
                  listener: (context, state) {
                    if (state is AuthErrorState) {
                      _showDedupedSnackbar(
                        state.message,
                        AppColors.error,
                      );
                    } else if (state is Auth2FARequiredState) {
                      setState(() {
                        _twoFaToken = state.twoFaToken;
                        _twoFaCodeController.clear();
                      });
                      _showDedupedSnackbar(
                        state.message,
                        AppColors.info,
                      );
                    }
                  },
                  builder: (context, state) {
                    if (state is AuthLoadingState || _isOtpFallbackLoading) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    return ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          if (_twoFaToken == null) {
                            context.read<AuthBloc>().add(LoginEvent(
                                  email: _emailController.text.trim(),
                                  password: _passwordController.text,
                                ));
                          } else {
                            try {
                              context.read<AuthBloc>().add(Verify2FAEvent(
                                    twoFaToken: _twoFaToken!,
                                    code: _twoFaCodeController.text.trim(),
                                  ));
                            } on StateError catch (_) {
                              await _verifyTwoFaFallback();
                            }
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(_twoFaToken == null ? 'Login' : 'Verify 2FA'),
                    );
                  },
                ),
                if (_twoFaToken != null) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _twoFaToken = null;
                        _twoFaCodeController.clear();
                        _passwordController.clear();
                      });
                    },
                    child: const Text('Use another account'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _twoFaCodeController.dispose();
    super.dispose();
  }
}
