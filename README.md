# أذكار – Flutter Native

مشروع Flutter عربي (RTL) مبني كتطبيق Android Native، وليس WebView.

## ما يتضمنه
- 44 ذكراً مستخرجاً من ملف HTML الأصلي (الصباح والمساء).
- عدادات تكرار مستقلة لكل ذكر، ومفضلة، وبحث.
- مسبحة بأهداف 33 و66 و99.
- الوضع الفاتح والداكن.
- مواقيت الصلاة لسطيف عبر واجهة AlAdhan.
- حفظ التقدم محلياً باستخدام SharedPreferences.

## بناء APK عبر GitHub Actions
1. فك ضغط الأرشيف.
2. افتح المستودع في GitHub وارفع **محتويات** مجلد `adhkar_flutter` إلى جذر المستودع، مع مجلد `.github`.
3. افتح تبويب Actions وفعّل workflows إذا طلب GitHub ذلك.
4. شغّل `Build Android APK` من Run workflow، أو ادفع commit إلى `main` أو `master`.
5. بعد نجاح التشغيل افتح Artifacts وحمّل `adhkar-release-apk`.

## ملاحظات
- يحذف المشروع اعتماد `intl` غير المستخدم لتجنب تعارضه مع إصدار `intl` الذي يثبته Flutter SDK عبر `flutter_localizations`.
- ينشئ GitHub Actions ملفات Android القياسية باستخدام Flutter، ثم يبني APK release.
- تم ضبط Java 17 لبناء Android Gradle.
- تم إصلاح خلفية البطاقات المتدرجة: لا يجتمع `color` و`gradient` في `BoxDecoration` لأن Flutter يمنع ذلك.
- قسم القرآن والأدعية يحتاجان إلى إضافة محتوى موثوق لاحقاً؛ لم يكن محتوى كامل لهما موجوداً في ملف HTML الأصلي.
