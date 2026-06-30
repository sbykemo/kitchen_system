# دليل تثبيت قاعدة البيانات وبناء تطبيقات Oracle APEX خطوة بخطوة
# Oracle APEX Deployment & Application Building Guide

يرشدك هذا الدليل التفصيلي إلى كيفية رفع سكريبتات قاعدة البيانات البرمجية وتشغيلها، ثم كيفية إعداد وتصميم تطبيقي الإدارة وبوابة العملاء داخل بيئة **Oracle APEX** (سواء على سحابة OCI أو محلياً) خطوة بخطوة عبر المتصفح.

---

## 📅 الجزء الأول: تشغيل سكريبتات قاعدة البيانات (Database Deployment)

سنستخدم أداة **SQL Workshop** المدمجة في Oracle APEX لرفع وتشغيل الملفات.

### الخطوة 1: الدخول إلى SQL Workshop
1. قم بتسجيل الدخول إلى مساحة عمل أوراكل إيبكس الخاصة بك (**APEX Workspace**).
2. من الشاشة الرئيسية، اضغط على تبويب **SQL Workshop** في القائمة العلوية.
3. اختر **SQL Scripts**.

### الخطوة 2: رفع وتشغيل السكريبتات بالترتيب
لكل ملف من الملفات الموجودة في مجلد `database/` بمشروعك، اتبع الآتي:
1. داخل صفحة **SQL Scripts**، اضغط على زر **Upload** (في أعلى اليمين).
2. اضغط على **Choose File** وحدد الملف المطلوب.
3. اكتب اسماً للملف (اختياري) ثم اضغط **Upload**.
4. بعد رفع الملف، سيظهر في القائمة. اضغط على أيقونة **Run** المقابلة له.
5. في شاشة التأكيد، اضغط على **Run Now**.
6. بعد اكتمال التشغيل، يمكنك مراجعة النتائج والـ Log عبر الضغط على أيقونة **View Results** للتأكد من عدم وجود أخطاء.

> [!IMPORTANT]
> **ترتيب التشغيل الإلزامي للملفات:**
> 1. [security.sql](file:///C:/Users/dev12/.gemini/antigravity/scratch/kitchen_system/database/security.sql) *(ملاحظة: إذا كنت تستخدم بيئة APEX سحابية مشتركة ولا تملك صلاحيات ADMIN كاملة لإنشاء مستخدمين DB، يمكنك تخطي هذا الملف والبدء بالخطوة التالية مباشرة).*
> 2. [schema.sql](file:///C:/Users/dev12/.gemini/antigravity/scratch/kitchen_system/database/schema.sql) - لإنشاء الجداول والقيود والعروض.
> 3. [pkg_inventory.sql](file:///C:/Users/dev12/.gemini/antigravity/scratch/kitchen_system/database/pkg_inventory.sql) - حزمة المخزون.
> 4. [pkg_recipes.sql](file:///C:/Users/dev12/.gemini/antigravity/scratch/kitchen_system/database/pkg_recipes.sql) - حزمة تسعير وتكاليف الوصفات.
> 5. [pkg_orders.sql](file:///C:/Users/dev12/.gemini/antigravity/scratch/kitchen_system/database/pkg_orders.sql) - حزمة إدارة الطلبات.
> 6. [triggers.sql](file:///C:/Users/dev12/.gemini/antigravity/scratch/kitchen_system/database/triggers.sql) - التريجرات الحمائية وتدقيق الصلاحية.
> 7. [seed_data.sql](file:///C:/Users/dev12/.gemini/antigravity/scratch/kitchen_system/database/seed_data.sql) - شحن قاعدة البيانات بالبيانات التجريبية الأولية.

---

## 💻 الجزء الثاني: بناء تطبيق الإدارة والمطبخ (Admin & Kitchen App)

يتم بناء هذا التطبيق لإدارة المخزون، الوصفات، ومتابعة الطلبات داخل المطبخ عبر شاشة KDS التفاعلية.

### الخطوة 1: إنشاء التطبيق الأساسي
1. اذهب إلى **App Builder** واضغط على زر **Create** ثم اختر **New Application**.
2. اسم التطبيق: `إدارة المطبخ الداخلي - الإدارة والطهي`.
3. تحت قسم **Security**:
   * اختر **Authentication** -> اضغط **Edit** وحدد **Database Accounts** (بحيث يتم تسجيل الدخول بمستخدمي قاعدة البيانات الذين تم إنشاؤهم في `security.sql`).
4. اضغط على **Create Application**.

### الخطوة 2: إعداد صلاحيات المستخدمين (Authorization Schemes)
1. داخل صفحة التطبيق في App Builder، اذهب إلى **Shared Components**.
2. تحت قسم *Security*، اضغط على **Authorization Schemes**.
3. اضغط على **Create** -> اختر **Scratch** ثم **Next**.
4. **الصلاحية الأولى (المدير):**
   * **Name:** `IS_ADMIN`
   * **Scheme Type:** PL/SQL Function Returning Boolean.
   * **PL/SQL Function Body:**
     ```sql
     DECLARE
         v_has_role NUMBER;
     BEGIN
         SELECT COUNT(*) INTO v_has_role
         FROM user_role_privs
         WHERE granted_role = 'KITCHEN_ADMIN_ROLE';
         RETURN (v_has_role > 0);
     END;
     ```
   * **Error Message:** `عذراً، هذا القسم مخصص لمدير النظام فقط.`
5. **الصلاحية الثانية (الطاهي/المطبخ):**
   * **Name:** `IS_CHEF`
   * **Scheme Type:** PL/SQL Function Returning Boolean.
   * **PL/SQL Function Body:**
     ```sql
     DECLARE
         v_has_role NUMBER;
     BEGIN
         SELECT COUNT(*) INTO v_has_role
         FROM user_role_privs
         WHERE granted_role IN ('KITCHEN_STAFF_ROLE', 'KITCHEN_ADMIN_ROLE');
         RETURN (v_has_role > 0);
     END;
     ```
   * **Error Message:** `عذراً، يجب أن تملك صلاحيات المطبخ لتصفح هذه الشاشة.`

### الخطوة 3: بناء الصفحات والشاشات

#### 1. لوحة البيانات (Dashboard) - الصفحة 1
* أنشئ صفحة جديدة من نوع **Blank Page**.
* أضف منطقة من نوع **Cards** لعرض المؤشرات المالية:
  * **Title:** `المؤشرات السريعة`
  * **SQL Query:**
    ```sql
    SELECT 'إجمالي مبيعات اليوم' as label, TO_CHAR(NVL(SUM(total_amount), 0), '999,990.00') || ' ج.م' as value FROM orders WHERE TRUNC(order_date) = TRUNC(SYSDATE)
    UNION ALL
    SELECT 'الباتشات منتهية الصلاحية' as label, TO_CHAR(COUNT(*)) FROM inventory_batches WHERE expiry_date <= TRUNC(SYSDATE) AND remaining_qty > 0
    ```
* أضف منطقة من نوع **Chart** (نوع Bar Chart) للمبيعات اليومية وتكلفتها:
  * **SQL Query:**
    ```sql
    SELECT TRUNC(order_date) as order_day, 
           SUM(total_amount) as total_sales,
           SUM((SELECT SUM(actual_cost) FROM order_items oi WHERE oi.order_id = o.order_id)) as total_cost
    FROM orders o
    GROUP BY TRUNC(order_date)
    ORDER BY order_day;
    ```

#### 2. شبكة إدارة المكونات والمخزون - الصفحة 2
* أنشئ صفحة جديدة من نوع **Interactive Grid**.
* **Title:** `إدارة المواد الخام والمخزون`
* **SQL Query:**
  ```sql
  SELECT ingredient_id, name, base_uom, min_stock_level, current_cost FROM ingredients;
  ```
* قم بتمكين خاصية التعديل والإضافة والإلغاء (**Enable Editing**) في إعدادات الـ Grid، واربطها بجدول `ingredients`.
* أضف في أسفل الصفحة جدولاً تفاعلياً آخر (**Interactive Grid**) يعرض دفعات المخزون وتواريخ صلاحيتها:
  ```sql
  SELECT batch_id, ingredient_id, purchase_date, expiry_date, initial_qty, remaining_qty, unit_cost, is_active FROM inventory_batches;
  ```

#### 3. مصمم الوصفات (Recipe Builder) - الصفحة 3
* أنشئ صفحة جديدة من نوع **Master-Detail** (تتكون من جدولين مدمجين).
* **Master (الوجبات الرئيسية):** جدول `recipes`.
* **Detail (مكونات الوجبة):** جدول `recipe_ingredients`.
* قم بتأمين الصفحة بربطها بـ Authorization Scheme مساوٍ لـ `IS_ADMIN`.

#### 4. شاشة عرض المطبخ (Kitchen Display System - KDS) - الصفحة 4
* أنشئ صفحة جديدة من نوع **Cards**.
* **Title:** `شاشة طلبات المطبخ النشطة`
* **SQL Query:**
  ```sql
  SELECT order_id, 
         (SELECT name FROM customers c WHERE c.customer_id = o.customer_id) as customer_name,
         order_date, 
         status, 
         total_amount
  FROM orders o
  WHERE status IN ('PENDING', 'PREPARING')
  ORDER BY order_date ASC;
  ```
* اذهب إلى إعدادات منطقة الـ Cards:
  * اضغط على **Attributes**.
  * اضغط على **Appearance** وضبط الـ CSS Classes لتبدو البطاقات ملونة وجذابة.
  * اضغط على خصائص المنطقة الرئيسية واضبط **Auto Refresh** ليكون **10** (لتحديث الشاشة تلقائياً كل 10 ثوانٍ بالطلبات الجديدة).
* **إضافة العمليات (Card Actions):**
  1. أنشئ زر أكشن داخل البطاقة باسم `بدء التحضير` (Start Preparing).
     * اجعل شرط ظهوره (**Server-side Condition**): الـ Status يساوي `PENDING`.
     * نوع الأكشن: **Redirect to Page in this Application** أو **Execute Server-side Code**.
     * الـ PL/SQL Code المنفذ:
       ```sql
       pkg_orders.update_order_status(:CARD_ORDER_ID, 'PREPARING');
       ```
  2. أنشئ زر أكشن ثانٍ داخل البطاقة باسم `جاهز للتسليم` (Ready).
     * اجعل شرط ظهوره: الـ Status يساوي `PREPARING`.
     * الـ PL/SQL Code المنفذ:
       ```sql
       pkg_orders.update_order_status(:CARD_ORDER_ID, 'READY');
       ```

---

## 📱 الجزء الثالث: بناء بوابة طلبات العملاء (Customer Portal)

هذا التطبيق مصمم ليكون متوافقاً مع شاشات الجوال بالكامل، ليتصفح العملاء المنيو ويطلبوا طعامهم.

### الخطوة 1: إنشاء تطبيق العميل
1. اضغط **Create** في App Builder واختر **New Application**.
2. اسم التطبيق: `اطلب الآن - مطبخنا الداخلي`.
3. تحت قسم **Security**:
   * اختر **Authentication** -> اضغط **Edit** وحدد **Custom** (حيث سنستخدم جدول العملاء الخاص بنا للتحقق من هواتفهم).
4. اضغط على **Create Application**.
5. اذهب إلى **Shared Components** -> **Application Definition** -> واضبط مخطط التشغيل (**Parsing Schema**) ليكون `KITCHEN_CUSTOMER_USER` لحماية البيانات.

### الخطوة 2: بناء الشاشات

#### 1. صفحة استعراض قائمة الطعام (Menu Cards) - الصفحة 1
* أنشئ صفحة جديدة من نوع **Cards**.
* **SQL Query:** الاستعلام من العرض العام المخصص للعملاء:
  ```sql
  SELECT recipe_id, name, description, selling_price, image_url FROM v_active_menu;
  ```
* في إعدادات الـ Card، اختر عرض الصورة، وضع زر أكشن باسم `إضافة إلى السلة`.
* **برمجة زر الإضافة (Dynamic Action):**
  * عند الضغط على الزر، قم بتنفيذ كود PL/SQL لإضافة العنصر إلى سلة تسوق مؤقتة (**APEX Collection**):
    ```sql
    IF NOT apex_collection.collection_exists('CART') THEN
        apex_collection.create_collection('CART');
    END IF;
    
    apex_collection.add_member(
        p_collection_name => 'CART',
        p_n001            => :CARD_RECIPE_ID, -- رقم الوجبة
        p_n002            => 1                -- الكمية الافتراضية
    );
    ```

#### 2. صفحة سلة التسوق وإتمام الطلب (Checkout) - الصفحة 2
* أنشئ صفحة جديدة تحتوي على:
  1. تقرير كلاسيكي (**Classic Report**) يستعرض محتويات السلة:
     ```sql
     SELECT c.seq_id,
            r.name as recipe_name,
            c.n002 as quantity,
            r.selling_price as unit_price,
            (c.n002 * r.selling_price) as sub_total
     FROM apex_collections c
     JOIN recipes r ON c.n001 = r.recipe_id
     WHERE c.collection_name = 'CART';
     ```
  2. نموذج إدخال بيانات التوصيل والدفع (اسم العميل، رقم الهاتف، العنوان الفعلي، طريقة الدفع [نقداً / إلكترونياً]).
* عند الضغط على زر **تأكيد الطلب وحفظه**:
  * قم بإنشاء عملية (**Page Process**) لتنفيذ الكود المتكامل المذكور في ملف `APEX_DESIGN.md` (قسم Checkout Page)، والذي يقوم بالتحقق من العميل، إدراج رأس الطلب، ونقل البنود من الـ Collection إلى جدول `order_items` وتحديث الإجمالي، ثم توجيه العميل تلقائياً لصفحة التتبع مع إفراغ السلة.

#### 3. صفحة تتبع الطلب (Order Tracking) - الصفحة 3
* أنشئ صفحة جديدة من نوع **Blank Page**.
* أضف منطقة من نوع **Classic Report** باستخدام قالب **Timeline** المدمج في APEX.
* **SQL Query:**
  ```sql
  SELECT status as title,
         changed_at as event_date,
         CASE status
           WHEN 'PENDING' THEN 'تم استلام طلبك وبانتظار التأكيد من الإدارة'
           WHEN 'PREPARING' THEN 'يقوم المطبخ حالياً بتحضير وجبتك الساخنة'
           WHEN 'READY' THEN 'الوجبة جاهزة ولذيذة، وهي الآن مع مندوب التوصيل'
           WHEN 'DELIVERED' THEN 'تم تسليم الطلب بنجاح! شكراً لتعاملك معنا'
         END as description,
         -- كود أيقونة جذاب حسب الحالة
         CASE status
           WHEN 'PENDING' THEN 'fa-clock-o'
           WHEN 'PREPARING' THEN 'fa-cutlery'
           WHEN 'READY' THEN 'fa-truck'
           WHEN 'DELIVERED' THEN 'fa-check-circle'
         END as icon
  FROM order_status_history
  WHERE order_id = :P3_ORDER_ID
  ORDER BY changed_at DESC;
  ```
* اضغط على خصائص التقرير، واضبط القالب (**Template**) ليكون **Timeline** ليعرض حالات الطلب التاريخية بشكل خط زمني متتابع وممتاز بصرياً للعميل.

---

## 🛠️ الجزء الرابع: تشغيل ومحاكاة دورة تشغيل كاملة (Testing the Flow)

بعد تثبيت قاعدة البيانات وبناء الشاشات في APEX:
1. اذهب لتطبيق الإدارة، وافتح صفحة **Inventory** وأضف كميات مواد خام جديدة بأسعار شراء وتواريخ صلاحية مختلفة (مثلاً: لحم مفروم، خبز).
2. افتح صفحة **Recipe Builder** واصنع وجبة جديدة (مثال: برجر كلاسيك) واربطها بالمواد الخام من المخزون مع تحديد الكميات اللازمة. ستلاحظ أن النظام يحسب التكلفة تلقائياً.
3. افتح تطبيق العميل، وتصفح المنيو، ثم أضف البرجر للسلة وأتمم الطلب مع إدخال رقم هاتفك وعنوانك.
4. ارجع لشاشة المطبخ (KDS) في تطبيق الإدارة، ستلاحظ فوراً ظهور طلب العميل الجديد في حالة **PENDING**.
5. اضغط على زر **بدء التحضير**؛ سيقوم النظام فوراً بفحص كميات المواد الخام في المخزون، وخصم الكميات بدقة بنظام FIFO (صلاحية أقرب)، وحساب الأرباح الفعلية للطلب وتخزينها، وتتحول حالة الطلب إلى **PREPARING**.
6. عند نضوج الطعام، اضغط على زر **جاهز للتسليم** لتتحول الحالة إلى **READY**.
7. عند تسليم الطلب للعميل، تتحول الحالة لـ **DELIVERED**.
8. اذهب للوحة التحكم (Dashboard) لمشاهدة إحصائيات المبيعات، التكاليف، والأرباح الحقيقية التي تم تحقيقها من هذه الدورة!
