CREATE OR REPLACE PACKAGE pkg_recipes AS
    /*
    =============================================================================
    حزمة إدارة تكاليف الوصفات وقائمة الطعام
    Recipes & Costing Management Package
    =============================================================================
    */

    -- حساب التكلفة الفعلية للوجبة أو الوصفة الفرعية بناءً على آخر أسعار شراء
    FUNCTION calculate_recipe_cost (
        p_recipe_id IN NUMBER
    ) RETURN NUMBER;

    -- الحصول على هامش الربح الحالي لوجبة معينة
    FUNCTION get_profit_margin (
        p_recipe_id IN NUMBER
    ) RETURN NUMBER;

    -- تحديث حالة الوجبة (نشطة / غير نشطة)
    PROCEDURE set_recipe_status (
        p_recipe_id IN NUMBER,
        p_status    IN VARCHAR2
    );

END pkg_recipes;
/

CREATE OR REPLACE PACKAGE BODY pkg_recipes AS

    FUNCTION calculate_recipe_cost (
        p_recipe_id IN NUMBER
    ) RETURN NUMBER IS
        v_total_cost NUMBER := 0.00;
        v_item_cost  NUMBER;
    BEGIN
        -- سنقوم بالدوران حول كافة مكونات الوصفة الحالية
        FOR r IN (
            SELECT ri.ingredient_id, 
                   ri.sub_recipe_id, 
                   ri.quantity, 
                   ri.uom,
                   i.base_uom, 
                   i.current_cost
            FROM recipe_ingredients ri
            LEFT JOIN ingredients i ON ri.ingredient_id = i.ingredient_id
            WHERE ri.recipe_id = p_recipe_id
        ) LOOP
            -- 1. إذا كان المكون عبارة عن مادة خام مباشرة
            IF r.ingredient_id IS NOT NULL THEN
                DECLARE
                    v_factor NUMBER;
                    v_base_qty NUMBER;
                BEGIN
                    -- تحويل كمية الوصفة إلى الوحدة الأساسية للمخزون
                    v_factor := pkg_inventory.get_conversion_factor(r.uom, r.base_uom);
                    v_base_qty := r.quantity * v_factor;
                    
                    v_item_cost := v_base_qty * r.current_cost;
                    v_total_cost := v_total_cost + v_item_cost;
                EXCEPTION
                    WHEN OTHERS THEN
                        -- في حال حدوث خطأ في تحويل الوحدات، نستمر مع إضافة 0 كحماية للمحاسبة
                        v_total_cost := v_total_cost + 0;
                END;
            
            -- 2. إذا كان المكون عبارة عن وصفة فرعية (Sub-recipe)
            ELSIF r.sub_recipe_id IS NOT NULL THEN
                -- استدعاء ذاتي (Recursive Call) لحساب تكلفة الوصفة الفرعية أولاً
                -- ثم ضرب التكلفة بالكمية المستعملة منها
                v_item_cost := calculate_recipe_cost(r.sub_recipe_id) * r.quantity;
                v_total_cost := v_total_cost + v_item_cost;
            END IF;
            
        END LOOP;

        RETURN ROUND(v_total_cost, 2);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 0.00;
        WHEN OTHERS THEN
            RETURN 0.00;
    END calculate_recipe_cost;

    FUNCTION get_profit_margin (
        p_recipe_id IN NUMBER
    ) RETURN NUMBER IS
        v_cost          NUMBER;
        v_selling_price NUMBER;
        v_profit_margin NUMBER := 0.00;
    BEGIN
        -- جلب سعر بيع الوجبة
        SELECT selling_price
        INTO v_selling_price
        FROM recipes
        WHERE recipe_id = p_recipe_id;

        -- حساب التكلفة
        v_cost := calculate_recipe_cost(p_recipe_id);

        -- إذا كانت التكلفة أو سعر البيع صفر لتفادي القسمة على صفر
        IF v_selling_price > 0 THEN
            v_profit_margin := ((v_selling_price - v_cost) / v_selling_price) * 100;
        END IF;

        RETURN ROUND(v_profit_margin, 2);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 0.00;
    END get_profit_margin;

    PROCEDURE set_recipe_status (
        p_recipe_id IN NUMBER,
        p_status    IN VARCHAR2
    ) IS
    BEGIN
        IF p_status NOT IN ('Y', 'N') THEN
            raise_application_error(-20005, 'خطأ: الحالة يجب أن تكون Y للنشط أو N لغير النشط.');
        END IF;

        UPDATE recipes
        SET is_active = p_status
        WHERE recipe_id = p_recipe_id;
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            raise_application_error(-20006, 'الوجبة المطلوبة غير موجودة.');
    END set_recipe_status;

END pkg_recipes;
/
