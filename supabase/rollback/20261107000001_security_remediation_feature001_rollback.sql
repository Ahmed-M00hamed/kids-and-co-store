-- ============================================================
-- Rollback — Security remediation Feature 001 (EMERGENCY ONLY)
-- Restores previous permissions/policies. Reopens security bypass.
-- WARNING: This rollback restores insecure permissions. Use only in emergency.
-- ============================================================

BEGIN;

-- 1) Restore legacy RPC execute to original scope (PUBLIC only; not broader)
GRANT EXECUTE ON FUNCTION public.create_store_order(
  text, text, text, text, text, jsonb, text, text
) TO PUBLIC;

-- 2) Restore direct insert grant to authenticated only (original state; anon never had it)
GRANT INSERT ON public.orders TO authenticated;
GRANT INSERT ON public.order_items TO authenticated;

-- 3) Restore original RLS insert policies
CREATE POLICY "authenticated can create orders"
  ON public.orders FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "authenticated can create order_items"
  ON public.order_items FOR INSERT TO authenticated WITH CHECK (true);

COMMIT;
