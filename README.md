# Mauri student — دروسي موريتانيا

تطبيق Flutter مستقل عن موقع MauriResults، مخصص للدروس والتمارين والامتحانات الموريتانية مع القراءة والتنزيل دون إنترنت. يدعم العربية والفرنسية، البحث والفلاتر، المفضلة، وتنزيل PDF إلى ذاكرة الهاتف.

## تحميل التطبيق

- **[تنزيل النسخة الخفيفة ARM64 (18.7 MB)](https://github.com/mauriresults/mauri-study-app/releases/download/preview-compact-04b44a44/Mauri-student-0.2.0-arm64-v8a-compact-preview.apk)** — للهواتف الحديثة (الموصى بها).
- **[تنزيل النسخة الخفيفة ARM32 (16.2 MB)](https://github.com/mauriresults/mauri-study-app/releases/download/preview-compact-499494a8/Mauri-student-0.2.0-armeabi-v7a-compact-preview.apk)** — للهواتف القديمة 32-bit.
- **[صفحة الإصدار الخفيف وبصمات SHA-256](https://github.com/mauriresults/mauri-study-app/releases/tag/preview-compact-04b44a44)**. لا تُنزّل النسختين معًا.
- **[بناء Android الخفيف واختباراته](https://github.com/mauriresults/mauri-study-app/actions/workflows/compact-android.yml)**.
- **[مستند تثبيت مفاتيح Google Play وبناء AAB](docs/GOOGLE_PLAY_SIGNING.md)**.
- **[تقرير نقل المراجع وحجم التطبيق](docs/LIBRARY_AND_SIZE_2026-10-31.md)**.

**حجم نسخ Android الخفيفة المتحقق منه:** 18.7 MB لـARM64 و16.2 MB لـARM32، مقارنة بحوالي 161 MB لنسخة Debug القديمة. هناك AAB تجريبي بحجم 52.5 MB، لكنه **ليس موقّعًا بمفتاح إنتاج للمتجر**.

لا يحتوي APK على مكتبة PDF؛ الدروس تُحمّل حسب طلب الطالب فقط، فلا يكبر ملف التطبيق عند إضافة المراجع.

## المكتبة السحابية

- Cloudflare Worker: `mauri-study-app-api`
- Cloudflare D1: `mauri-study-app-db`
- Cloudflare R2: `mauri-study-files` (خاص وغير مكشوف مباشرة)
- **50 ملف PDF حقيقيًا منشورًا ومفهرسًا** بحجم **27,868,674 بايت (27.87 MB)** بتاريخ 31 أكتوبر 2026؛ 50 بصمة SHA-256 مختلفة، موزعة بين الخامسة الثانوية، السادسة، والبكالوريا. التصنيفات تشمل الكتب والدروس والتمارين والامتحانات والملخصات.
- **109 ملفات معلّقة** (558,060,329 بايت، نحو 558 MB) مكتشفة في قائمتي المصادر؛ لا تُعرض في التطبيق قبل نجاح نقل الملف نفسه إلى R2 والتحقق من سلامته. الفهرسة المصدرية لا تعني النشر.
- تحديث الواجهة: تصفح مباشر السنة → الشعبة → المادة، بحث يشمل تسميات المواد باللغتين العربية والفرنسية، وزر تنزيل مباشر. المزامنة تستخدم جلب الفهرس دون تكرار تحميل محتوى قائمة الملفات.
- أحدث نسخة Android المجتازة للاختبارات مصدرها commit `04b44a44` (نسخة معاينة تجريبية، وليست منشورة في المتجر).
- الهدف الذي لم يكتمل بعد: ترحيل المكتبة التعليمية الكبيرة متعددة المجلدات. يتطلب ذلك مصدرًا قابلًا للتنزيل الموثوق، حقوق إعادة النشر، ونقلًا متدرجًا بتكاليف مدروسة.

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
