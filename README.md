# Mauri student — دروسي موريتانيا

تطبيق Flutter مستقل عن موقع MauriResults، مخصص للدروس والتمارين والامتحانات الموريتانية مع القراءة والتنزيل دون إنترنت. يدعم العربية والفرنسية، البحث والفلاتر، المفضلة، وتنزيل PDF إلى ذاكرة الهاتف.

## تحميل التطبيق

- **[تنزيل النسخة الخفيفة ARM64 (18.7 MB)](https://github.com/mauriresults/mauri-study-app/releases/download/preview-compact-04b44a44/Mauri-student-0.2.0-arm64-v8a-compact-preview.apk)** — للهواتف الحديثة (الموصى بها).
- **[تنزيل النسخة الخفيفة ARM32 (16.2 MB)](https://github.com/mauriresults/mauri-study-app/releases/download/preview-compact-499494a8/Mauri-student-0.2.0-armeabi-v7a-compact-preview.apk)** — للهواتف القديمة 32-bit.
- **[صفحة الإصدار الخفيف وبصمات SHA-256](https://github.com/mauriresults/mauri-study-app/releases/tag/preview-compact-04b44a44)**. لا تُنزّل النسختين معًا.
- **[بناء Android الخفيف واختباراته](https://github.com/mauriresults/mauri-study-app/actions/workflows/compact-android.yml)**.
- **[مستند تثبيت مفاتيح Google Play وبناء AAB](docs/GOOGLE_PLAY_SIGNING.md)**.
- **[تقرير النقل الحالي والتحقق من 19 PDF جديدًا](docs/LIVE_MIGRATION_AUDIT_2026-10-31.md)**، و[التقرير الأقدم](docs/LIBRARY_AND_SIZE_2026-10-31.md).

**حجم نسخ Android الخفيفة المتحقق منه:** 18.7 MB لـARM64 و16.2 MB لـARM32، مقارنة بحوالي 161 MB لنسخة Debug القديمة. هناك AAB تجريبي بحجم 52.5 MB، لكنه **ليس موقّعًا بمفتاح إنتاج للمتجر**.

لا يحتوي APK على مكتبة PDF؛ الدروس تُحمّل حسب طلب الطالب فقط، فلا يكبر ملف التطبيق عند إضافة المراجع.

## المكتبة السحابية

- Cloudflare Worker: `mauri-study-app-api`
- Cloudflare D1: `mauri-study-app-db`
- Cloudflare R2: `mauri-study-files` (خاص وغير مكشوف مباشرة)
- **110 ملفات PDF منشورة فعليًا في D1 وR2** بحجم **37,717,690 بايت (37.72 MB)** في تدقيق 31 أكتوبر 2026، مع 110 بصمات SHA-256 مختلفة. تشمل هذه الحصيلة 19 ملفًا جديدًا (2,994,563 بايت) تم نقلها والتحقق منها في الجلسة الأخيرة.
- **712 سجل مصدر من فهرسي الموقع الأساسيين** بعد إزالة 4 تداخلات: 79 نُقلت وربطت بالمصادر، 4 معلمة مكررة، و**629 سجلًا معلّقًا** بحجم معلن إجمالي **2,481,769,489 بايت** (ليس حجم ملفات تم التحقق من إمكان تنزيلها). قائمة النقل القديمة ذات 159 سجلًا متداخلة مع القائمة الأشمل، وليست إضافة إليها.
- تحديث الواجهة: صفحة رئيسية أبسط، وتصفح السنة ← الشعبة ← المادة ← نوع الملف ← سنة الامتحان عند توافرها، مع عرض التصحيحات والحلول بشكل مستقل؛ المشاهدة عبر الإنترنت منفصلة عن تنزيل PDF الدائم. تدعم المزامنة صفحات الفهرس والمفضلة والتنزيلات المحفوظة.
- تحسينات المكتبة والمشاهدة دُمجت في `main` على commit `8bb3840a` بعد اجتياز اختبارات Flutter وAPI وبناء Android التجريبي. تصدر نسخ APK الحديثة ضمن إصدارات GitHub التجريبية، ولا تمثل إصدارات متجر Google Play.
- **ما يزال نقل بقية محتويات الموقع غير مكتمل**: 629 سجلًا مصدرًا في انتظار التحقق والنقل، بالإضافة إلى مراجع الكتب المدرسية والمجموعات الخارجية الأخرى. لا تُعرض روابط المصدر غير المستضافة على أنها ملفات موجودة في التطبيق.

## التحقق

- نجح بناء APK الخفيف، واختبارات Flutter والتحليل، وفحص التوقيع وSHA-256.
- نجح بناء AAB تجريبي. الإنتاج الرسمي يحتاج مفاتيح رفع خاصة محفوظة في GitHub Secrets، وتوقيع AAB بمفتاح رفع مستقر.
- ما زالت اختبارات التثبيت على الأجهزة الحقيقية وتوزيع Google Play خارج نطاق التحقق الحالي.
- لا تُجرى تعديلات على موقع MauriResults أو نشره أو قاعدة بياناته من هذه المستودع.

## تطوير المشروع

Flutter `3.47.9`، ودليل التطبيق في `app/`، وكود Workers في `backend/`، وأدوات الاستيراد والتحقق في `scripts/`.

```bash
python scripts/generate_platforms.py
python scripts/configure_android.py
cd app
flutter pub get
flutter analyze
flutter test
flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64 --tree-shake-icons --dart-define=API_BASE_URL=https://mauri-study-app-api.mauri-study-app.workers.dev
```

- **[اختبارات API والاستيراد](https://github.com/mauriresults/mauri-study-app/actions/workflows/backend-tests.yml)**
- **[تدقيق API والملفات](https://github.com/mauriresults/mauri-study-app/actions/workflows/api-audit.yml)**

لا تضع مفاتيح Cloudflare أو Google Drive أو شهادات توقيع Google Play داخل المستودع أو التطبيق.
