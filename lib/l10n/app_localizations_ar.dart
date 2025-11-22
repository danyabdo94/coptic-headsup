// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'Heads Up! لايت';

  @override
  String get tapStart => 'اضغط ابدأ!';

  @override
  String get startGame => 'ابدأ اللعبة';

  @override
  String timeLeft(int time) {
    return 'الوقت: $timeث';
  }

  @override
  String score(int score) {
    return 'النتيجة: $score';
  }

  @override
  String get placePhoneOnForehead => 'ضع الهاتف على جبهتك!';

  @override
  String get tiltDownCorrect => 'مل للأسفل للإجابة الصحيحة';

  @override
  String get tiltUpPass => 'مل للأعلى للتخطي';

  @override
  String get gameOver => 'انتهت اللعبة!';

  @override
  String finalScore(int score) {
    return 'النتيجة النهائية: $score';
  }

  @override
  String get playAgain => 'العب مرة أخرى';

  @override
  String get backToMenu => 'العودة للقائمة';

  @override
  String get selectCategory => 'اختر فئة';

  @override
  String get loading => 'جاري التحميل...';

  @override
  String get errorLoadingWords => 'خطأ في تحميل الكلمات';

  @override
  String get correct => 'صحيح!';

  @override
  String get pass => 'تخطي!';

  @override
  String get gameInstructions =>
      'خمن الكلمة على الشاشة بناءً على تلميحات فريقك. مل للأسفل لـ \"صحيح\" وللأعلى لـ \"تخطي\".';

  @override
  String get wordsPlayed => 'الكلمات التي تم لعبها (اضغط للتفاصيل):';

  @override
  String get close => 'إغلاق';

  @override
  String get noDescription => 'لا يوجد وصف متاح.';
}
