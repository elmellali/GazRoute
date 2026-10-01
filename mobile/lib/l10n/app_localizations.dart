import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('fr')
  ];

  /// No description provided for @appTitle.
  ///
  /// In ar, this message translates to:
  /// **'وكيل توزيع الغاز'**
  String get appTitle;

  /// No description provided for @appSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'OTP · عربي / فرنسي'**
  String get appSubtitle;

  /// No description provided for @login.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get login;

  /// No description provided for @phone.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف'**
  String get phone;

  /// No description provided for @requestOtp.
  ///
  /// In ar, this message translates to:
  /// **'طلب رمز التحقق'**
  String get requestOtp;

  /// No description provided for @otpCode.
  ///
  /// In ar, this message translates to:
  /// **'رمز التحقق'**
  String get otpCode;

  /// No description provided for @verify.
  ///
  /// In ar, this message translates to:
  /// **'تحقق'**
  String get verify;

  /// No description provided for @devCode.
  ///
  /// In ar, this message translates to:
  /// **'رمز التطوير'**
  String get devCode;

  /// No description provided for @permissions.
  ///
  /// In ar, this message translates to:
  /// **'الأذونات'**
  String get permissions;

  /// No description provided for @continueLabel.
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get continueLabel;

  /// No description provided for @vehicleCheck.
  ///
  /// In ar, this message translates to:
  /// **'فحص المركبة قبل الانطلاق'**
  String get vehicleCheck;

  /// No description provided for @preTripTitle.
  ///
  /// In ar, this message translates to:
  /// **'السلامة والحمولة قبل الانطلاق'**
  String get preTripTitle;

  /// No description provided for @acceptLoad.
  ///
  /// In ar, this message translates to:
  /// **'قبول حمولة الشاحنة / بدء الوردية'**
  String get acceptLoad;

  /// No description provided for @starting.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ البدء…'**
  String get starting;

  /// No description provided for @assignedVehicle.
  ///
  /// In ar, this message translates to:
  /// **'المركبة المخصصة'**
  String get assignedVehicle;

  /// No description provided for @check1.
  ///
  /// In ar, this message translates to:
  /// **'طفاية الحريق: العداد أخضر، الملصق ساري'**
  String get check1;

  /// No description provided for @check2.
  ///
  /// In ar, this message translates to:
  /// **'أحزمة التثبيت / قضبان الربط موجودة وسليمة'**
  String get check2;

  /// No description provided for @check3.
  ///
  /// In ar, this message translates to:
  /// **'تكديس الأسطوانات مطابق (الصمامات محمية)'**
  String get check3;

  /// No description provided for @check4.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد صوت تسرّب / رائحة мерكابتان'**
  String get check4;

  /// No description provided for @check5.
  ///
  /// In ar, this message translates to:
  /// **'سترة عاكسة، مثلثات، مثبتات عجلات'**
  String get check5;

  /// No description provided for @checklistMustPass.
  ///
  /// In ar, this message translates to:
  /// **'يجب اجتياز جميع بنود القائمة'**
  String get checklistMustPass;

  /// No description provided for @shiftStarted.
  ///
  /// In ar, this message translates to:
  /// **'بدأت الوردية'**
  String get shiftStarted;

  /// No description provided for @routeMap.
  ///
  /// In ar, this message translates to:
  /// **'خريطة المسار'**
  String get routeMap;

  /// No description provided for @routeArrivalTitle.
  ///
  /// In ar, this message translates to:
  /// **'المسار والوصول'**
  String get routeArrivalTitle;

  /// No description provided for @enRoute.
  ///
  /// In ar, this message translates to:
  /// **'في الطريق'**
  String get enRoute;

  /// No description provided for @arrival.
  ///
  /// In ar, this message translates to:
  /// **'الوصول'**
  String get arrival;

  /// No description provided for @confirmArrival.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الوصول'**
  String get confirmArrival;

  /// No description provided for @arrived.
  ///
  /// In ar, this message translates to:
  /// **'وصلت'**
  String get arrived;

  /// No description provided for @retryGps.
  ///
  /// In ar, this message translates to:
  /// **'إعادة تحديد الموقع'**
  String get retryGps;

  /// No description provided for @noGps.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد إشارة GPS — أعد المحاولة'**
  String get noGps;

  /// No description provided for @noRoutes.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مسارات مخصصة'**
  String get noRoutes;

  /// No description provided for @stops.
  ///
  /// In ar, this message translates to:
  /// **'المحطات'**
  String get stops;

  /// No description provided for @stop.
  ///
  /// In ar, this message translates to:
  /// **'محطة'**
  String get stop;

  /// No description provided for @tel.
  ///
  /// In ar, this message translates to:
  /// **'الهاتف'**
  String get tel;

  /// No description provided for @geofence.
  ///
  /// In ar, this message translates to:
  /// **'السياج'**
  String get geofence;

  /// No description provided for @distance.
  ///
  /// In ar, this message translates to:
  /// **'المسافة'**
  String get distance;

  /// No description provided for @openDelivery.
  ///
  /// In ar, this message translates to:
  /// **'فتح التوصيل / الإرجاع / الدفع'**
  String get openDelivery;

  /// No description provided for @stopSummary.
  ///
  /// In ar, this message translates to:
  /// **'ملخص النقطة'**
  String get stopSummary;

  /// No description provided for @delivery.
  ///
  /// In ar, this message translates to:
  /// **'التوصيل'**
  String get delivery;

  /// No description provided for @returns.
  ///
  /// In ar, this message translates to:
  /// **'الإرجاع'**
  String get returns;

  /// No description provided for @payment.
  ///
  /// In ar, this message translates to:
  /// **'الدفع'**
  String get payment;

  /// No description provided for @proof.
  ///
  /// In ar, this message translates to:
  /// **'إثبات / توقيع'**
  String get proof;

  /// No description provided for @reviewStop.
  ///
  /// In ar, this message translates to:
  /// **'مراجعة النقطة'**
  String get reviewStop;

  /// No description provided for @exception.
  ///
  /// In ar, this message translates to:
  /// **'استثناء'**
  String get exception;

  /// No description provided for @deliveryTitle.
  ///
  /// In ar, this message translates to:
  /// **'التوصيل / الإرجاع / الدفع'**
  String get deliveryTitle;

  /// No description provided for @recipientName.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستلم (إثبات)'**
  String get recipientName;

  /// No description provided for @deliveredFull.
  ///
  /// In ar, this message translates to:
  /// **'تسليم ممتلئة'**
  String get deliveredFull;

  /// No description provided for @returnedEmpty.
  ///
  /// In ar, this message translates to:
  /// **'إرجاع فارغة'**
  String get returnedEmpty;

  /// No description provided for @defective.
  ///
  /// In ar, this message translates to:
  /// **'معيبة'**
  String get defective;

  /// No description provided for @totalDue.
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي المستحق (صافي التأمين)'**
  String get totalDue;

  /// No description provided for @cashCollected.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ المحصل (درهم)'**
  String get cashCollected;

  /// No description provided for @overrideCode.
  ///
  /// In ar, this message translates to:
  /// **'رمز الإدارة (عند حساب الائتمان)'**
  String get overrideCode;

  /// No description provided for @creditLocked.
  ///
  /// In ar, this message translates to:
  /// **'الحساب معلق - تجاوز حد الائتمان'**
  String get creditLocked;

  /// No description provided for @noStopSelected.
  ///
  /// In ar, this message translates to:
  /// **'لم يتم تحديد محطة'**
  String get noStopSelected;

  /// No description provided for @enterQty.
  ///
  /// In ar, this message translates to:
  /// **'أدخل كمية واحدة على الأقل'**
  String get enterQty;

  /// No description provided for @recipientRequired.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستلام مطلوب (إثبات)'**
  String get recipientRequired;

  /// No description provided for @savedOffline.
  ///
  /// In ar, this message translates to:
  /// **'تم الحفظ دون اتصال — ستتم المزامنة عند عودة الاتصال'**
  String get savedOffline;

  /// No description provided for @finalizeStop.
  ///
  /// In ar, this message translates to:
  /// **'إنهاء المحطة'**
  String get finalizeStop;

  /// No description provided for @saving.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ الحفظ…'**
  String get saving;

  /// No description provided for @receipt.
  ///
  /// In ar, this message translates to:
  /// **'الإيصال'**
  String get receipt;

  /// No description provided for @total.
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي'**
  String get total;

  /// No description provided for @balance.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد'**
  String get balance;

  /// No description provided for @safetyReport.
  ///
  /// In ar, this message translates to:
  /// **'تقرير السلامة'**
  String get safetyReport;

  /// No description provided for @safetyIncident.
  ///
  /// In ar, this message translates to:
  /// **'حادثة سلامة'**
  String get safetyIncident;

  /// No description provided for @incidentType.
  ///
  /// In ar, this message translates to:
  /// **'نوع الحادثة'**
  String get incidentType;

  /// No description provided for @severity.
  ///
  /// In ar, this message translates to:
  /// **'الخطورة'**
  String get severity;

  /// No description provided for @low.
  ///
  /// In ar, this message translates to:
  /// **'منخفضة'**
  String get low;

  /// No description provided for @high.
  ///
  /// In ar, this message translates to:
  /// **'مرتفعة'**
  String get high;

  /// No description provided for @critical.
  ///
  /// In ar, this message translates to:
  /// **'حرجة'**
  String get critical;

  /// No description provided for @description.
  ///
  /// In ar, this message translates to:
  /// **'الوصف (ماذا حدث، الإجراءات المتخذة)'**
  String get description;

  /// No description provided for @descriptionRequired.
  ///
  /// In ar, this message translates to:
  /// **'الوصف مطلوب'**
  String get descriptionRequired;

  /// No description provided for @noActiveShift.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد وحدة نشطة — ابدأ الوردية أولاً'**
  String get noActiveShift;

  /// No description provided for @criticalAlert.
  ///
  /// In ar, this message translates to:
  /// **'الخطورة الحرجة ترفع تنبيهاً فورياً للمستودع.'**
  String get criticalAlert;

  /// No description provided for @submitIncident.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الحادثة'**
  String get submitIncident;

  /// No description provided for @submitting.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ الإرسال…'**
  String get submitting;

  /// No description provided for @incidentRecorded.
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل الحادثة'**
  String get incidentRecorded;

  /// No description provided for @typeLeak.
  ///
  /// In ar, this message translates to:
  /// **'تسريب'**
  String get typeLeak;

  /// No description provided for @typeFire.
  ///
  /// In ar, this message translates to:
  /// **'حريق'**
  String get typeFire;

  /// No description provided for @typeCylinderDamage.
  ///
  /// In ar, this message translates to:
  /// **'تلف الأسطوانة'**
  String get typeCylinderDamage;

  /// No description provided for @typeVehicleIncident.
  ///
  /// In ar, this message translates to:
  /// **'حادث مركبة'**
  String get typeVehicleIncident;

  /// No description provided for @typeNearMiss.
  ///
  /// In ar, this message translates to:
  /// **'شبه حادث'**
  String get typeNearMiss;

  /// No description provided for @typeOther.
  ///
  /// In ar, this message translates to:
  /// **'أخرى'**
  String get typeOther;

  /// No description provided for @reconciliation.
  ///
  /// In ar, this message translates to:
  /// **'المطابقة النهائية'**
  String get reconciliation;

  /// No description provided for @reconciliationTitle.
  ///
  /// In ar, this message translates to:
  /// **'المطابقة والتفريغ'**
  String get reconciliationTitle;

  /// No description provided for @unloadDepot.
  ///
  /// In ar, this message translates to:
  /// **'تفريغ إلى المستودع (حسب الحالة)'**
  String get unloadDepot;

  /// No description provided for @full.
  ///
  /// In ar, this message translates to:
  /// **'ممتلئة'**
  String get full;

  /// No description provided for @empty.
  ///
  /// In ar, this message translates to:
  /// **'فارغة'**
  String get empty;

  /// No description provided for @declaredCash.
  ///
  /// In ar, this message translates to:
  /// **'النقد المعلن (درهم)'**
  String get declaredCash;

  /// No description provided for @closeoutHelp.
  ///
  /// In ar, this message translates to:
  /// **'التسليم المادي + صورتان مطلوبان لإنهاء النقد.'**
  String get closeoutHelp;

  /// No description provided for @noActiveShiftClose.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد وحدة نشطة'**
  String get noActiveShiftClose;

  /// No description provided for @finalizeCloseout.
  ///
  /// In ar, this message translates to:
  /// **'إنهاء المطابقة والتفريغ'**
  String get finalizeCloseout;

  /// No description provided for @closing.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ الإنهاء…'**
  String get closing;

  /// No description provided for @closeoutComplete.
  ///
  /// In ar, this message translates to:
  /// **'اكتملت المطابقة'**
  String get closeoutComplete;

  /// No description provided for @closeoutQueued.
  ///
  /// In ar, this message translates to:
  /// **'تم الحفظ دون اتصال — ستتم المزامنة عند عودة الاتصال'**
  String get closeoutQueued;

  /// No description provided for @movements.
  ///
  /// In ar, this message translates to:
  /// **'الحركات'**
  String get movements;

  /// No description provided for @logout.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get logout;

  /// No description provided for @syncPending.
  ///
  /// In ar, this message translates to:
  /// **'في انتظار المزامنة'**
  String get syncPending;

  /// No description provided for @syncOk.
  ///
  /// In ar, this message translates to:
  /// **'تمت المزامنة'**
  String get syncOk;

  /// No description provided for @homeVehicleCheck.
  ///
  /// In ar, this message translates to:
  /// **'فحص المركبة / قبول الحمولة'**
  String get homeVehicleCheck;

  /// No description provided for @homeRoute.
  ///
  /// In ar, this message translates to:
  /// **'خريطة المسار والمحطات'**
  String get homeRoute;

  /// No description provided for @homeDelivery.
  ///
  /// In ar, this message translates to:
  /// **'التوصيل / الإرجاع / الدفع'**
  String get homeDelivery;

  /// No description provided for @homeSafety.
  ///
  /// In ar, this message translates to:
  /// **'تقرير حادثة السلامة'**
  String get homeSafety;

  /// No description provided for @homeReconciliation.
  ///
  /// In ar, this message translates to:
  /// **'المطابقة والتفريغ'**
  String get homeReconciliation;

  /// No description provided for @readyPermissions.
  ///
  /// In ar, this message translates to:
  /// **'جاهز لطلب الأذونات'**
  String get readyPermissions;

  /// No description provided for @enableLocation.
  ///
  /// In ar, this message translates to:
  /// **'فعّل خدمة الموقع من إعدادات النظام'**
  String get enableLocation;

  /// No description provided for @locationDenied.
  ///
  /// In ar, this message translates to:
  /// **'تم رفض إذن الموقع'**
  String get locationDenied;

  /// No description provided for @permissionsGranted.
  ///
  /// In ar, this message translates to:
  /// **'تم منح الأذونات'**
  String get permissionsGranted;

  /// No description provided for @consentTitle.
  ///
  /// In ar, this message translates to:
  /// **'الموافقة'**
  String get consentTitle;

  /// No description provided for @consentBody.
  ///
  /// In ar, this message translates to:
  /// **'يتم جمع الموقع الجغرافي فقط أثناء وردية نشطة.'**
  String get consentBody;

  /// No description provided for @consentNotice.
  ///
  /// In ar, this message translates to:
  /// **'يتم جمع الموقع فقط أثناء الوردية النشطة (بدء الوردية ← الإغلاق). مدة الاحتفاظ: GPS ٩٠ يوماً، السجلات التجارية ١٠ سنوات، سجلات التدقيق ٣ سنوات.'**
  String get consentNotice;

  /// No description provided for @permissionsBody.
  ///
  /// In ar, this message translates to:
  /// **'موقع أمامي وخلفي (فترة الوردية فقط)،\nكاميرا لإثباتات التصوير، تخزين للحزمة دون اتصال.'**
  String get permissionsBody;

  /// No description provided for @grantPermissions.
  ///
  /// In ar, this message translates to:
  /// **'منح الأذونات'**
  String get grantPermissions;

  /// No description provided for @ok.
  ///
  /// In ar, this message translates to:
  /// **'موافق'**
  String get ok;

  /// No description provided for @langToggle.
  ///
  /// In ar, this message translates to:
  /// **'Français'**
  String get langToggle;

  /// No description provided for @status_PENDING.
  ///
  /// In ar, this message translates to:
  /// **'قيد الانتظار'**
  String get status_PENDING;

  /// No description provided for @status_EN_ROUTE.
  ///
  /// In ar, this message translates to:
  /// **'في الطريق'**
  String get status_EN_ROUTE;

  /// No description provided for @status_NEARBY.
  ///
  /// In ar, this message translates to:
  /// **'قريب'**
  String get status_NEARBY;

  /// No description provided for @status_ARRIVED.
  ///
  /// In ar, this message translates to:
  /// **'وصل'**
  String get status_ARRIVED;

  /// No description provided for @status_IN_SERVICE.
  ///
  /// In ar, this message translates to:
  /// **'قيد الخدمة'**
  String get status_IN_SERVICE;

  /// No description provided for @status_COMPLETED.
  ///
  /// In ar, this message translates to:
  /// **'مكتمل'**
  String get status_COMPLETED;

  /// No description provided for @status_EXCEPTION.
  ///
  /// In ar, this message translates to:
  /// **'استثناء'**
  String get status_EXCEPTION;

  /// No description provided for @status_ACTIVE.
  ///
  /// In ar, this message translates to:
  /// **'نشط'**
  String get status_ACTIVE;

  /// No description provided for @status_DRAFT.
  ///
  /// In ar, this message translates to:
  /// **'مسودة'**
  String get status_DRAFT;

  /// No description provided for @apiError.
  ///
  /// In ar, this message translates to:
  /// **'خطأ في الاتصال'**
  String get apiError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
