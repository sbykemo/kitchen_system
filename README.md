# نظام إدارة المطبخ الداخلي - Oracle APEX & Oracle DB 23ai
# Indoor Kitchen Management System

هذا المشروع يحتوي على مخطط قاعدة البيانات الكامل (DDL)، الصلاحيات، الحزم البرمجية (PL/SQL Packages)، وبيانات الفحص الأولية لوصفات الطعام والمخزون، وتصميم واجهات وتطبيقات Oracle APEX.

---

## محتويات المشروع (Project Contents)

### 1. مجلد قاعدة البيانات (`/database`)
* **[security.sql](file:///C:/Users/dev12/.gemini/antigravity/scratch/kitchen_system/database/security.sql):** سكريبت تهيئة الأدوار (Roles) والمستخدمين والصلاحيات على مستوى قاعدة البيانات.
* **[schema.sql](file:///C:/Users/dev12/.gemini/antigravity/scratch/kitchen_system/database/schema.sql):** سكريبت إنشاء جداول المخزون، الوصفات، والطلبات مع القيود والفهارس.
* **[pkg_inventory.sql](file:///C:/Users/dev12/.gemini/antigravity/scratch/kitchen_system/database/pkg_inventory.sql):** حزمة PL/SQL لإدخال المشتريات ومراقبة كميات المخزون وتحديث التكلفة.
* **[pkg_recipes.sql](file:///C:/Users/dev12/.gemini/antigravity/scratch/kitchen_system/database/pkg_recipes.sql):** حزمة PL/SQL لحساب تكلفة الوجبات وهوامش الربح تلقائياً (تتعامل مع الوصفات الفرعية تراجعياً).
* **[pkg_orders.sql](file:///C:/Users/dev12/.gemini/antigravity/scratch/kitchen_system/database/pkg_orders.sql):** حزمة PL/SQL لمعالجة المبيعات وخصم المخزون بنظام FEFO (تاريخ الصلاحية الأقرب) عند بدء التحضير.
* **[triggers.sql](file:///C:/Users/dev12/.gemini/antigravity/scratch/kitchen_system/database/triggers.sql):** التريجرات الخاصة بضمان سلامة العمليات وتدقيق حالات الصلاحية.
* **[seed_data.sql](file:///C:/Users/dev12/.gemini/antigravity/scratch/kitchen_system/database/seed_data.sql):** بيانات فحص تجريبية للمكونات، الباتشات، الوصفات الفرعية والوجبات والعملاء.

### 2. مجلد واجهات التطبيق (`/apex`)
* **[APEX_DESIGN.md](file:///C:/Users/dev12/.gemini/antigravity/scratch/kitchen_system/apex/APEX_DESIGN.md):** وثيقة التصميم التفصيلية لتطبيقي الإدارة (Admin & Chef) وبوابة العملاء (Customer Portal) وكيفية تفعيل شاشة KDS التفاعلية وسلة المشتريات.

---

## طريقة تشغيل وتثبيت قاعدة البيانات (Database Installation Steps)

قم بتشغيل الملفات بالترتيب التالي داخل بيئة قاعدة البيانات الخاصة بك (عبر SQL Developer أو SQL*Plus أو APEX SQL Workshop):
1. قم بتشغيل سكريبت الصلاحيات والمستخدمين **`security.sql`** بمستخدم له صلاحيات إدارية (ADMIN أو SYS).
2. قم بتسجيل الدخول بمخطط المالك الرئيسي للمشروع (مثل `KITCHEN_OWNER`).
3. قم بتشغيل سكريبت الجداول **`schema.sql`**.
4. قم بتشغيل الحزم البرمجية بالترتيب:
   * **`pkg_inventory.sql`**
   * **`pkg_recipes.sql`**
   * **`pkg_orders.sql`**
5. قم بتشغيل التريجرات **`triggers.sql`**.
6. قم بتشغيل سكريبت البيانات التجريبية **`seed_data.sql`** لشحن الجداول بالبيانات للبدء بالفحص المباشر.

---

## ربط المشروع مع مستودع GitHub (How to link to GitHub)

المشروع تم تهيئته محلياً بمستودع Git. للربط مع حسابك على GitHub، اتبع الخطوات التالية:

1. افتح موقع **GitHub** وقم بإنشاء مستودع جديد (Repository) باسم `kitchen_system` (دون تهيئة README أو gitignore هناك).
2. افتح سطر الأوامر (Command Prompt / Terminal) في مسار هذا المجلد:
   `C:\Users\dev12\.gemini\antigravity\scratch\kitchen_system`
3. قم بتشغيل الأوامر التالية لربط المستودع المحلي بالمستودع البعيد ورفع الملفات:
   ```bash
   # إضافة رابط مستودع GitHub الخاص بك
   git remote add origin https://github.com/USERNAME/kitchen_system.git
   
   # تسمية الفرع الرئيسي بـ main
   git branch -M main
   
   # رفع الملفات
   git push -u origin main
   ```
   *(استبدل USERNAME باسم حسابك الفعلي على GitHub)*.
