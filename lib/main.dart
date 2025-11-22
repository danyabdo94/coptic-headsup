import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
// NOTE: For a real project, this package must be added to pubspec.yaml
import 'package:sensors_plus/sensors_plus.dart';

// --- 1. DATA AND CONSTANTS ---

// Hardcoded Word List (The Deck)
const List<String> _kWordDeck = [
  'Dog',
  'Cat',
  'Elephant',
  'Lion',
  'Tiger',
  'Monkey',
  'Zebra',
  'Apple',
  'Banana',
  'Orange',
  'Grape',
  'Strawberry',
  'Mango',
  'Car',
  'Train',
  'Bus',
  'Bicycle',
  'Airplane',
  'Boat',
  'Coding',
  'Flutter',
  'Dart',
  'Software',
  'Develop',
  'AI',
  'Game',
];

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
      title: 'Heads Up! Lite',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      home: const HeadsUpHomePage(),
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
  String _currentWord = 'Tap Start!';
  Timer? _timer;

  // Sensor & Feedback Management
  // Subscription to the accelerometer stream for real-time tilt data
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  DateTime _lastActionTime = DateTime.now(); // Debouncing
  Color _actionColor = Colors.black; // Visual feedback color

  // Word Management
  List<String> _currentDeck = [];
  final List<String> _playedWords = [];
  final Random _random = Random();

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
  void dispose() {
    _timer?.cancel();
    // Cancel the accelerometer subscription when the widget is removed
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  // --- 4. State Management/Game Flow Functions ---

  /// Resets game variables and starts the 60-second timer.
  void _startGame() {
    setState(() {
      _gameState = GameState.playing;
      _score = 0;
      _timeLeft = _kGameDurationSeconds;
      _currentDeck = List.from(_kWordDeck); // Copy the full deck
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
      if (_currentWord != 'Tap Start!') {
        _playedWords.add(_currentWord);
      }

      // Get a new random word and remove it from the deck
      final int index = _random.nextInt(_currentDeck.length);
      _currentWord = _currentDeck[index];
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

  // --- 5. UI COMPONENTS (Corresponding to Game States) ---

  Widget _buildLobby(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Welcome to Heads Up! Lite',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        const Text(
          'Guess the word on the screen based on your team\'s clues. Tilt down for "Correct" and up for "Skip".',
          style: TextStyle(fontSize: 16, color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: _startGame,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal.shade600,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Start Game (60s)',
            style: TextStyle(fontSize: 20, color: Colors.white),
          ),
        ),
      ],
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
            child: Text(
              _currentWord.toUpperCase(),
              style: const TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
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
                  'SCORE: $_score',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.greenAccent,
                  ),
                ),
                Text(
                  'TIME: $_timeLeft s',
                  style: TextStyle(
                    fontSize: 18,
                    color: _timeLeft <= 10 ? Colors.redAccent : Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Instruction (Center Top)
          const Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: Text(
              'Tilt down for Correct, up for Skip.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '🎉 Time\'s Up! 🎉',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Final Score: $_score',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w900,
            color: Colors.greenAccent,
          ),
        ),
        const SizedBox(height: 30),
        const Text(
          'Words Played:',
          style: TextStyle(fontSize: 20, color: Colors.white),
        ),
        const SizedBox(height: 10),
        // Displaying a small list of played words
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          alignment: WrapAlignment.center,
          children: _playedWords
              .map(
                (word) => Chip(
                  label: Text(word),
                  backgroundColor: Colors.teal.shade100,
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _gameState = GameState.lobby;
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal.shade600,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Play Again',
            style: TextStyle(fontSize: 20, color: Colors.white),
          ),
        ),
      ],
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
