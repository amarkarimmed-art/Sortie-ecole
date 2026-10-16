// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get ecranSurveillanceTitre => 'مراقبة مغادرة التلاميذ';

  @override
  String get chargementFile => 'جاري تحميل القائمة...';

  @override
  String get aucunEleveAppele => 'لا يوجد تلاميذ تم النداء عليهم حالياً';

  @override
  String get reessayer => 'إعادة المحاولة';

  @override
  String get erreurChargement => 'حدث خطأ أثناء تحميل القائمة';

  @override
  String classeTitre(String className) {
    return 'قسم $className';
  }

  @override
  String heureAppel(String time) {
    return 'تم النداء في $time';
  }

  @override
  String get reconnexionReussie => 'تمت إعادة الاتصال وتحديث القائمة';
}
