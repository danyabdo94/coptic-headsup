// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Coptic heads Up!';

  @override
  String get tapStart => 'Tap Start!';

  @override
  String get startGame => 'Start Game';

  @override
  String timeLeft(int time) {
    return 'Time: ${time}s';
  }

  @override
  String score(int score) {
    return 'Score: $score';
  }

  @override
  String get placePhoneOnForehead => 'Place phone on forehead!';

  @override
  String get tiltDownCorrect => 'Tilt DOWN for Correct';

  @override
  String get tiltUpPass => 'Tilt UP for Pass';

  @override
  String get gameOver => 'Game Over!';

  @override
  String finalScore(int score) {
    return 'Final Score: $score';
  }

  @override
  String get playAgain => 'Play Again';

  @override
  String get backToMenu => 'Back to Menu';

  @override
  String get selectCategory => 'Select a Category';

  @override
  String get loading => 'Loading...';

  @override
  String get errorLoadingWords => 'Error loading words';

  @override
  String get correct => 'Correct!';

  @override
  String get pass => 'Pass!';

  @override
  String get gameInstructions =>
      'Guess the word on the screen based on your team\'s clues. Tilt down for \"Correct\" and up for \"Skip\".';

  @override
  String get wordsPlayed => 'Words Played (Tap for info):';

  @override
  String get close => 'Close';

  @override
  String get noDescription => 'No description available.';
}
