CREATE OR REPLACE PACKAGE pkg_inventory AS
    /*
    =============================================================================
    حزمة إدارة المخزون والمشتريات
    Inventory & Purchase Management Package
    =============================================================================
    */

    -- إضافة فاتورة شراء أو توريد مادة خام للمخزون مع تحديث التكلفة والكميات
    PROCEDURE add_purchase_receipt (
        p_ingredient_id   IN NUMBER,
        p_qty             IN NUMBER,
        p_purchase_uom    IN VARCHAR2,
        p_unit_cost       IN NUMBER, -- التكلفة للوحدة التي تم الشراء بها
        p_expiry_date     IN DATE
    );

    -- الحصول على إجمالي الرصيد الحالي الصالح للاستخدام لمادة خام معينة
    FUNCTION get_current_stock (
        p_ingredient_id   IN NUMBER
    ) RETURN NUMBER;

    -- الحصول على معامل التحويل بين وحدات القياس
    FUNCTION get_conversion_factor (
        p_from_uom        IN VARCHAR2,
        p_to_uom          IN VARCHAR2
    ) RETURN NUMBER;

END pkg_inventory;
/

CREATE OR REPLACE PACKAGE BODY pkg_inventory AS

    FUNCTION get_conversion_factor (
        p_from_uom        IN VARCHAR2,
        p_to_uom          IN VARCHAR2
    ) RETURN NUMBER IS
        v_factor NUMBER;
    BEGIN
        -- إذا كانت الوحدات متطابقة، المعامل هو 1
        IF p_from_uom = p_to_uom THEN
            RETURN 1;
        END IF;

        -- البحث عن التحويل المباشر
        BEGIN
            SELECT conversion_factor
            INTO v_factor
            FROM uom_conversions
            WHERE from_uom = p_from_uom AND to_uom = p_to_uom;
            
            RETURN v_factor;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- البحث عن التحويل العكسي
                BEGIN
                    SELECT 1 / conversion_factor
                    INTO v_factor
                    FROM uom_conversions
                    WHERE from_uom = p_to_uom AND to_uom = p_from_uom;
                    
                    RETURN v_factor;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        raise_application_error(-20001, 'خطأ: لا يوجد تعريف تحويل بين الوحدة ' || p_from_uom || ' والوحدة ' || p_to_uom);
                END;
        END;
    END get_conversion_factor;

    PROCEDURE add_purchase_receipt (
        p_ingredient_id   IN NUMBER,
        p_qty             IN NUMBER,
        p_purchase_uom    IN VARCHAR2,
        p_unit_cost       IN NUMBER,
        p_expiry_date     IN DATE
    ) IS
        v_base_uom       ingredients.base_uom%TYPE;
        v_factor         NUMBER;
        v_base_qty       NUMBER;
        v_base_unit_cost NUMBER;
    BEGIN
        -- 1. التأكد من صحة الكمية والسعر وتاريخ انتهاء الصلاحية
        IF p_qty <= 0 OR p_unit_cost <= 0 THEN
            raise_application_error(-20002, 'يجب أن تكون الكمية والسعر أكبر من الصفر.');
        END IF;

        IF p_expiry_date <= TRUNC(SYSDATE) THEN
            raise_application_error(-20003, 'تاريخ انتهاء الصلاحية يجب أن يكون في المستقبل.');
        END IF;

        -- 2. جلب وحدة القياس الأساسية للمادة
        SELECT base_uom
        INTO v_base_uom
        FROM ingredients
        WHERE ingredient_id = p_ingredient_id;

        -- 3. حساب الكمية وتكلفة الوحدة بناءً على وحدة القياس الأساسية (Base UOM)
        v_factor := get_conversion_factor(p_purchase_uom, v_base_uom);
        
        v_base_qty := p_qty * v_factor;
        v_base_unit_cost := p_unit_cost / v_factor;

        -- 4. إدراج الدفعة الجديدة في المخزون
        INSERT INTO inventory_batches (
            ingredient_id,
            purchase_date,
            expiry_date,
            initial_qty,
            remaining_qty,
            unit_cost,
            is_active
        ) VALUES (
            p_ingredient_id,
            TRUNC(SYSDATE),
            TRUNC(p_expiry_date),
            v_base_qty,
            v_base_qty,
            v_base_unit_cost,
            'Y'
        );

        -- 5. تحديث التكلفة الحالية للمادة الخام في جدول المكونات (آخر سعر شراء فعلي)
        UPDATE ingredients
        SET current_cost = v_base_unit_cost
        WHERE ingredient_id = p_ingredient_id;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            raise_application_error(-20004, 'المادة الخام المحددة غير موجودة بقاعدة البيانات.');
    END add_purchase_receipt;

    FUNCTION get_current_stock (
        p_ingredient_id   IN NUMBER
    ) RETURN NUMBER IS
        v_total_stock NUMBER := 0;
    BEGIN
        SELECT NVL(SUM(remaining_qty), 0)
        INTO v_total_stock
        FROM inventory_batches
        WHERE ingredient_id = p_ingredient_id
          AND expiry_date > TRUNC(SYSDATE)
          AND is_active = 'Y';
          
        RETURN v_total_stock;
    END get_current_stock;

END pkg_inventory;
/
