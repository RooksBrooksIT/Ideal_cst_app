import 'package:flutter/material.dart';
import 'package:ideal_cst/screens/auth/organisation_login_page.dart';
import 'package:ideal_cst/screens/auth/manager_login_page.dart';
import 'package:ideal_cst/screens/auth/supervisor_login_page.dart';

class AppColors {
  static const primaryColor = Color(0xFF003768);
  static const primaryGradientStart = Color(0xFF003768);
  static const primaryGradientEnd = Color.fromARGB(
    255,
    1,
    127,
    223,
  ); // Slightly lighter for gradient
}

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeInOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacementNamed(context, '/letsStart');
        return false;
      },
      child: Scaffold(
        body: Container(
          color: const Color(0xFFDDEBF6), // Match Get Started page background
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    if (!_controller.isAnimating && !_controller.isCompleted) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return Opacity(
                      opacity: _opacityAnimation.value,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: screenWidth > 600
                                ? screenWidth * 0.1
                                : 20,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeader(theme),
                              SizedBox(height: screenWidth > 600 ? 30 : 20),
                              Expanded(
                                child: ListView(
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.only(bottom: 20),
                                  children: [
                                    DashboardCard(
                                      theme: theme,
                                      title: 'Organization',
                                      subtitle:
                                          'Manage organizations and their details',
                                      icon: Icons.account_balance_rounded,
                                      color: AppColors.primaryColor, // Original brand color
                                      destination:
                                          const Organisation_LoginPage(),
                                    ),
                                    SizedBox(
                                      height: screenWidth > 600 ? 24 : 16,
                                    ),
                                    DashboardCard(
                                      theme: theme,
                                      title: 'Manager',
                                      subtitle:
                                          'Configure system settings and preferences',
                                      icon: Icons.settings_rounded,
                                      color: const Color(0xFF00695C), // Dark Teal
                                      destination: const ManagerLoginPage(),
                                    ),
                                    SizedBox(
                                      height: screenWidth > 600 ? 24 : 16,
                                    ),
                                    DashboardCard(
                                      theme: theme,
                                      title: 'Supervisor',
                                      subtitle:
                                          'Manage supervisors and their activities',
                                      icon: Icons.supervisor_account_rounded,
                                      color: const Color(0xFF4527A0), // Deep Purple
                                      destination: const Supervisor_LoginPage(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'CST Dashboard',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: AppColors.primaryColor,
        ),
      ),
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'Welcome to CST',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select your role to continue',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.primaryColor.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

class DashboardCard extends StatefulWidget {
  final ThemeData theme;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget destination;

  const DashboardCard({
    super.key,
    required this.theme,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.destination,
  });

  @override
  State<DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<DashboardCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  void _navigate() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => widget.destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardHeight = screenWidth > 600 ? 140.0 : 120.0;
    
    final scale = _isPressed ? 0.96 : 1.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          _navigate();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutQuad,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: cardHeight,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: _isHovered ? 0.4 : 0.2),
                  blurRadius: _isHovered ? 20 : 15,
                  offset: Offset(0, _isHovered ? 12 : 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Subtle background icon
                Positioned(
                  right: -20,
                  bottom: -20,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _isHovered ? 0.15 : 0.1,
                    child: Icon(
                      widget.icon,
                      size: cardHeight * 0.8,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Left accent border
                Positioned(
                  left: 0,
                  top: 20,
                  bottom: 20,
                  child: Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(widget.icon, size: 32, color: Colors.white),
                      ),
                      SizedBox(width: screenWidth > 600 ? 24 : 16),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: widget.theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.subtitle,
                              style: widget.theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      AnimatedSlide(
                        offset: _isHovered ? const Offset(0.3, 0) : Offset.zero,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 20,
                            color: AppColors.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
