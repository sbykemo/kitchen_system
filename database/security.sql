-- =============================================================================
-- نظام إدارة المطبخ الداخلي - سكريبت الصلاحيات والمستخدمين على مستوى قاعدة البيانات
-- Indoor Kitchen Management System - DB Security Roles & Users Script
-- =============================================================================
-- هذا السكريبت يتم تشغيله بواسطة مستخدم له صلاحيات إدارية (مثل SYS أو ADMIN في Autonomous DB)
-- لتهيئة الأدوار والمستخدمين ومنح الصلاحيات اللازمة.

-- 1. إنشاء الأدوار (Roles)
PROMPT Creating Database Roles...

CREATE ROLE KITCHEN_ADMIN_ROLE;
CREATE ROLE KITCHEN_STAFF_ROLE;
CREATE ROLE KITCHEN_CUSTOMER_ROLE;

-- 2. إنشاء مخطط مالك الجداول والأكواد (Schema Owner)
-- ملاحظة: في بيئة APEX السحابية (OCI)، يكون المخطط منشأ بالفعل ويتم ربطه بمساحة العمل.
-- سنفترض هنا أن اسم المخطط المالك للمشروع هو KITCHEN_OWNER.
-- CREATE USER KITCHEN_OWNER IDENTIFIED BY "KitchenOwnerPassword2026#" DEFAULT TABLESPACE USERS TEMPORARY TABLESPACE TEMP;
-- ALTER USER KITCHEN_OWNER QUOTA UNLIMITED ON USERS;
-- GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE PROCEDURE, CREATE TRIGGER, CREATE SEQUENCE TO KITCHEN_OWNER;

-- 3. إنشاء مستخدم العملاء العام (Public Customer User)
-- هذا المستخدم مخصص لبوابة العملاء للتصفح وإدخال الطلبات دون امتلاك حسابات DB متعددة للجمهور
PROMPT Creating Public Customer DB User...
CREATE USER KITCHEN_CUSTOMER_USER IDENTIFIED BY "CustUserPass2026#$" 
DEFAULT TABLESPACE USERS 
TEMPORARY TABLESPACE TEMP;

GRANT CREATE SESSION TO KITCHEN_CUSTOMER_USER;
GRANT KITCHEN_CUSTOMER_ROLE TO KITCHEN_CUSTOMER_USER;
ALTER USER KITCHEN_CUSTOMER_USER DEFAULT ROLE KITCHEN_CUSTOMER_ROLE;

-- 4. إنشاء مستخدمين نموذجيين للمطبخ والإدارة (Sample Staff & Admin Users)
-- هؤلاء يمثلون الموظفين الفعليين الذين سيسجلون الدخول لتطبيق الإدارة والمطبخ (Admin & Chef)
PROMPT Creating Sample DB Users for Staff and Admins...

-- مدير النظام (Admin)
CREATE USER kitchen_admin_demo IDENTIFIED BY "AdminDemoPass2026#"
DEFAULT TABLESPACE USERS TEMPORARY TABLESPACE TEMP;
GRANT CREATE SESSION TO kitchen_admin_demo;
GRANT KITCHEN_ADMIN_ROLE TO kitchen_admin_demo;
ALTER USER kitchen_admin_demo DEFAULT ROLE KITCHEN_ADMIN_ROLE;

-- الطاهي / موظف المطبخ (Chef)
CREATE USER kitchen_chef_demo IDENTIFIED BY "ChefDemoPass2026#"
DEFAULT TABLESPACE USERS TEMPORARY TABLESPACE TEMP;
GRANT CREATE SESSION TO kitchen_chef_demo;
GRANT KITCHEN_STAFF_ROLE TO kitchen_chef_demo;
ALTER USER kitchen_chef_demo DEFAULT ROLE KITCHEN_STAFF_ROLE;

-- 5. تعليمات منح الصلاحيات للأدوار (Grants from KITCHEN_OWNER to Roles)
-- [تنبيه هام]: هذه الأوامر يجب تشغيلها بواسطة المخطط المالك (KITCHEN_OWNER) بعد إنشاء الجداول والـ Packages.
-- تم إدراجها هنا للتوثيق وسيتم وضعها ضمن سكريبتات الإنشاء التفصيلية.

/*
-- تشغيل بواسطة KITCHEN_OWNER:

-- صلاحيات دور الإدارة (KITCHEN_ADMIN_ROLE): كامل الصلاحيات على الجداول والـ Packages
GRANT SELECT, INSERT, UPDATE, DELETE ON KITCHEN_OWNER.ingredients TO KITCHEN_ADMIN_ROLE;
GRANT SELECT, INSERT, UPDATE, DELETE ON KITCHEN_OWNER.uom_conversions TO KITCHEN_ADMIN_ROLE;
GRANT SELECT, INSERT, UPDATE, DELETE ON KITCHEN_OWNER.inventory_batches TO KITCHEN_ADMIN_ROLE;
GRANT SELECT, INSERT, UPDATE, DELETE ON KITCHEN_OWNER.recipes TO KITCHEN_ADMIN_ROLE;
GRANT SELECT, INSERT, UPDATE, DELETE ON KITCHEN_OWNER.sub_recipes TO KITCHEN_ADMIN_ROLE;
GRANT SELECT, INSERT, UPDATE, DELETE ON KITCHEN_OWNER.recipe_ingredients TO KITCHEN_ADMIN_ROLE;
GRANT SELECT, INSERT, UPDATE, DELETE ON KITCHEN_OWNER.customers TO KITCHEN_ADMIN_ROLE;
GRANT SELECT, INSERT, UPDATE, DELETE ON KITCHEN_OWNER.orders TO KITCHEN_ADMIN_ROLE;
GRANT SELECT, INSERT, UPDATE, DELETE ON KITCHEN_OWNER.order_items TO KITCHEN_ADMIN_ROLE;
GRANT SELECT, INSERT, UPDATE, DELETE ON KITCHEN_OWNER.order_customizations TO KITCHEN_ADMIN_ROLE;
GRANT SELECT, INSERT, UPDATE, DELETE ON KITCHEN_OWNER.delivery_partners TO KITCHEN_ADMIN_ROLE;
GRANT SELECT ON KITCHEN_OWNER.order_status_history TO KITCHEN_ADMIN_ROLE;

GRANT EXECUTE ON KITCHEN_OWNER.pkg_inventory TO KITCHEN_ADMIN_ROLE;
GRANT EXECUTE ON KITCHEN_OWNER.pkg_recipes TO KITCHEN_ADMIN_ROLE;
GRANT EXECUTE ON KITCHEN_OWNER.pkg_orders TO KITCHEN_ADMIN_ROLE;

-- صلاحيات دور المطبخ (KITCHEN_STAFF_ROLE): صلاحيات قراءة المكونات والوصفات، وإدارة حالات الطلب (KDS)
GRANT SELECT ON KITCHEN_OWNER.ingredients TO KITCHEN_STAFF_ROLE;
GRANT SELECT ON KITCHEN_OWNER.inventory_batches TO KITCHEN_STAFF_ROLE;
GRANT SELECT ON KITCHEN_OWNER.recipes TO KITCHEN_STAFF_ROLE;
GRANT SELECT ON KITCHEN_OWNER.recipe_ingredients TO KITCHEN_STAFF_ROLE;
GRANT SELECT ON KITCHEN_OWNER.orders TO KITCHEN_STAFF_ROLE;
GRANT SELECT ON KITCHEN_OWNER.order_items TO KITCHEN_STAFF_ROLE;
GRANT SELECT ON KITCHEN_OWNER.order_customizations TO KITCHEN_STAFF_ROLE;
GRANT SELECT ON KITCHEN_OWNER.order_status_history TO KITCHEN_STAFF_ROLE;

-- الطاهي يمكنه فقط تحديث حالة الطلب من خلال الـ Package المخصصة لذلك وليس التعديل المباشر
GRANT EXECUTE ON KITCHEN_OWNER.pkg_orders TO KITCHEN_STAFF_ROLE;

-- صلاحيات دور العميل العام (KITCHEN_CUSTOMER_ROLE): صلاحيات القراءة على المنيو، وإنشاء الطلبات
-- سنقوم بإنشاء Views مخصصة للعملاء لحماية الجداول الأصلية وتوفير خصوصية البيانات
GRANT SELECT ON KITCHEN_OWNER.v_active_menu TO KITCHEN_CUSTOMER_ROLE;
GRANT SELECT ON KITCHEN_OWNER.v_menu_customizations TO KITCHEN_CUSTOMER_ROLE;
GRANT SELECT, INSERT, UPDATE ON KITCHEN_OWNER.customers TO KITCHEN_CUSTOMER_ROLE;

-- صلاحية تشغيل حزمة الطلبات لإنشاء الطلب وتتبعه
GRANT EXECUTE ON KITCHEN_OWNER.pkg_orders TO KITCHEN_CUSTOMER_ROLE;
*/

PROMPT Security Roles & Users Script Created Successfully.
