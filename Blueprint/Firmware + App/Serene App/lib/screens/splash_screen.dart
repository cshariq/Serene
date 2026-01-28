import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../main.dart';
import 'dashboard.dart';

const sereneGradient = LinearGradient(
  colors: [Color(0xFF00BCD4), Color(0xFF80DEEA)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
      ),
    );

    _controller.forward();

    // Initialize app and navigate to dashboard
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final model = SereneStateProvider.of(context);

    // Allow splash screen to show for minimum duration
    await Future.delayed(const Duration(milliseconds: 2500));

    // Initialize runtime (permissions, BLE, sensors, etc.)
    model.initializeRuntime();

    // Wait a bit more for animations to complete
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const DashboardScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0A0E21),
                    const Color(0xFF1A1F3A),
                    const Color(0xFF2A1F3A),
                  ]
                : [
                    const Color(0xFFF5F7FA),
                    const Color(0xFFE8EDF5),
                    const Color(0xFFE0E7F0),
                  ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated glowing orb
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer glow
                      Container(
                        height: 180 * _scaleAnimation.value,
                        width: 180 * _scaleAnimation.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accentColor(
                                context,
                              ).withOpacity(0.4 * _glowAnimation.value),
                              blurRadius: 60 * _glowAnimation.value,
                              spreadRadius: 20 * _glowAnimation.value,
                            ),
                          ],
                        ),
                      ),
                      // Main orb
                      Container(
                        height: 140 * _scaleAnimation.value,
                        width: 140 * _scaleAnimation.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              accentColor(context),
                              accentColor(context).withOpacity(0.8),
                              accentColor(context).withOpacity(0.4),
                            ],
                            stops: const [0.0, 0.6, 1.0],
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.waves,
                            size: 60 * _scaleAnimation.value,
                            color: Colors.black.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 40 * _fadeAnimation.value),

                  // App name
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) => sereneGradient.createShader(
                        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                      ),
                      child: Text(
                        'SERENE',
                        style: GoogleFonts.inter(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 8 * _fadeAnimation.value),

                  // Tagline
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      'Active Noise Cancellation',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.5,
                        color: isDark
                            ? Colors.white.withOpacity(0.6)
                            : Colors.black.withOpacity(0.5),
                      ),
                    ),
                  ),

                  SizedBox(height: 60 * _fadeAnimation.value),

                  // Loading indicator
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          accentColor(context).withOpacity(0.8),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
