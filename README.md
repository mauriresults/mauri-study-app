# Mauri student — دروسي موريتانيا

تطبيق Flutter مستقل عن موقع MauriResults، مخصص للدروس والتمارين والامتحانات الموريتانية مع القراءة والتنزيل دون إنترنت. يدعم العربية والفرنسية، البحث والفلاتر، المفضلة، وتنزيل PDF إلى ذاكرة الهاتف.

## تحميل التطبيق

- **[تنزيل النسخة الخفيفة ARM64 (26.5 MB)](https://github.com/mauriresults/mauri-study-app/releases/download/preview-compact-8bb3840a/Mauri-student-0.2.0-arm64-v8a-compact-preview.apk)** — للهواتف الحديثة (الموصى بها).
- **[تنزيل النسخة الخفيفة ARM32 (21.8 MB)](https://github.com/mauriresults/mauri-study-app/releases/download/preview-compact-8bb3840a/Mauri-student-0.2.0-armeabi-v7a-compact-preview.apk)** — للهواتف القديمة 32-bit.
- **[صفحة الإصدار الخفيف وبصمات SHA-256](https://github.com/mauriresults/mauri-study-app/releases/tag/preview-compact-8bb3840a)**. لا تُنزّل النسختين معًا.
- **[بناء Android الخفيف واختباراته](https://github.com/mauriresults/mauri-study-app/actions/workflows/compact-android.yml)**.
- **[مستند تثبيت مفاتيح Google Play وبناء AAB](docs/GOOGLE_PLAY_SIGNING.md)**.
- **[تقرير النقل الحالي (6 نوفمبر 2026): 21 ملف PDF جديدًا مع التحقق من R2](docs/LIVE_MIGRATION_AUDIT_2026-11-06.md)**، و[تقرير 31 أكتوبر](docs/LIVE_MIGRATION_AUDIT_2026-10-31.md).

**حجم نسخ Android الخفيفة المتحقق منه:** 26.5 MB لـARM64 و21.8 MB لـARM32، مقارنة بحوالي 161 MB لنسخة Debug القديمة. هناك AAB تجريبي بحجم 52.5 MB، لكنه **ليس موقّعًا بمفتاح إنتاج للمتجر**.

لا يحتوي APK على مكتبة PDF؛ الدروس تُحمّل حسب طلب الطالب فقط، فلا يكبر ملف التطبيق عند إضافة المراجع.

## المكتبة السحابية

- Cloudflare Worker: `mauri-study-app-api`
- Cloudflare D1: `mauri-study-app-db`
- Cloudflare R2: `mauri-study-files` (خاص وغير مكشوف مباشرة)
- **139 ملف PDF منشورًا فعليًا في D1 وR2** بحجم **58,548,722 بايت (58.55 MB)** في تدقيق 6 نوفمبر 2026، مع 139 بصمة SHA-256 مختلفة. أضافت المتابعة الأحدث **21 ملفًا جديدًا صافيًا (15,208,890 بايت)** بعد التحقق من الحجم والبصمات بإعادة القراءة من R2.
- **712 سجل مصدر من فهرسي الموقع الأساسيين**: 108 نُقلت وربطت بالمصادر، 7 معلمة مكررة، وسجل واحد غير متاح بعد كشف PDF فارغ، و**596 سجلًا معلقًا**. الحجم المعلن للسجلات المعلقة حاليًا **2,497,207,576 بايت** بعد تصحيح أحجام خمسة كتب كانت غير معروفة سابقًا؛ هذا رقم من فهرس المصادر وليس حجم ملفات تم التحقق من إمكان تنزيلها. قائمة النقل القديمة ذات 159 سجلًا متداخلة مع القائمة الأشمل، وليست إضافة إليها.
- تحديث الواجهة: صفحة رئيسية أبسط، وتصفح السنة ← الشعبة ← المادة ← نوع الملف ← سنة الامتحان عند توافرها، مع عرض التصحيحات والحلول بشكل مستقل؛ المشاهدة عبر الإنترنت منفصلة عن تنزيل PDF الدائم. تدعم المزامنة صفحات الفهرس والمفضلة والتنزيلات المحفوظة.
- تحسينات المكتبة والمشاهدة دُمجت في `main` على commit `8bb3840a` بعد اجتياز اختبارات Flutter وAPI وبناء Android التجريبي. تصدر نسخ APK الحديثة ضمن إصدارات GitHub التجريبية، ولا تمثل إصدارات متجر Google Play.
- **ما يزال نقل بقية محتويات الموقع غير مكتمل**: 596 سجلًا مصدرًا في انتظار التحقق والنقل، بالإضافة إلى مراجع الكتب المدرسية والمجموعات الخارجية الأخرى. لا تُعرض روابط المصدر غير المستضافة على أنها ملفات موجودة في التطبيق.

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
