# تصميم تطبيقات Oracle APEX لنظام إدارة المطبخ الداخلي
# Oracle APEX Applications Design Documentation

يوضح هذا المستند كيفية بناء وتصميم واجهات وتطبيقات **Oracle APEX** (الإصدار 23.x أو 24.x) والربط مع الصلاحيات والمستخدمين على مستوى قاعدة البيانات (Database-level Authentication & Roles).

---

## 1. تطبيق الإدارة والمطبخ (Admin & Kitchen Management Portal)
هذا التطبيق مخصص لموظفي المطبخ والإدارة، ويتم الدخول إليه بمستخدمي قاعدة البيانات الفعليين.

### أ) آلية التحقق من الهوية والصلاحيات (Authentication & Authorization)
* **نظام التحقق (Authentication Scheme):** يتم اختيار **Database Accounts** في APEX. عند تسجيل الدخول، يقوم APEX بالتحقق من اسم المستخدم وكلمة المرور مباشرة في قاعدة البيانات.
* **نظام الصلاحيات (Authorization Schemes):**
  1. **صلاحية المدير (IS_ADMIN):**
     * **النوع (Scheme Type):** PL/SQL Function Returning Boolean.
     * **الكود:**
       ```sql
       -- التحقق مما إذا كان المستخدم يملك دور المدير في قاعدة البيانات
       DECLARE
           v_has_role NUMBER;
       BEGIN
           SELECT COUNT(*)
           INTO v_has_role
           FROM user_role_privs
           WHERE granted_role = 'KITCHEN_ADMIN_ROLE';
           
           RETURN (v_has_role > 0);
       END;
       ```
  2. **صلاحية المطبخ (IS_CHEF):**
     * **النوع:** PL/SQL Function Returning Boolean.
     * **الكود:**
       ```sql
       -- التحقق مما إذا كان المستخدم يملك دور المطبخ أو دور المدير
       DECLARE
           v_has_role NUMBER;
       BEGIN
           SELECT COUNT(*)
           INTO v_has_role
           FROM user_role_privs
           WHERE granted_role IN ('KITCHEN_STAFF_ROLE', 'KITCHEN_ADMIN_ROLE');
           
           RETURN (v_has_role > 0);
       END;
       ```

### ب) الصفحات الرئيسية للتطبيق (App Pages)

#### 1. لوحة البيانات الرئيسية (Dashboard Page) - للمدراء فقط
* **مكونات الصفحة:**
  * **سلسلة مؤشرات أداء (Cards / Badge List):** إجمالي مبيعات اليوم، الوجبات النشطة، قيمة المخزون الحالي، الباتشات منتهية الصلاحية.
  * **رسم بياني (Chart - Jet Bar/Line):** المبيعات اليومية وتكلفة الإنتاج لمعرفة هامش الربح الإجمالي الفعلي.
  * **رسم بياني (Chart - Pie/Donut):** الوجبات الأكثر مبيعاً.
  * **استعلام تنبيهات الصلاحية (Classic Report):**
    ```sql
    SELECT name, expiry_date, remaining_qty, TRUNC(expiry_date) - TRUNC(SYSDATE) as days_left
    FROM inventory_batches b
    JOIN ingredients i ON b.ingredient_id = i.ingredient_id
    WHERE expiry_date <= TRUNC(SYSDATE) + 3 -- تنبيه خلال 3 أيام
      AND remaining_qty > 0;
    ```

#### 2. إدارة المخزون (Inventory Management) - للمدراء فقط
* **مكونات الصفحة:**
  * **شبكة تفاعلية (Interactive Grid):** لإدخال وتعديل المواد الخام (`ingredients`).
  * **شاشة إدخال فواتير المشتريات (Form & Interactive Grid Master-Detail):** لإدخال فواتير الشراء، ويقوم زر الحفظ باستدعاء الإجراء:
    ```sql
    pkg_inventory.add_purchase_receipt(
        p_ingredient_id => :P2_INGREDIENT_ID,
        p_qty           => :P2_QTY,
        p_purchase_uom  => :P2_UOM,
        p_unit_cost     => :P2_COST,
        p_expiry_date   => :P2_EXPIRY
    );
    ```

#### 3. مصمم الوصفات (Recipe & BOM Builder) - للمدراء فقط
* **مكونات الصفحة:**
  * **تقرير شجري أو Master-Detail:** لإدارة الوصفات والوجبات.
  * الجزء العلوي (Master): وجبات الطعام وسعر البيع.
  * الجزء السفلي (Detail): المكونات الخام والكميات المطلوبة لكل وجبة.
  * **حقل حساب التكلفة التلقائي:** يتم استخدام Dynamic Action عند تغيير المكونات لاستدعاء الدالة وحساب تكلفة الوجبة وهامش الربح فورياً:
    ```sql
    :P3_ACTUAL_COST := pkg_recipes.calculate_recipe_cost(:P3_RECIPE_ID);
    :P3_PROFIT_MARGIN := pkg_recipes.get_profit_margin(:P3_RECIPE_ID);
    ```

#### 4. شاشة عرض المطبخ التفاعلية (Kitchen Display System - KDS) - للإدارة والطهي
* **مكونات الصفحة:**
  * **منطقة بطاقات (Cards Region):** تعرض الطلبات التي حالتها `PENDING` أو `PREPARING` مع ترتيبها بالأقدم أولاً.
  * **الاستعلام المغذي للبطاقات:**
    ```sql
    SELECT order_id, 
           c.name as customer_name, 
           order_date, 
           status, 
           total_amount,
           -- كود CSS لتغيير لون البطاقة حسب الحالة والأهمية
           CASE status 
             WHEN 'PENDING' THEN 'u-color-danger-bg' 
             WHEN 'PREPARING' THEN 'u-color-warning-bg' 
           END as card_color
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE status IN ('PENDING', 'PREPARING')
    ORDER BY order_date ASC;
    ```
  * **التحديث التلقائي (Auto Refresh):** ضبط خاصية `Lazy Loading` و `Auto Refresh` للمنطقة كل 10 ثوانٍ لضمان ظهور الطلبات الجديدة دون تدخل.
  * **أزرار الأكشن داخل البطاقات (Card Actions):**
    * **زر "بدء التحضير" (يظهر للطلبات PENDING فقط):** يقوم بتنفيذ عملية بقاعدة البيانات (Execute Server-side Code):
      ```sql
      pkg_orders.update_order_status(:CARD_ORDER_ID, 'PREPARING');
      ```
      (هذه الخطوة ستقوم تلقائياً بخصم المخزون وحساب التكاليف عبر الـ Package).
    * **زر "جاهز للتسليم" (يظهر للطلبات PREPARING فقط):** يقوم بتنفيذ:
      ```sql
      pkg_orders.update_order_status(:CARD_ORDER_ID, 'READY');
      ```

---

## 2. بوابة طلبات العملاء (Customer Ordering Portal)
هذا التطبيق مخصص للجمهور، ويتم تصفحه بشكل عام أو بمصادقة حساب مخصص للتطبيق.

### أ) آلية الاتصال والأمان (Connection & Security)
* **مخطط التشغيل (Parsing Schema):** يتم ضبط التطبيق ليعمل بمخطط `KITCHEN_CUSTOMER_USER`. هذا المخطط لا يملك أي صلاحيات تعديل أو قراءة مباشرة على الجداول الرئيسية، بل يملك صلاحية القراءة فقط على الـ Views الخدمية وصلاحية التنفيذ للـ Packages المطلوبة للطلب.
* **نظام التحقق (Authentication Scheme):** Custom Authentication Scheme يتم ربطه بجدول `customers` للتحقق من رقم الهاتف وكلمة المرور الخاصة بالعميل.

### ب) الصفحات الرئيسية للتطبيق (App Pages)

#### 1. صفحة المنيو (Faceted Menu Page)
* **التصميم الجمالي:** استخدام مكون الـ Cards مع تفعيل خاصية الصور وتصفيتها حسب الفئة.
* **الاستعلام المغذي:** الاستعلام من العرض المخصص للعميل:
  ```sql
  SELECT recipe_id, name, description, selling_price, image_url
  FROM v_active_menu;
  ```
* **سلة التسوق الذكية (APEX Collection):** عند الضغط على "إضافة للسلة"، يتم استدعاء Dynamic Action لإضافة الصنف إلى مجموعة APEX مؤقتة (`APEX_COLLECTION`) باسم `CART`.

#### 2. صفحة إتمام الطلب (Checkout Page)
* **مكونات الصفحة:**
  * تقرير يستعرض محتويات السلة من الـ Collection.
  * نموذج إدخال بيانات العميل (الاسم، الهاتف، العنوان).
  * خيارات الدفع (كاش COD / دفع إلكتروني إرفاق إيصال انستا باي).
* **معالجة تأكيد الطلب (Process on Submit):**
  ```sql
  DECLARE
      v_cust_id  NUMBER;
      v_order_id NUMBER;
      v_item_id  NUMBER;
  BEGIN
      -- 1. التأكد من وجود العميل أو إنشائه
      BEGIN
          SELECT customer_id INTO v_cust_id 
          FROM customers WHERE phone = :P20_PHONE;
          
          -- تحديث العنوان إذا تغير
          UPDATE customers SET address = :P20_ADDRESS WHERE customer_id = v_cust_id;
      EXCEPTION
          WHEN NO_DATA_FOUND THEN
              INSERT INTO customers (name, phone, address)
              VALUES (:P20_NAME, :P20_PHONE, :P20_ADDRESS)
              RETURNING customer_id INTO v_cust_id;
      END;

      -- 2. إنشاء رأس الطلب
      pkg_orders.create_order(
          p_customer_id       => v_cust_id,
          p_order_type        => 'DELIVERY',
          p_payment_method    => :P20_PAYMENT_METHOD,
          p_payment_reference => :P20_PAYMENT_REF,
          o_order_id          => v_order_id
      );

      -- 3. ترحيل الأصناف من سلة التسوق (Collection) إلى جدول الأصناف الفعلي
      FOR r IN (
          SELECT n001 as recipe_id, n002 as quantity
          FROM apex_collections
          WHERE collection_name = 'CART'
      ) LOOP
          pkg_orders.add_order_item(
              p_order_id      => v_order_id,
              p_recipe_id     => r.recipe_id,
              p_quantity      => r.quantity,
              o_order_item_id => v_item_id
          );
      END LOOP;

      -- 4. إفراغ السلة وتوجيه العميل لصفحة التتبع
      apex_collection.truncate_collection('CART');
      :P20_NEW_ORDER_ID := v_order_id;
  END;
  ```

#### 3. صفحة تتبع الطلب (Order Tracking Page)
* **مكونات الصفحة:**
  * **الخط الزمني (Timeline Component):** يستعرض المراحل الزمنية لتغير حالة الطلب من سياق الجدول `order_status_history`.
  * **الاستعلام المغذي للخط الزمني:**
    ```sql
    SELECT status, changed_at,
           CASE status
             WHEN 'PENDING' THEN 'تم استلام طلبك وبانتظار التأكيد'
             WHEN 'PREPARING' THEN 'المطبخ يقوم بتحضير وجبتك الآن'
             WHEN 'READY' THEN 'الوجبة جاهزة وتم تسليمها لمندوب التوصيل'
             WHEN 'DELIVERED' THEN 'تم توصيل الطلب بنجاح، بالهناء والشفاء!'
           END as status_desc
    FROM order_status_history
    WHERE order_id = :P30_ORDER_ID
    ORDER BY changed_at DESC;
    ```
