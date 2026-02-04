import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with TickerProviderStateMixin {
  // Animation Controllers
  AnimationController? _mainController;
  Animation<double>? _logoFade;
  Animation<Offset>? _textSlide;

  AnimationController? _progressController;
  Animation<double>? _progressValue;
  Animation<Color?>? _progressColor;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startAppSequence();
  }

  void _initAnimations() {
    // 1. Setup Main Controller (Logo & Text)
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController!, curve: Curves.easeOut),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _mainController!, curve: Curves.easeOut),
    );

    // 2. Setup Progress Controller (Loading Bar)
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _progressValue = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController!, curve: Curves.easeInOut),
    );

    _progressColor = ColorTween(
      begin: Colors.grey[400],
      end: Colors.deepOrange,
    ).animate(_progressController!);
  }

  Future<void> _startAppSequence() async {
    try {
      // Start animations
      _mainController!.forward();

      // FIX: Added <dynamic> to Future.wait to resolve type conflict
      // between TickerFuture (void) and Future<String>
      final results = await Future.wait<dynamic>([
        _progressController!.forward(), // Wait for animation
        _checkUserStatus(), // Fetch data
      ]);

      // results[1] contains the destination route from _checkUserStatus
      final String nextRoute = results[1] as String;

      if (mounted) {
        _safeNavigate(nextRoute);
      }
    } catch (e) {
      debugPrint("Startup Error: $e");
      // Fallback
      if (mounted) _safeNavigate('/exam');
    }
  }

  Future<String> _checkUserStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedExam = prefs.getString('selected_exam');
      final String? examDate = prefs.getString('exam_date');

      if (savedExam != null && savedExam.isNotEmpty && examDate != null) {
        return '/home';
      }
      return '/exam';
    } catch (e) {
      return '/exam'; // Default to new user on error
    }
  }

  void _safeNavigate(String routeName) {
    try {
      Navigator.of(context).pushReplacementNamed(routeName);
    } catch (e) {
      debugPrint("Navigation Error: $e");
    }
  }

  @override
  void dispose() {
    _mainController?.dispose();
    _progressController?.dispose();
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // LOGO
              FadeTransition(
                opacity: _logoFade!,
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
                position: _textSlide!,
                child: FadeTransition(
                  opacity: _logoFade!,
                  child: Column(
                    children: [
                      Text(
                        "ExamMate",
                        style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
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
                animation: _progressController!,
                builder: (context, child) {
                  return SizedBox(
                    width: 140,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _progressValue!.value,
                        backgroundColor:
                            isDark ? Colors.grey[800] : Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                            _progressColor!.value ?? Colors.deepOrange),
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
