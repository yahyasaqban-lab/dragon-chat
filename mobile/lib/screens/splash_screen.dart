import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/matrix_service.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    
    _controller.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final matrixService = Provider.of<MatrixService>(context, listen: false);
    await matrixService.initialize();
    
    // Wait for animation
    await Future.delayed(const Duration(milliseconds: 2000));
    
    if (mounted) {
      if (matrixService.isLoggedIn) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.secondary],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _opacityAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '🐉',
                        style: TextStyle(fontSize: 100),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Dragon Chat',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Secure Communication',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 40),
                      const SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
