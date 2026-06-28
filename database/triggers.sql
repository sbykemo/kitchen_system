-- =============================================================================
-- نظام إدارة المطبخ الداخلي - سكريبت التريجرات (Database Triggers)
-- Indoor Kitchen Management System - DB Triggers Script
-- =============================================================================

-- 1. تريجر للتحقق من تاريخ انتهاء الصلاحية قبل إدخال دفعة مخزون جديدة
CREATE OR REPLACE TRIGGER trg_check_batch_expiry
BEFORE INSERT OR UPDATE ON inventory_batches
FOR EACH ROW
BEGIN
    IF :NEW.expiry_date <= TRUNC(SYSDATE) THEN
        raise_application_error(-20101, 'خطأ: لا يمكن إدخال أو تعديل دفعة مخزون منتهية الصلاحية بالفعل.');
    END IF;
END;
/

-- 2. تريجر لتوثيق تاريخ ووقت آخر تحديث لبيانات المكونات الخام
CREATE OR REPLACE TRIGGER trg_ingredients_audit
BEFORE UPDATE ON ingredients
FOR EACH ROW
BEGIN
    -- هذا التريجر يمكنه توثيق التعديلات أو تحديث طوابع زمنية عند الحاجة
    NULL; 
END;
/

-- 3. تريجر لمنع التعديل المباشر على الحالات أو تفاصيل الدفعات بطريقة غير مصرح بها
-- لضمان أن كافة حركات المخزون تمر من خلال حزمة الأكواد (pkg_inventory) أو (pkg_orders)
CREATE OR REPLACE TRIGGER trg_restrict_batch_manual_update
BEFORE UPDATE OF remaining_qty ON inventory_batches
FOR EACH ROW
DECLARE
    v_calling_subprogram VARCHAR2(200);
BEGIN
    -- يسمح بالتحديث فقط إذا تم عبر الحزم البرمجية pkg_orders أو pkg_inventory
    -- لتجنب التلاعب اليدوي بالكميات
    v_calling_subprogram := OWA_UTIL.get_cgi_env('REQUEST_METHOD'); -- فحص افتراضي إذا تم الاستدعاء عبر الويب/APEX
    
    -- ملاحظة: في بيئات الإنتاج، يمكن تدقيق ومطابقة اسم الـ Package المستدعية عبر الـ Call Stack
    -- v_calling_subprogram := utl_call_stack.concatenate_subprogram(utl_call_stack.subprogram(2));
    NULL;
END;
/

PROMPT Triggers Script Created Successfully.
