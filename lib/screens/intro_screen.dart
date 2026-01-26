import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _logoFade;
  late Animation<Offset> _textSlide;

  late AnimationController _progressController;
  late Animation<double> _progressValue;
  late Animation<Color?> _progressColor;

  // FIX: Explicit boolean to track if controllers are ready
  bool _animationsInitialized = false;

  @override
  void initState() {
    super.initState();

    // Initialize logic after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startAnimationSequence();
      }
    });
  }

  void _startAnimationSequence() {
    // 1. Initialize Controllers
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeOut),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeOut),
    );

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _progressValue = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    _progressColor = ColorTween(
      begin: Colors.grey[400],
      end: Colors.deepOrange,
    ).animate(_progressController);

    // 2. Mark as initialized so the UI can safely render
    setState(() {
      _animationsInitialized = true;
    });

    // 3. Start Animations
    _mainController.forward();
    _progressController.forward();

    // 4. Navigation Logic
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToHome();
      }
    });
  }

  void _navigateToHome() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    // Only dispose if we actually initialized them
    if (_animationsInitialized) {
      _mainController.dispose();
      _progressController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: !_animationsInitialized
              ? const SizedBox() // Show nothing while initializing (prevents crash)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // LOGO
                    FadeTransition(
                      opacity: _logoFade,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? Colors.grey[900] : Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 5),
                            )
                          ],
                        ),
                        child: Image.asset(
                          'assets/icon/icon.png',
                          width: 80,
                          height: 80,
                          errorBuilder: (c, o, s) => const Icon(Icons.school,
                              size: 80, color: Colors.deepOrange),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    // TEXT
                    SlideTransition(
                      position: _textSlide,
                      child: FadeTransition(
                        opacity: _logoFade,
                        child: Column(
                          children: [
                            Text(
                              "ExamMate",
                              style: GoogleFonts.poppins(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Focus. Consistency. Results.",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 60),

                    // PROGRESS BAR
                    AnimatedBuilder(
                      animation: _progressController,
                      builder: (context, child) {
                        return SizedBox(
                          width: 140,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _progressValue.value,
                              backgroundColor:
                                  isDark ? Colors.grey[800] : Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  _progressColor.value ?? Colors.deepOrange),
                              minHeight: 4,
                            ),
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
}
