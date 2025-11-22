import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
// NOTE: For a real project, this package must be added to pubspec.yaml
import 'package:sensors_plus/sensors_plus.dart';

// --- 1. DATA AND CONSTANTS ---

// Word Item Model
class WordItem {
  final String word;
  final String description;

  WordItem({required this.word, required this.description});

  factory WordItem.fromJson(Map<String, dynamic> json) {
    return WordItem(word: json['word'], description: json['description']);
  }
}

// Played Word Model
class PlayedWord {
  final String word;
  final bool isCorrect;
  String? description;

  PlayedWord(this.word, this.isCorrect, {this.description});
}

// Game duration in seconds
const int _kGameDurationSeconds = 60;

// Accelerometer Constants for Tilt Detection
// We focus on the Z-axis, which measures the face-up/face-down tilt relative to gravity (~9.8 m/s^2).
const double _kTiltThreshold = 7.0; // Strong tilt detection
const int _kDebounceDurationMs =
    1000; // 1 second debounce to prevent rapid-fire scoring

// Game States
enum GameState {
  lobby, // Before the game starts
  playing, // Game in progress
  gameOver, // Game finished
}

// --- 2. MAIN APPLICATION SETUP ---

void main() {
  runApp(const HeadsUpGame());
}

class HeadsUpGame extends StatelessWidget {
  const HeadsUpGame({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      home: const HeadsUpHomePage(),
      // Add localization support
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        AppLocalizations.delegate, // Custom localizations
      ],
      supportedLocales: const [
        Locale('en', ''), // English
        Locale('ar', ''), // Arabic
      ],
    );
  }
}

// --- 3. GAME LOGIC (StatefulWidget) ---

class HeadsUpHomePage extends StatefulWidget {
  const HeadsUpHomePage({super.key});

  @override
  State<HeadsUpHomePage> createState() => _HeadsUpHomePageState();
}

class _HeadsUpHomePageState extends State<HeadsUpHomePage> {
  // Game State Variables
  GameState _gameState = GameState.lobby;
  int _score = 0;
  int _timeLeft = _kGameDurationSeconds;
  String _currentWord = '';
  String? _currentDescription;
  Timer? _timer;

  // Sensor & Feedback Management
  // Subscription to the accelerometer stream for real-time tilt data
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  DateTime _lastActionTime = DateTime.now(); // Debouncing
  Color _actionColor = Colors.black; // Visual feedback color

  // Word Management
  Map<String, List<WordItem>> _wordCategories = {};
  List<WordItem> _currentDeck = [];
  final List<PlayedWord> _playedWords = [];
  final Random _random = Random();
  String? _selectedCategory;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Start listening to the accelerometer stream immediately
    _accelerometerSubscription = accelerometerEventStream().listen((
      AccelerometerEvent event,
    ) {
      if (_gameState == GameState.playing) {
        // Pass the z-axis value to the tilt handler
        _handleTilt(event.z);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadWordData();
  }

  Future<void> _loadWordData() async {
    try {
      final locale = Localizations.localeOf(context);
      final String jsonFile = locale.languageCode == 'ar' ? 'assets/words_ar.json' : 'assets/words_en.json';
      final String response = await rootBundle.loadString(jsonFile);
      final Map<String, dynamic> data = json.decode(response);

      setState(() {
        _wordCategories = data.map((key, value) {
          final List<dynamic> list = value;
          return MapEntry(
            key,
            list.map((item) => WordItem.fromJson(item)).toList(),
          );
        });
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading word data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    // Cancel the accelerometer subscription when the widget is removed
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  // --- 4. State Management/Game Flow Functions ---

  /// Resets game variables and starts the 60-second timer.
  void _startGame() {
    if (_selectedCategory == null) return;

    setState(() {
      _gameState = GameState.playing;
      _score = 0;
      _timeLeft = _kGameDurationSeconds;
      _currentDeck = List.from(
        _wordCategories[_selectedCategory]!,
      ); // Copy the category deck
      _playedWords.clear();
      _actionColor = Colors.black; // Reset feedback color
      _nextWord(false); // Get the first word (don't count as correct)
    });

    // Start the timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() {
          _timeLeft--;
        });
      } else {
        _stopGame();
      }
    });
  }

  /// Ends the game, stops the timer, and transitions to the Game Over screen.
  void _stopGame() {
    _timer?.cancel();
    setState(() {
      _gameState = GameState.gameOver;
    });
  }

  /// Clears the action color after a brief delay for visual feedback.
  void _resetActionColor() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _actionColor = Colors.black;
        });
      }
    });
  }

  /// Updates the score based on the outcome and fetches the next word.
  void _nextWord(bool isCorrect) {
    // Check if game is still active
    if (_gameState != GameState.playing) return;

    // Check if deck is empty
    if (_currentDeck.isEmpty) {
      _stopGame();
      return;
    }

    setState(() {
      if (isCorrect) {
        _score++;
        _actionColor = Colors.green.shade800; // Visual feedback for CORRECT
      } else {
        _actionColor = Colors.red.shade800; // Visual feedback for SKIP
      }

      // Move the current word to played list (if not null/initial state)
      if (_currentWord.isNotEmpty) {
        _playedWords.add(
          PlayedWord(_currentWord, isCorrect, description: _currentDescription),
        );
      }

      // Get a new random word and remove it from the deck
      final int index = _random.nextInt(_currentDeck.length);
      final WordItem nextItem = _currentDeck[index];
      _currentWord = nextItem.word;
      _currentDescription = nextItem.description;
      _currentDeck.removeAt(index);
    });

    _resetActionColor(); // Reset color after action
  }

  /// Processes accelerometer data to determine if a tilt action occurred.
  void _handleTilt(double z) {
    // Debounce check - prevents multiple actions from one tilt
    if (DateTime.now().difference(_lastActionTime).inMilliseconds <
        _kDebounceDurationMs) {
      return;
    }

    // Tilt Up (Skip): Phone faces up (Z approaches +9.8)
    if (z > _kTiltThreshold) {
      _lastActionTime = DateTime.now();
      _nextWord(false); // Skip
    }
    // Tilt Down (Correct): Phone faces down (Z approaches -9.8)
    else if (z < -_kTiltThreshold) {
      _lastActionTime = DateTime.now();
      _nextWord(true); // Correct
    }
  }

  void _showWordDescription(PlayedWord playedWord) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(playedWord.word),
          content: Text(playedWord.description ?? AppLocalizations.of(context)!.noDescription),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context)!.close),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLobby(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            AppLocalizations.of(context)!.appTitle,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context)!.selectCategory,
            style: const TextStyle(fontSize: 20, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            alignment: WrapAlignment.center,
            children: _wordCategories.keys.map((category) {
              return ActionChip(
                label: Text(category),
                backgroundColor: _selectedCategory == category
                    ? Colors.tealAccent
                    : Colors.grey.shade300,
                onPressed: () {
                  setState(() {
                    _selectedCategory = category;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context)!.gameInstructions,
            style: const TextStyle(fontSize: 16, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _selectedCategory != null ? _startGame : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade600,
              disabledBackgroundColor: Colors.grey,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              AppLocalizations.of(context)!.startGame,
              style: const TextStyle(fontSize: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaying() {
    // The main playing area, which relies purely on sensor input.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color:
            _actionColor, // Uses the dynamic action color (flashes green/red)
        border: Border.all(color: Colors.yellow.shade700, width: 4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // Current Word Display (Center)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentWord.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_currentDescription != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Text(
                      _currentDescription!,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),

          // Score and Timer (Top and Bottom, discreet)
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.score(_score),
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.greenAccent,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    _timer?.cancel();
                    setState(() {
                      _gameState = GameState.lobby;
                      _selectedCategory = null;
                    });
                  },
                ),
                Text(
                  AppLocalizations.of(context)!.timeLeft(_timeLeft),
                  style: TextStyle(
                    fontSize: 18,
                    color: _timeLeft <= 10 ? Colors.redAccent : Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Instruction (Center Top)
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: Text(
              '${AppLocalizations.of(context)!.tiltDownCorrect}, ${AppLocalizations.of(context)!.tiltUpPass}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),

          // Visual Indicator (Top)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 50,
            child: Center(
              child: Icon(
                Icons.keyboard_arrow_up,
                size: 40,
                color: Colors.redAccent,
              ),
            ),
          ),

          // Visual Indicator (Bottom)
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 50,
            child: Center(
              child: Icon(
                Icons.keyboard_arrow_down,
                size: 40,
                color: Colors.greenAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOver() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            AppLocalizations.of(context)!.gameOver,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context)!.finalScore(_score),
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: Colors.greenAccent,
            ),
          ),
          const SizedBox(height: 30),
          Text(
            AppLocalizations.of(context)!.wordsPlayed,
            style: const TextStyle(fontSize: 20, color: Colors.white),
          ),
          const SizedBox(height: 10),
          // Displaying a small list of played words
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            alignment: WrapAlignment.center,
            children: _playedWords.map((playedWord) {
              return GestureDetector(
                onTap: () => _showWordDescription(playedWord),
                child: Chip(
                  label: Text(playedWord.word),
                  backgroundColor: playedWord.isCorrect
                      ? Colors.green.shade200
                      : Colors.red.shade200,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _gameState = GameState.lobby;
                _selectedCategory = null; // Reset category selection
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade600,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              AppLocalizations.of(context)!.playAgain,
              style: const TextStyle(fontSize: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // --- 6. Main Build Method (UI Router) ---

  @override
  Widget build(BuildContext context) {
    Widget content;

    switch (_gameState) {
      case GameState.lobby:
        content = _buildLobby(context);
        break;
      case GameState.playing:
        content = _buildPlaying();
        break;
      case GameState.gameOver:
        content = _buildGameOver();
        break;
    }

    // Apply the main background and padding
    return Scaffold(
      backgroundColor: Colors.blueGrey.shade900,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(child: content),
        ),
      ),
    );
  }
}
