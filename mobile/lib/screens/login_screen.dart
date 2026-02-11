import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/matrix_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _homeserverController = TextEditingController(text: MatrixService.defaultHomeserver);
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isRegistering = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _homeserverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    final matrixService = Provider.of<MatrixService>(context, listen: false);
    
    bool success;
    if (_isRegistering) {
      success = await matrixService.register(
        homeserver: _homeserverController.text,
        username: _usernameController.text,
        password: _passwordController.text,
      );
    } else {
      success = await matrixService.login(
        homeserver: _homeserverController.text,
        username: _usernameController.text,
        password: _passwordController.text,
      );
    }
    
    setState(() => _isLoading = false);
    
    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(matrixService.error ?? 'Authentication failed'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  const Text(
                    '🐉',
                    style: TextStyle(fontSize: 80),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Dragon Chat',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isRegistering ? 'Create your account' : 'Sign in to continue',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  
                  // Homeserver
                  TextFormField(
                    controller: _homeserverController,
                    decoration: const InputDecoration(
                      labelText: 'Homeserver',
                      hintText: 'https://matrix.y7xyz.com',
                      prefixIcon: Icon(Icons.dns_outlined),
                    ),
                    keyboardType: TextInputType.url,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter homeserver URL';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Username
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      hintText: '@user:y7xyz.com',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    keyboardType: TextInputType.text,
                    autocorrect: false,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter username';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Password
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter password';
                      }
                      if (_isRegistering && value.length < 8) {
                        return 'Password must be at least 8 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // Submit Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(_isRegistering ? 'Create Account' : 'Sign In'),
                  ),
                  const SizedBox(height: 16),
                  
                  // Toggle Register/Login
                  TextButton(
                    onPressed: () {
                      setState(() => _isRegistering = !_isRegistering);
                    },
                    child: Text(
                      _isRegistering
                          ? 'Already have an account? Sign in'
                          : "Don't have an account? Register",
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
