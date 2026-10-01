// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'وكيل توزيع الغاز';

  @override
  String get appSubtitle => 'OTP · عربي / فرنسي';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get phone => 'رقم الهاتف';

  @override
  String get requestOtp => 'طلب رمز التحقق';

  @override
  String get otpCode => 'رمز التحقق';

  @override
  String get verify => 'تحقق';

  @override
  String get devCode => 'رمز التطوير';

  @override
  String get permissions => 'الأذونات';

  @override
  String get continueLabel => 'متابعة';

  @override
  String get vehicleCheck => 'فحص المركبة قبل الانطلاق';

  @override
  String get preTripTitle => 'السلامة والحمولة قبل الانطلاق';

  @override
  String get acceptLoad => 'قبول حمولة الشاحنة / بدء الوردية';

  @override
  String get starting => 'جارٍ البدء…';

  @override
  String get assignedVehicle => 'المركبة المخصصة';

  @override
  String get check1 => 'طفاية الحريق: العداد أخضر، الملصق ساري';

  @override
  String get check2 => 'أحزمة التثبيت / قضبان الربط موجودة وسليمة';

  @override
  String get check3 => 'تكديس الأسطوانات مطابق (الصمامات محمية)';

  @override
  String get check4 => 'لا يوجد صوت تسرّب / رائحة мерكابتان';

  @override
  String get check5 => 'سترة عاكسة، مثلثات، مثبتات عجلات';

  @override
  String get checklistMustPass => 'يجب اجتياز جميع بنود القائمة';

  @override
  String get shiftStarted => 'بدأت الوردية';

  @override
  String get routeMap => 'خريطة المسار';

  @override
  String get routeArrivalTitle => 'المسار والوصول';

  @override
  String get enRoute => 'في الطريق';

  @override
  String get arrival => 'الوصول';

  @override
  String get confirmArrival => 'تأكيد الوصول';

  @override
  String get arrived => 'وصلت';

  @override
  String get retryGps => 'إعادة تحديد الموقع';

  @override
  String get noGps => 'لا يوجد إشارة GPS — أعد المحاولة';

  @override
  String get noRoutes => 'لا توجد مسارات مخصصة';

  @override
  String get stops => 'المحطات';

  @override
  String get stop => 'محطة';

  @override
  String get tel => 'الهاتف';

  @override
  String get geofence => 'السياج';

  @override
  String get distance => 'المسافة';

  @override
  String get openDelivery => 'فتح التوصيل / الإرجاع / الدفع';

  @override
  String get stopSummary => 'ملخص النقطة';

  @override
  String get delivery => 'التوصيل';

  @override
  String get returns => 'الإرجاع';

  @override
  String get payment => 'الدفع';

  @override
  String get proof => 'إثبات / توقيع';

  @override
  String get reviewStop => 'مراجعة النقطة';

  @override
  String get exception => 'استثناء';

  @override
  String get deliveryTitle => 'التوصيل / الإرجاع / الدفع';

  @override
  String get recipientName => 'اسم المستلم (إثبات)';

  @override
  String get deliveredFull => 'تسليم ممتلئة';

  @override
  String get returnedEmpty => 'إرجاع فارغة';

  @override
  String get defective => 'معيبة';

  @override
  String get totalDue => 'الإجمالي المستحق (صافي التأمين)';

  @override
  String get cashCollected => 'المبلغ المحصل (درهم)';

  @override
  String get overrideCode => 'رمز الإدارة (عند حساب الائتمان)';

  @override
  String get creditLocked => 'الحساب معلق - تجاوز حد الائتمان';

  @override
  String get noStopSelected => 'لم يتم تحديد محطة';

  @override
  String get enterQty => 'أدخل كمية واحدة على الأقل';

  @override
  String get recipientRequired => 'اسم المستلام مطلوب (إثبات)';

  @override
  String get savedOffline =>
      'تم الحفظ دون اتصال — ستتم المزامنة عند عودة الاتصال';

  @override
  String get finalizeStop => 'إنهاء المحطة';

  @override
  String get saving => 'جارٍ الحفظ…';

  @override
  String get receipt => 'الإيصال';

  @override
  String get total => 'الإجمالي';

  @override
  String get balance => 'الرصيد';

  @override
  String get safetyReport => 'تقرير السلامة';

  @override
  String get safetyIncident => 'حادثة سلامة';

  @override
  String get incidentType => 'نوع الحادثة';

  @override
  String get severity => 'الخطورة';

  @override
  String get low => 'منخفضة';

  @override
  String get high => 'مرتفعة';

  @override
  String get critical => 'حرجة';

  @override
  String get description => 'الوصف (ماذا حدث، الإجراءات المتخذة)';

  @override
  String get descriptionRequired => 'الوصف مطلوب';

  @override
  String get noActiveShift => 'لا توجد وحدة نشطة — ابدأ الوردية أولاً';

  @override
  String get criticalAlert => 'الخطورة الحرجة ترفع تنبيهاً فورياً للمستودع.';

  @override
  String get submitIncident => 'تسجيل الحادثة';

  @override
  String get submitting => 'جارٍ الإرسال…';

  @override
  String get incidentRecorded => 'تم تسجيل الحادثة';

  @override
  String get typeLeak => 'تسريب';

  @override
  String get typeFire => 'حريق';

  @override
  String get typeCylinderDamage => 'تلف الأسطوانة';

  @override
  String get typeVehicleIncident => 'حادث مركبة';

  @override
  String get typeNearMiss => 'شبه حادث';

  @override
  String get typeOther => 'أخرى';

  @override
  String get reconciliation => 'المطابقة النهائية';

  @override
  String get reconciliationTitle => 'المطابقة والتفريغ';

  @override
  String get unloadDepot => 'تفريغ إلى المستودع (حسب الحالة)';

  @override
  String get full => 'ممتلئة';

  @override
  String get empty => 'فارغة';

  @override
  String get declaredCash => 'النقد المعلن (درهم)';

  @override
  String get closeoutHelp => 'التسليم المادي + صورتان مطلوبان لإنهاء النقد.';

  @override
  String get noActiveShiftClose => 'لا توجد وحدة نشطة';

  @override
  String get finalizeCloseout => 'إنهاء المطابقة والتفريغ';

  @override
  String get closing => 'جارٍ الإنهاء…';

  @override
  String get closeoutComplete => 'اكتملت المطابقة';

  @override
  String get closeoutQueued =>
      'تم الحفظ دون اتصال — ستتم المزامنة عند عودة الاتصال';

  @override
  String get movements => 'الحركات';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get syncPending => 'في انتظار المزامنة';

  @override
  String get syncOk => 'تمت المزامنة';

  @override
  String get homeVehicleCheck => 'فحص المركبة / قبول الحمولة';

  @override
  String get homeRoute => 'خريطة المسار والمحطات';

  @override
  String get homeDelivery => 'التوصيل / الإرجاع / الدفع';

  @override
  String get homeSafety => 'تقرير حادثة السلامة';

  @override
  String get homeReconciliation => 'المطابقة والتفريغ';

  @override
  String get readyPermissions => 'جاهز لطلب الأذونات';

  @override
  String get enableLocation => 'فعّل خدمة الموقع من إعدادات النظام';

  @override
  String get locationDenied => 'تم رفض إذن الموقع';

  @override
  String get permissionsGranted => 'تم منح الأذونات';

  @override
  String get consentTitle => 'الموافقة';

  @override
  String get consentBody => 'يتم جمع الموقع الجغرافي فقط أثناء وردية نشطة.';

  @override
  String get consentNotice =>
      'يتم جمع الموقع فقط أثناء الوردية النشطة (بدء الوردية ← الإغلاق). مدة الاحتفاظ: GPS ٩٠ يوماً، السجلات التجارية ١٠ سنوات، سجلات التدقيق ٣ سنوات.';

  @override
  String get permissionsBody =>
      'موقع أمامي وخلفي (فترة الوردية فقط)،\nكاميرا لإثباتات التصوير، تخزين للحزمة دون اتصال.';

  @override
  String get grantPermissions => 'منح الأذونات';

  @override
  String get ok => 'موافق';

  @override
  String get langToggle => 'Français';

  @override
  String get status_PENDING => 'قيد الانتظار';

  @override
  String get status_EN_ROUTE => 'في الطريق';

  @override
  String get status_NEARBY => 'قريب';

  @override
  String get status_ARRIVED => 'وصل';

  @override
  String get status_IN_SERVICE => 'قيد الخدمة';

  @override
  String get status_COMPLETED => 'مكتمل';

  @override
  String get status_EXCEPTION => 'استثناء';

  @override
  String get status_ACTIVE => 'نشط';

  @override
  String get status_DRAFT => 'مسودة';

  @override
  String get apiError => 'خطأ في الاتصال';
}
