-- =============================================================================
-- نظام إدارة المطبخ الداخلي - سكريبت البيانات التجريبية الأولية
-- Indoor Kitchen Management System - Seed Data Script
-- =============================================================================

PROMPT Inserting UOM Conversions...
INSERT INTO uom_conversions (from_uom, to_uom, conversion_factor) VALUES ('KG', 'G', 1000);
INSERT INTO uom_conversions (from_uom, to_uom, conversion_factor) VALUES ('L', 'ML', 1000);
INSERT INTO uom_conversions (from_uom, to_uom, conversion_factor) VALUES ('BOX', 'PCS', 12); -- الصندوق به 12 قطعة

PROMPT Inserting Raw Ingredients...
-- إدراج المواد الخام مع تحديد وحدات القياس الأساسية والحد الأدنى للطلب
INSERT INTO ingredients (name, base_uom, min_stock_level, current_cost) VALUES ('لحم بقري مفروم', 'G', 5000, 0.25); -- الكيلو بـ 250 جنيه (الجرام بـ 0.25)
INSERT INTO ingredients (name, base_uom, min_stock_level, current_cost) VALUES ('خبز برجر', 'PCS', 50, 5.00);      -- القطعة بـ 5 جنيه
INSERT INTO ingredients (name, base_uom, min_stock_level, current_cost) VALUES ('شرائح جبنة شيدر', 'PCS', 100, 8.00); -- القطعة بـ 8 جنيه
INSERT INTO ingredients (name, base_uom, min_stock_level, current_cost) VALUES ('بصل', 'G', 3000, 0.02);           -- الكيلو بـ 20 جنيه (الجرام بـ 0.02)
INSERT INTO ingredients (name, base_uom, min_stock_level, current_cost) VALUES ('طماطم طازجة', 'G', 4000, 0.015);  -- الكيلو بـ 15 جنيه (الجرام بـ 0.015)
INSERT INTO ingredients (name, base_uom, min_stock_level, current_cost) VALUES ('ثوم', 'G', 500, 0.05);             -- الكيلو بـ 50 جنيه (الجرام بـ 0.05)
INSERT INTO ingredients (name, base_uom, min_stock_level, current_cost) VALUES ('زيت زيتون', 'ML', 2000, 0.15);    -- اللتر بـ 150 جنيه (الملي بـ 0.15)
INSERT INTO ingredients (name, base_uom, min_stock_level, current_cost) VALUES ('مكرونة بنة', 'G', 6000, 0.04);     -- الكيلو بـ 40 جنيه (الجرام بـ 0.04)

PROMPT Inserting Initial Inventory Batches (Purchases)...
-- سنستخدم حزمة المخزون لضمان إجراء الحسابات وتحديث أسعار التكلفة تلقائياً
DECLARE
    v_beef_id NUMBER;
    v_bun_id NUMBER;
    v_cheese_id NUMBER;
    v_onion_id NUMBER;
    v_tomato_id NUMBER;
    v_garlic_id NUMBER;
    v_oil_id NUMBER;
    v_pasta_id NUMBER;
BEGIN
    SELECT ingredient_id INTO v_beef_id FROM ingredients WHERE name = 'لحم بقري مفروم';
    SELECT ingredient_id INTO v_bun_id FROM ingredients WHERE name = 'خبز برجر';
    SELECT ingredient_id INTO v_cheese_id FROM ingredients WHERE name = 'شرائح جبنة شيدر';
    SELECT ingredient_id INTO v_onion_id FROM ingredients WHERE name = 'بصل';
    SELECT ingredient_id INTO v_tomato_id FROM ingredients WHERE name = 'طماطم طازجة';
    SELECT ingredient_id INTO v_garlic_id FROM ingredients WHERE name = 'ثوم';
    SELECT ingredient_id INTO v_oil_id FROM ingredients WHERE name = 'زيت زيتون';
    SELECT ingredient_id INTO v_pasta_id FROM ingredients WHERE name = 'مكرونة بنة';

    -- إضافة مشتريات (شراء كميات كافية للتشغيل)
    pkg_inventory.add_purchase_receipt(v_beef_id, 10, 'KG', 2600.00, SYSDATE + 7); -- 10 كيلو بـ 2600 جنيه (260 جنيه للكيلو)
    pkg_inventory.add_purchase_receipt(v_bun_id, 5, 'BOX', 66.00, SYSDATE + 4);      -- 5 صناديق (60 قطعة) بـ 66 جنيه
    pkg_inventory.add_purchase_receipt(v_cheese_id, 10, 'BOX', 96.00, SYSDATE + 30); -- 10 صناديق (120 قطعة) بـ 96 جنيه
    pkg_inventory.add_purchase_receipt(v_onion_id, 15, 'KG', 300.00, SYSDATE + 15);   -- 15 كيلو بـ 300 جنيه
    pkg_inventory.add_purchase_receipt(v_tomato_id, 20, 'KG', 400.00, SYSDATE + 5);   -- 20 كيلو بـ 400 جنيه
    pkg_inventory.add_purchase_receipt(v_garlic_id, 2, 'KG', 120.00, SYSDATE + 45);   -- 2 كيلو بـ 120 جنيه
    pkg_inventory.add_purchase_receipt(v_oil_id, 5, 'L', 800.00, SYSDATE + 180);      -- 5 لتر بـ 800 جنيه
    pkg_inventory.add_purchase_receipt(v_pasta_id, 12, 'KG', 540.00, SYSDATE + 120);  -- 12 كيلو بـ 540 جنيه
END;
/

PROMPT Inserting Recipes & Sub-Recipes...
-- 1. الوصفات الفرعية (Sub-recipes)
INSERT INTO recipes (name, description, selling_price, is_sub_recipe) 
VALUES ('قرص برجر مجهز', 'قرص لحم برجر 150 جرام متبل وجاهز للشوي', 0.00, 'Y');

INSERT INTO recipes (name, description, selling_price, is_sub_recipe) 
VALUES ('صوص الطماطم البيتي', 'صوص طماطم بالثوم وزيت الزيتون للمكرونة (يكفي وجبة واحدة)', 0.00, 'Y');

-- 2. وجبات المنيو النهائية للبيع للمستهلك (Menu Items)
INSERT INTO recipes (name, description, selling_price, is_sub_recipe) 
VALUES ('تشيز برجر كلاسيك', 'ساندوتش تشيز برجر بالجبنة الشيدر السائحة والبصل المقرمش', 140.00, 'N');

INSERT INTO recipes (name, description, selling_price, is_sub_recipe) 
VALUES ('مكرونة بالصوص الأحمر', 'مكرونة بنة بصوص الطماطم البيتي وزيت الزيتون البكر', 85.00, 'N');

PROMPT Building Recipe Bom (Recipe Ingredients)...
DECLARE
    v_beef_id NUMBER;
    v_bun_id NUMBER;
    v_cheese_id NUMBER;
    v_onion_id NUMBER;
    v_tomato_id NUMBER;
    v_garlic_id NUMBER;
    v_oil_id NUMBER;
    v_pasta_id NUMBER;

    v_sub_patty_id NUMBER;
    v_sub_sauce_id NUMBER;
    v_menu_burger_id NUMBER;
    v_menu_pasta_id NUMBER;
BEGIN
    -- جلب معرفات المكونات الخام
    SELECT ingredient_id INTO v_beef_id FROM ingredients WHERE name = 'لحم بقري مفروم';
    SELECT ingredient_id INTO v_bun_id FROM ingredients WHERE name = 'خبز برجر';
    SELECT ingredient_id INTO v_cheese_id FROM ingredients WHERE name = 'شرائح جبنة شيدر';
    SELECT ingredient_id INTO v_onion_id FROM ingredients WHERE name = 'بصل';
    SELECT ingredient_id INTO v_tomato_id FROM ingredients WHERE name = 'طماطم طازجة';
    SELECT ingredient_id INTO v_garlic_id FROM ingredients WHERE name = 'ثوم';
    SELECT ingredient_id INTO v_oil_id FROM ingredients WHERE name = 'زيت زيتون';
    SELECT ingredient_id INTO v_pasta_id FROM ingredients WHERE name = 'مكرونة بنة';

    -- جلب معرفات الوصفات
    SELECT recipe_id INTO v_sub_patty_id FROM recipes WHERE name = 'قرص برجر مجهز';
    SELECT recipe_id INTO v_sub_sauce_id FROM recipes WHERE name = 'صوص الطماطم البيتي';
    SELECT recipe_id INTO v_menu_burger_id FROM recipes WHERE name = 'تشيز برجر كلاسيك';
    SELECT recipe_id INTO v_menu_pasta_id FROM recipes WHERE name = 'مكرونة بالصوص الأحمر';

    -- أ) مكونات الوصفة الفرعية: قرص برجر مجهز (150 جرام لحم + 10 جرام بصل)
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, quantity, uom) VALUES (v_sub_patty_id, v_beef_id, 150, 'G');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, quantity, uom) VALUES (v_sub_patty_id, v_onion_id, 10, 'G');

    -- ب) مكونات الوصفة الفرعية: صوص الطماطم البيتي (200 جرام طماطم + 5 جرام ثوم + 15 ملي زيت زيتون)
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, quantity, uom) VALUES (v_sub_sauce_id, v_tomato_id, 200, 'G');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, quantity, uom) VALUES (v_sub_sauce_id, v_garlic_id, 5, 'G');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, quantity, uom) VALUES (v_sub_sauce_id, v_oil_id, 15, 'ML');

    -- ج) مكونات تشيز برجر كلاسيك (1 خبز برجر + 1 قرص برجر مجهز [وصفة فرعية] + 1 شريحة جبنة شيدر)
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, quantity, uom) VALUES (v_menu_burger_id, v_bun_id, 1, 'PCS');
    INSERT INTO recipe_ingredients (recipe_id, sub_recipe_id, quantity, uom) VALUES (v_menu_burger_id, v_sub_patty_id, 1, 'PCS');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, quantity, uom) VALUES (v_menu_burger_id, v_cheese_id, 1, 'PCS');

    -- د) مكونات مكرونة بالصوص الأحمر (200 جرام مكرونة بنة + 1 صوص الطماطم البيتي [وصفة فرعية])
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, quantity, uom) VALUES (v_menu_pasta_id, v_pasta_id, 200, 'G');
    INSERT INTO recipe_ingredients (recipe_id, sub_recipe_id, quantity, uom) VALUES (v_menu_pasta_id, v_sub_sauce_id, 1, 'PCS');
END;
/

PROMPT Inserting Customers...
INSERT INTO customers (name, phone, email, address) 
VALUES ('أحمد رأفت', '01099887766', 'ahmed.rafat@gmail.com', 'الدقي - 12 شارع التحرير - شقة 5');

INSERT INTO customers (name, phone, email, address) 
VALUES ('مي حسن', '01222334455', 'mai.hassan@yahoo.com', 'مصر الجديدة - 44 شارع الثورة - الدور الثالث');

PROMPT Inserting Delivery Partners...
INSERT INTO delivery_partners (name, contact_number, is_active) VALUES ('شركة طلبات مصر', '19999', 'Y');
INSERT INTO delivery_partners (name, contact_number, is_active) VALUES ('كابتن مرسول الجاهز', '16000', 'Y');

COMMIT;
PROMPT Seed Data Inserted and Committed Successfully.
