-- ============================================================
-- Security remediation — Feature 001 (variant discounts)
-- Review only. DO NOT RUN without explicit approval.
-- ============================================================

-- ---------- Pre-deployment checks (manual) ----------
-- Legacy RPC grants (all grantees, including PUBLIC via COALESCE):
-- SELECT CASE WHEN a.grantee=0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END AS grantee, a.privilege_type
-- FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
-- LEFT JOIN LATERAL aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) a ON true
-- WHERE n.nspname='public' AND p.proname='create_store_order';
--
-- has_function_privilege (anon/auth):
-- SELECT has_function_privilege('anon','public.create_store_order(text,text,text,text,text,jsonb,text,text)','EXECUTE') AS anon_exec,
--        has_function_privilege('authenticated','public.create_store_order(text,text,text,text,text,jsonb,text,text)','EXECUTE') AS auth_exec;
-- Expected pre: true, true
--
-- Table grants (all grantees) — INSERT only:
-- SELECT grantee, table_name, privilege_type
-- FROM information_schema.table_privileges
-- WHERE table_schema='public' AND table_name IN ('orders','order_items') AND privilege_type='INSERT'
-- ORDER BY table_name, grantee;
--
-- has_table_privilege (anon/auth):
-- SELECT has_table_privilege('anon','public.orders','INSERT') AS anon_orders_insert,
--        has_table_privilege('authenticated','public.orders','INSERT') AS auth_orders_insert,
--        has_table_privilege('anon','public.order_items','INSERT') AS anon_items_insert,
--        has_table_privilege('authenticated','public.order_items','INSERT') AS auth_items_insert;
-- Expected pre: false, true, false, true

-- has_table_privilege (anon/auth) — additional revocations for TRUNCATE, REFERENCES, TRIGGER:
-- SELECT has_table_privilege('anon','public.orders','TRUNCATE') AS anon_orders_truncate,
--       has_table_privilege('authenticated','public.orders','TRUNCATE') AS auth_orders_truncate,
--       has_table_privilege('anon','public.orders','REFERENCES') AS anon_orders_references,
--       has_table_privilege('authenticated','public.orders','REFERENCES') AS auth_orders_references,
--       has_table_privilege('anon','public.orders','TRIGGER') AS anon_orders_trigger,
--       has_table_privilege('authenticated','public.orders','TRIGGER') AS auth_orders_trigger,
--       has_table_privilege('anon','public.order_items','TRUNCATE') AS anon_items_truncate,
--       has_table_privilege('authenticated','public.order_items','TRUNCATE') AS auth_items_truncate,
--       has_table_privilege('anon','public.order_items','REFERENCES') AS anon_items_references,
--       has_table_privilege('authenticated','public.order_items','REFERENCES') AS auth_items_references,
--       has_table_privilege('anon','public.order_items','TRIGGER') AS anon_items_trigger,
--       has_table_privilege('authenticated','public.order_items','TRIGGER') AS auth_items_trigger;
-- Expected pre: true, true, true, true, true, true, true, true, true, true, true, true
--
-- INSERT policies:
-- SELECT tablename, policyname, roles, cmd, with_check
-- FROM pg_policies
-- WHERE schemaname='public' AND tablename IN ('orders','order_items') AND cmd='INSERT';
-- Expected pre: 2 rows ("authenticated can create orders", "authenticated can create order_items")
--
-- Triggers (side effects):
-- SELECT tgname, tgrelid::regclass::text, tgenabled
-- FROM pg_trigger
-- WHERE tgrelid IN ('public.orders'::regclass,'public.order_items'::regclass,'public.product_variants'::regclass)
--   AND NOT tgisinternal;

BEGIN;

-- 1) Revoke legacy RPC execute from customers (and PUBLIC)
REVOKE EXECUTE ON FUNCTION public.create_store_order(
  text, text, text, text, text, jsonb, text, text
) FROM PUBLIC, anon, authenticated;

-- 2) Revoke direct insert grants (customers only; admin/service roles untouched)
REVOKE INSERT ON public.orders FROM PUBLIC, anon, authenticated;
REVOKE INSERT ON public.order_items FROM PUBLIC, anon, authenticated;

-- 3) Revoke additional unsafe table privileges: TRUNCATE, REFERENCES, TRIGGER
REVOKE TRUNCATE, REFERENCES, TRIGGER
ON public.orders FROM PUBLIC, anon, authenticated;
REVOKE TRUNCATE, REFERENCES, TRIGGER
ON public.order_items FROM PUBLIC, anon, authenticated;

-- 4) Remove permissive direct-insert RLS policies
DROP POLICY IF EXISTS "authenticated can create orders" ON public.orders;
DROP POLICY IF EXISTS "authenticated can create order_items" ON public.order_items;

COMMIT;

-- ---------- Post-deployment verification (manual) ----------
-- Legacy RPC grants (all grantees, including PUBLIC via COALESCE):
-- SELECT CASE WHEN a.grantee=0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END AS grantee, a.privilege_type
-- FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
-- LEFT JOIN LATERAL aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) a ON true
-- WHERE n.nspname='public' AND p.proname='create_store_order';
-- Expected post: no PUBLIC/anon/authenticated EXECUTE rows
--
-- has_function_privilege (anon/auth):
-- SELECT has_function_privilege('anon','public.create_store_order(text,text,text,text,text,jsonb,text,text)','EXECUTE') AS anon_exec,
--        has_function_privilege('authenticated','public.create_store_order(text,text,text,text,text,jsonb,text,text)','EXECUTE') AS auth_exec;
-- Expected post: false, false
--
-- Table grants (INSERT) — verify no PUBLIC/anon/authenticated:
-- SELECT grantee, table_name, privilege_type
-- FROM information_schema.table_privileges
-- WHERE table_schema='public' AND table_name IN ('orders','order_items') AND privilege_type='INSERT'
-- ORDER BY table_name, grantee;
-- Expected post: rows may exist for service_role/postgres/admin roles, but NO PUBLIC/anon/authenticated
--
-- has_table_privilege (anon/auth):
-- SELECT has_table_privilege('anon','public.orders','INSERT') AS anon_orders_insert,
--        has_table_privilege('authenticated','public.orders','INSERT') AS auth_orders_insert,
--        has_table_privilege('anon','public.order_items','INSERT') AS anon_items_insert,
--        has_table_privilege('authenticated','public.order_items','INSERT') AS auth_items_insert;
-- Expected post: false, false, false, false

-- has_table_privilege (anon/auth) — additional revocations verified:
-- SELECT has_table_privilege('anon','public.orders','TRUNCATE') AS anon_orders_truncate,
--       has_table_privilege('authenticated','public.orders','TRUNCATE') AS auth_orders_truncate,
--       has_table_privilege('anon','public.orders','REFERENCES') AS anon_orders_references,
--       has_table_privilege('authenticated','public.orders','REFERENCES') AS auth_orders_references,
--       has_table_privilege('anon','public.orders','TRIGGER') AS anon_orders_trigger,
--       has_table_privilege('authenticated','public.orders','TRIGGER') AS auth_orders_trigger,
--       has_table_privilege('anon','public.order_items','TRUNCATE') AS anon_items_truncate,
--       has_table_privilege('authenticated','public.order_items','TRUNCATE') AS auth_items_truncate,
--       has_table_privilege('anon','public.order_items','REFERENCES') AS anon_items_references,
--       has_table_privilege('authenticated','public.order_items','REFERENCES') AS auth_items_references,
--       has_table_privilege('anon','public.order_items','TRIGGER') AS anon_items_trigger,
--       has_table_privilege('authenticated','public.order_items','TRIGGER') AS auth_items_trigger;
-- Expected post: false, false, false, false, false, false, false, false, false, false, false, false
--
-- INSERT policies:
-- SELECT tablename, policyname
-- FROM pg_policies
-- WHERE schemaname='public' AND tablename IN ('orders','order_items') AND cmd='INSERT';
-- Expected post: 0 rows
--
-- Note: "Store admins manage orders/order items" (FOR ALL) remains, but direct INSERT is blocked by revoked table privilege for authenticated (including admins). No standalone INSERT policy remains.
--
-- Safe transactional test (no persistent changes):
-- BEGIN;
-- SET LOCAL ROLE anon;
-- SELECT public.submit_checkout_order('SECURITY_TEST_20261107','0799999999','Addr','City','[{"variant_id":<valid_id>,"quantity":1}]'::jsonb,NULL,NULL);
-- -- Expected JSON keys: success, order_id, order_number, subtotal, shipping_cost (0), total, payment_method, payment_status
-- ROLLBACK;
--
-- Baseline unchanged:
-- SELECT count(*) AS leftover_test_orders FROM public.orders WHERE customer_name='SECURITY_TEST_20261107' AND customer_phone='0799999999';  -- Expected: 0