# Mauri student — دروسي موريتانيا

تطبيق Flutter مستقل عن موقع MauriResults، مخصص للدروس والتمارين والامتحانات الموريتانية مع القراءة والتنزيل دون إنترنت. يدعم العربية والفرنسية، البحث والفلاتر، المفضلة، وتنزيل PDF إلى ذاكرة الهاتف.

## تحميل التطبيق

- **[تنزيل أحدث إصدارات Android من GitHub Releases](https://github.com/mauriresults/mauri-study-app/releases)** — ابحث عن **compact ARM64** للغالبية العظمى من الهواتف الحديثة، أو **ARM32** للأجهزة الأقدم. لا تُنزّل النسختين معًا.
- **[بناء Android الخفيف واختباراته](https://github.com/mauriresults/mauri-study-app/actions/workflows/compact-android.yml)**.
- **[مستند تثبيت مفاتيح Google Play وبناء AAB](docs/GOOGLE_PLAY_SIGNING.md)**.
- **[تقرير نقل المراجع وحجم التطبيق](docs/LIBRARY_AND_SIZE_2026-10-31.md)**.

**حجم نسخ Android الخفيفة المتحقق منه:** 18.7 MB لـARM64 و16.2 MB لـARM32، مقارنة بحوالي 161 MB لنسخة Debug القديمة. هناك AAB تجريبي بحجم 52.5 MB، لكنه **ليس موقّعًا بمفتاح إنتاج للمتجر**.

لا يحتوي APK على مكتبة PDF؛ الدروس تُحمّل حسب طلب الطالب فقط، فلا يكبر ملف التطبيق عند إضافة المراجع.

## المكتبة السحابية

- Cloudflare Worker: `mauri-study-app-api`
- Cloudflare D1: `mauri-study-app-db`
- Cloudflare R2: `mauri-study-files` (خاص وغير مكشوف مباشرة)
- **19 ملف PDF منشورًا ومفهرسًا** بحجم إجمالي **3,872,734 بايت** بتاريخ 31 أكتوبر 2026، موزعة بين البكالوريا والخامسة الثانوية 5C/5D.
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
