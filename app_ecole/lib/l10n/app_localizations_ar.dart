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

  @override
  String get enDirect => 'مباشر';

  @override
  String get reconnexionEnCours => 'جاري إعادة الاتصال...';

  @override
  String get miseAJourEnCours => 'جاري التحديث...';

  @override
  String get statutPrevenu => 'تم الإشعار';

  @override
  String get sansClasse => 'بدون قسم';

  @override
  String get boutonParti => 'غادر';

  @override
  String get erreurDepart => 'حدث خطأ أثناء تسجيل مغادرة التلميذ';

  @override
  String get appTitle => 'مغادرة المدرسة — تطبيق المدرسة';

  @override
  String get loginTitre => 'تسجيل الدخول — فضاء المدرسة';

  @override
  String get loginSousTitre => 'بوابة الاستقبال ومراقبة مغادرة التلاميذ';

  @override
  String get loginBadgePersonnel => 'أطر المدرسة';

  @override
  String get loginNumeroLabel => 'رقم الهاتف';

  @override
  String get loginNumeroHint => '6 12 34 56 78';

  @override
  String get loginIndicatifMaroc => '+212';

  @override
  String get loginAideSaisie => 'أدخل رقم هاتفك المهني المسجل لدى المدرسة';

  @override
  String get loginBoutonEnvoyer => 'توصل برمز التحقق عبر SMS';

  @override
  String get loginErreurTelephoneRequis => 'يرجى إدخال رقم الهاتف';

  @override
  String get loginErreurTelephoneInvalide =>
      'رقم الهاتف غير صالح (يجب أن يبدأ بـ 06 أو 07)';

  @override
  String get loginTitreOtp => 'التحقق من رمز التأكيد';

  @override
  String loginSousTitreOtp(String phone) {
    return 'أدخل الرمز السري المكون من 6 أرقام المرسل إلى $phone';
  }

  @override
  String get loginOtpLabel => 'رمز التحقق';

  @override
  String get loginOtpHint => '000000';

  @override
  String get loginBoutonValider => 'تأكيد وتسجيل الدخول';

  @override
  String get loginBoutonModifierNumero => 'تعديل الرقم';

  @override
  String get loginBoutonRenvoyer => 'إعادة إرسال الرمز';

  @override
  String loginRenvoyerDans(int seconds) {
    return 'إعادة الإرسال بعد $seconds ثانية';
  }

  @override
  String get loginErreurOtpRequis => 'يرجى إدخال الرمز المكون من 6 أرقام';

  @override
  String get loginErreurOtpInvalide => 'يجب أن يتكون الرمز من 6 أرقام بالضبط';

  @override
  String get loginErreurOtpEchoue =>
      'رمز التحقق غير صحيح أو منتهي الصلاحية. يرجى المحاولة مرة أخرى.';

  @override
  String get loginErreurUtilisateurIntrouvable =>
      'المستخدم غير موجود. يرجى الاتصال بإدارة المؤسسة.';

  @override
  String get loginErreurTropDeTentatives =>
      'محاولات كثيرة جداً. يرجى الانتظار بضع دقائق قبل إعادة المحاولة.';

  @override
  String get loginErreurRoleNonAutorise =>
      'الدخول مخصص فقط لأطر المدرسة (المراقبون، أعوان الاستقبال، الإدارة).';

  @override
  String get loginErreurReseau =>
      'خطأ في الاتصال بالشبكة. يرجى التحقق من اتصالك بالإنترنت.';

  @override
  String get loginBadgeSecurite =>
      'مطابق للجنة CNDP والقانون 09-08 — البيانات محمية';

  @override
  String get loginSucces => 'تم تسجيل الدخول بنجاح. مرحباً بكم!';

  @override
  String get loginChangerLangue => 'تغيير اللغة';

  @override
  String get roleSurveillant => 'مراقب';

  @override
  String get roleAgent => 'عامل استقبال';

  @override
  String get roleDirection => 'الإدارة';
}
