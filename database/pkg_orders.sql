CREATE OR REPLACE PACKAGE pkg_orders AS
    /*
    =============================================================================
    حزمة إدارة الطلبات وتدفق العمليات والمطبخ
    Order Management & Workflow Package
    =============================================================================
    */

    -- الأنواع المستخدمة لتجميع متطلبات المواد الخام للطلب
    TYPE r_required_ingredient IS RECORD (
        ingredient_id NUMBER,
        total_qty     NUMBER
    );
    TYPE t_required_list IS TABLE OF r_required_ingredient;

    -- إنشاء رأس الطلب الجديد
    PROCEDURE create_order (
        p_customer_id       IN NUMBER,
        p_order_type        IN VARCHAR2, -- DELIVERY / PICKUP
        p_payment_method    IN VARCHAR2, -- COD / INSTAPAY / WALLET
        p_payment_reference IN VARCHAR2 DEFAULT NULL,
        p_delivery_partner  IN NUMBER DEFAULT NULL,
        o_order_id          OUT NUMBER
    );

    -- إضافة وجبة للطلب
    PROCEDURE add_order_item (
        p_order_id          IN NUMBER,
        p_recipe_id         IN NUMBER,
        p_quantity          IN NUMBER,
        o_order_item_id     OUT NUMBER
    );

    -- إضافة تخصيص/تعديل على وجبة معينة في الطلب
    PROCEDURE add_item_customization (
        p_order_item_id     IN NUMBER,
        p_custom_name       IN VARCHAR2,
        p_charge_amount     IN NUMBER DEFAULT 0.00
    );

    -- تحديث حالة الطلب والتحكم في المخزون وحساب التكلفة الفعلية
    PROCEDURE update_order_status (
        p_order_id          IN NUMBER,
        p_new_status        IN VARCHAR2 -- PENDING, PREPARING, READY, DELIVERED
    );

    -- تجميع المواد الخام المطلوبة للطلب بالكامل (بما فيها المكونات والوصفات الفرعية)
    PROCEDURE collect_order_ingredients (
        p_order_id          IN NUMBER,
        o_list              IN OUT NOCOPY t_required_list
    );

END pkg_orders;
/

CREATE OR REPLACE PACKAGE BODY pkg_orders AS

    PROCEDURE create_order (
        p_customer_id       IN NUMBER,
        p_order_type        IN VARCHAR2,
        p_payment_method    IN VARCHAR2,
        p_payment_reference IN VARCHAR2 DEFAULT NULL,
        p_delivery_partner  IN NUMBER DEFAULT NULL,
        o_order_id          OUT NUMBER
    ) IS
    BEGIN
        INSERT INTO orders (
            customer_id,
            order_date,
            status,
            order_type,
            delivery_partner_id,
            total_amount,
            payment_method,
            payment_reference
        ) VALUES (
            p_customer_id,
            CURRENT_TIMESTAMP,
            'PENDING',
            p_order_type,
            p_delivery_partner,
            0.00, -- سيبدأ بـ 0 ويتم تحديثه مع إضافة الأصناف والتخصيصات
            p_payment_method,
            p_payment_reference
        ) RETURNING order_id INTO o_order_id;

        -- تسجيل الحالة الأولية في السجل
        INSERT INTO order_status_history (order_id, status)
        VALUES (o_order_id, 'PENDING');
    END create_order;

    PROCEDURE add_order_item (
        p_order_id          IN NUMBER,
        p_recipe_id         IN NUMBER,
        p_quantity          IN NUMBER,
        o_order_item_id     OUT NUMBER
    ) IS
        v_selling_price NUMBER(10,2);
    BEGIN
        -- جلب سعر الوجبة الحالي
        SELECT selling_price
        INTO v_selling_price
        FROM recipes
        WHERE recipe_id = p_recipe_id AND is_active = 'Y';

        -- إدراج صنف الطلب
        INSERT INTO order_items (
            order_id,
            recipe_id,
            quantity,
            unit_price,
            actual_cost
        ) VALUES (
            p_order_id,
            p_recipe_id,
            p_quantity,
            v_selling_price,
            0.00 -- سيتم حسابه وحفظه عند بدء التحضير
        ) RETURNING order_item_id INTO o_order_item_id;

        -- تحديث إجمالي الطلب الرئيسي
        UPDATE orders
        SET total_amount = total_amount + (v_selling_price * p_quantity)
        WHERE order_id = p_order_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            raise_application_error(-20010, 'الوجبة المطلوبة غير موجودة أو غير نشطة.');
    END add_order_item;

    PROCEDURE add_item_customization (
        p_order_item_id     IN NUMBER,
        p_custom_name       IN VARCHAR2,
        p_charge_amount     IN NUMBER DEFAULT 0.00
    ) IS
        v_order_id NUMBER;
        v_qty      NUMBER;
    BEGIN
        -- إدراج التخصيص
        INSERT INTO order_customizations (
            order_item_id,
            customization_name,
            charge_amount
        ) VALUES (
            p_order_item_id,
            p_custom_name,
            p_charge_amount
        );

        -- جلب كمية الصنف ورقم الطلب لتحديث الإجمالي الرئيسي للطلب
        SELECT order_id, quantity
        INTO v_order_id, v_qty
        FROM order_items
        WHERE order_item_id = p_order_item_id;

        -- تحديث إجمالي الطلب مع مراعاة عدد مرات تكرار الصنف
        UPDATE orders
        SET total_amount = total_amount + (p_charge_amount * v_qty)
        WHERE order_id = v_order_id;
    END add_item_customization;

    -- دالة مساعدة داخلية لتجميع مكونات وجبة بشكل تراجعي (Recursive)
    PROCEDURE collect_recipe_ingredients_rec (
        p_recipe_id IN NUMBER,
        p_qty       IN NUMBER,
        io_list     IN OUT NOCOPY t_required_list
    ) IS
        v_factor NUMBER;
        v_base_qty NUMBER;
        v_found BOOLEAN;
    BEGIN
        FOR r IN (
            SELECT ri.ingredient_id, ri.sub_recipe_id, ri.quantity, ri.uom, i.base_uom
            FROM recipe_ingredients ri
            LEFT JOIN ingredients i ON ri.ingredient_id = i.ingredient_id
            WHERE ri.recipe_id = p_recipe_id
        ) LOOP
            -- أ) إذا كان مكون خام مباشر
            IF r.ingredient_id IS NOT NULL THEN
                v_factor := pkg_inventory.get_conversion_factor(r.uom, r.base_uom);
                v_base_qty := r.quantity * p_qty * v_factor;

                -- التحقق إذا كانت المادة موجودة بالفعل في القائمة لتحديثها بدلاً من التكرار
                v_found := FALSE;
                FOR idx IN 1..io_list.COUNT LOOP
                    IF io_list(idx).ingredient_id = r.ingredient_id THEN
                        io_list(idx).total_qty := io_list(idx).total_qty + v_base_qty;
                        v_found := TRUE;
                        EXIT;
                    END IF;
                END LOOP;

                -- إذا لم تكن موجودة، نضيفها كعنصر جديد
                IF NOT v_found THEN
                    io_list.EXTEND;
                    io_list(io_list.LAST).ingredient_id := r.ingredient_id;
                    io_list(io_list.LAST).total_qty := v_base_qty;
                END IF;

            -- ب) إذا كان وصفة فرعية
            ELSIF r.sub_recipe_id IS NOT NULL THEN
                -- استدعاء تراجعي للوصفة الفرعية
                collect_recipe_ingredients_rec(r.sub_recipe_id, r.quantity * p_qty, io_list);
            END IF;
        END LOOP;
    END collect_recipe_ingredients_rec;

    PROCEDURE collect_order_ingredients (
        p_order_id          IN NUMBER,
        o_list              IN OUT NOCOPY t_required_list
    ) IS
    BEGIN
        o_list := t_required_list();
        -- جلب كافة وجبات الطلب
        FOR item IN (
            SELECT recipe_id, quantity
            FROM order_items
            WHERE order_id = p_order_id
        ) LOOP
            collect_recipe_ingredients_rec(item.recipe_id, item.quantity, o_list);
        END LOOP;
    END collect_order_ingredients;

    -- إجراء داخلي لخصم المخزون باستخدام سياسة FIFO/FEFO وحساب التكلفة الفعلية
    PROCEDURE deduct_inventory_and_set_cost (
        p_order_id IN NUMBER
    ) IS
        v_req_list        t_required_list;
        v_available_stock NUMBER;
        v_ing_name        ingredients.name%TYPE;
        v_qty_to_deduct   NUMBER;
        v_batch_deducted  NUMBER;
        v_actual_cost     NUMBER := 0.00;
        v_item_actual_cost NUMBER;
    BEGIN
        -- 1. تجميع كل المواد المطلوبة للطلب
        collect_order_ingredients(p_order_id, v_req_list);

        -- 2. التحقق المسبق من وجود كميات كافية لجميع المواد لتجنب الخصم الجزئي
        FOR idx IN 1..v_req_list.COUNT LOOP
            v_available_stock := pkg_inventory.get_current_stock(v_req_list(idx).ingredient_id);
            IF v_available_stock < v_req_list(idx).total_qty THEN
                SELECT name INTO v_ing_name FROM ingredients WHERE ingredient_id = v_req_list(idx).ingredient_id;
                raise_application_error(-20011, 'خطأ: لا يوجد مخزون كافٍ للمادة الخام (' || v_ing_name || '). المطلوب: ' || v_req_list(idx).total_qty || '، المتوفر: ' || v_available_stock);
            END IF;
        END LOOP;

        -- 3. الخصم الفعلي للمكونات بنظام FEFO (تاريخ الصلاحية الأقرب أولاً)
        FOR idx IN 1..v_req_list.COUNT LOOP
            v_qty_to_deduct := v_req_list(idx).total_qty;

            -- الاستعلام عن باتشات المخزون النشطة للمكون مرتبة حسب تاريخ انتهاء الصلاحية
            FOR batch IN (
                SELECT batch_id, remaining_qty, unit_cost
                FROM inventory_batches
                WHERE ingredient_id = v_req_list(idx).ingredient_id
                  AND expiry_date > TRUNC(SYSDATE)
                  AND remaining_qty > 0
                  AND is_active = 'Y'
                ORDER BY expiry_date ASC, purchase_date ASC
                FOR UPDATE -- قفل الصفوف لمنع حدوث Race Conditions
            ) LOOP
                EXIT WHEN v_qty_to_deduct = 0;

                IF batch.remaining_qty >= v_qty_to_deduct THEN
                    -- الدفعة تغطي كامل الكمية المتبقية
                    UPDATE inventory_batches
                    SET remaining_qty = remaining_qty - v_qty_to_deduct
                    WHERE batch_id = batch.batch_id;

                    v_actual_cost := v_actual_cost + (v_qty_to_deduct * batch.unit_cost);
                    v_qty_to_deduct := 0;
                ELSE
                    -- الدفعة تغطي جزءاً من الكمية فقط
                    UPDATE inventory_batches
                    SET remaining_qty = 0
                    WHERE batch_id = batch.batch_id;

                    v_actual_cost := v_actual_cost + (batch.remaining_qty * batch.unit_cost);
                    v_qty_to_deduct := v_qty_to_deduct - batch.remaining_qty;
                END IF;
            END LOOP;
        END LOOP;

        -- 4. توزيع التكلفة الفعلية (Actual Cost) وحفظها على مستوى بنود الطلب (Order Items)
        -- كحل رياضي تقريبي، سنقوم بحساب تكلفة الوجبة وتخزينها
        FOR item IN (
            SELECT order_item_id, recipe_id, quantity
            FROM order_items
            WHERE order_id = p_order_id
        ) LOOP
            v_item_actual_cost := pkg_recipes.calculate_recipe_cost(item.recipe_id) * item.quantity;
            UPDATE order_items
            SET actual_cost = v_item_actual_cost
            WHERE order_item_id = item.order_item_id;
        END LOOP;

    END deduct_inventory_and_set_cost;

    PROCEDURE update_order_status (
        p_order_id          IN NUMBER,
        p_new_status        IN VARCHAR2
    ) IS
        v_current_status orders.status%TYPE;
    BEGIN
        -- جلب الحالة الحالية
        SELECT status
        INTO v_current_status
        FROM orders
        WHERE order_id = p_order_id;

        -- التحقق من منطقية تغيير الحالة
        IF v_current_status = p_new_status THEN
            RETURN;
        END IF;

        -- التحقق من تتابع الحالات: PENDING -> PREPARING -> READY -> DELIVERED
        IF (v_current_status = 'PENDING' AND p_new_status != 'PREPARING') OR
           (v_current_status = 'PREPARING' AND p_new_status != 'READY') OR
           (v_current_status = 'READY' AND p_new_status != 'DELIVERED') OR
           (v_current_status = 'DELIVERED') THEN
            raise_application_error(-20012, 'تغيير حالة غير مسموح به من ' || v_current_status || ' إلى ' || p_new_status);
        END IF;

        -- إذا كانت الحالة الجديدة "قيد التحضير PREPARING"، يتم خصم المخزون فوراً
        IF p_new_status = 'PREPARING' THEN
            deduct_inventory_and_set_cost(p_order_id);
        END IF;

        -- تحديث حالة الطلب الرئيسية
        UPDATE orders
        SET status = p_new_status
        WHERE order_id = p_order_id;

        -- تسجيل في تاريخ الحالات
        INSERT INTO order_status_history (order_id, status)
        VALUES (p_order_id, p_new_status);

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            raise_application_error(-20013, 'الطلب المحدد غير موجود.');
    END update_order_status;

END pkg_orders;
/
