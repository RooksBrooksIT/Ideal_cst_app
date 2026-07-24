import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ideal_cst/screens/organization/Organization_Dashboard.dart';
import 'package:ideal_cst/screens/manager/config_account_dashboard.dart';
import 'package:ideal_cst/screens/supervisor/supervisor_dashboard.dart';
import 'package:ideal_cst/screens/manager/contractor_entry_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pulseController;

  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoFadeAnimation;
  late Animation<Offset> _textSlideAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<double> _progressFadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Main animation controller (2.4 seconds total entry sequence)
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    // Continuous subtle pulsing controller for ambient background glow
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _logoScaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );

    _logoFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.40, curve: Curves.easeIn),
      ),
    );

    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.35, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.35, 0.70, curve: Curves.easeIn),
      ),
    );

    _progressFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.60, 0.90, curve: Curves.easeIn),
      ),
    );

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Start entry animations
    _mainController.forward();

    // Run navigation logic after animation & auth data load complete
    _initializeAndNavigate();
  }

  Future<void> _initializeAndNavigate() async {
    // Wait for animation completion and preference fetch concurrently
    final animFuture = Future.delayed(const Duration(milliseconds: 2600));
    final prefsFuture = SharedPreferences.getInstance();

    final results = await Future.wait([animFuture, prefsFuture]);
    final prefs = results[1] as SharedPreferences;
    final String? role = prefs.getString('persistent_role');

    if (!mounted) return;

    Widget targetScreen;
    if (role == 'Organization') {
      targetScreen = const OrganizationDashboard();
    } else if (role == 'Manager') {
      targetScreen = const ConfigAccountDashboard();
    } else if (role == 'Supervisor') {
      final supervisorId = prefs.getString('sup_supervisorId') ?? '';
      final supervisorName = prefs.getString('sup_supervisorName') ?? '';
      final username = prefs.getString('sup_username') ?? '';
      targetScreen = SupervisorDashboard(
        supervisorId: supervisorId,
        supervisorName: supervisorName,
        username: username,
      );
    } else if (role == 'ContractorEntry') {
      final supervisorId = prefs.getString('sup_supervisorId') ?? '';
      final contractorName = prefs.getString('sup_contractorName') ?? '';
      final contractorField = prefs.getString('sup_contractorField') ?? '';
      final username = prefs.getString('sup_username') ?? '';
      targetScreen = ContractorEntryPage(
        userName: username,
        userDetails: {
          'supervisorId': supervisorId,
          'contractorName': contractorName,
          'contractorField': contractorField,
        },
      );
    } else {
      Navigator.pushReplacementNamed(context, '/letsStart');
      return;
    }

    // Smooth fade transition to target dashboard
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Dynamic Gradient Background
          Container(
            width: size.width,
            height: size.height,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF041026),
                  Color(0xFF0b3470),
                  Color(0xFF051838),
                ],
              ),
            ),
          ),

          // Ambient Background Glow Circles
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Positioned(
                top: size.height * 0.35 - (120 * _pulseAnimation.value),
                left: size.width * 0.5 - (120 * _pulseAnimation.value),
                child: Container(
                  width: 240 * _pulseAnimation.value,
                  height: 240 * _pulseAnimation.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1a50a1).withValues(alpha: 0.25),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2864c2).withValues(alpha: 0.3),
                        blurRadius: 80,
                        spreadRadius: 40,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Main Center Animation Content
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),

                    // Animated Logo Container
                    AnimatedBuilder(
                      animation: _mainController,
                      builder: (context, child) {
                        return FadeTransition(
                          opacity: _logoFadeAnimation,
                          child: ScaleTransition(
                            scale: _logoScaleAnimation,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/splash_screen_logo.png',
                          width: 160,
                          height: 160,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.apartment_rounded,
                              size: 100,
                              color: Colors.white,
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Animated Title and Tagline
                    AnimatedBuilder(
                      animation: _mainController,
                      builder: (context, child) {
                        return FadeTransition(
                          opacity: _textFadeAnimation,
                          child: SlideTransition(
                            position: _textSlideAnimation,
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        children: [
                          const Text(
                            'Construct Pro',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Smart Construction & Site Management',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.8),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Animated Loading Indicator
                    AnimatedBuilder(
                      animation: _mainController,
                      builder: (context, child) {
                        return FadeTransition(
                          opacity: _progressFadeAnimation,
                          child: child,
                        );
                      },
                      child: Column(
                        children: [
                          SizedBox(
                            width: 140,
                            height: 3,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                backgroundColor: Colors.white.withValues(alpha: 0.15),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF64B5F6),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Initializing...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.6),
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
