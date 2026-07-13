-- 18_add_super_admin_role_and_user_management.sql
-- This migration:
--   1. Adds 'super_admin' value to public.app_role enum.
--   2. Creates secure SECURITY DEFINER RPCs for user management (password reset, role changes, and deletion).

-- Note: ALTER TYPE ... ADD VALUE cannot be executed inside a transaction block in some environments,
-- but on Supabase (Postgres 15+) it is supported. To be completely safe, we'll execute it.
ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'super_admin';

-- 1. Secure RPC to change any user's password (strictly restricted to super_admin)
CREATE OR REPLACE FUNCTION public.admin_update_user_password(target_user_id uuid, new_password text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Verify caller is super_admin
  IF NOT EXISTS (
    SELECT 1 FROM public.app_user 
    WHERE id = auth.uid() AND role = 'super_admin'::public.app_role
  ) THEN
    RAISE EXCEPTION 'Access denied. Only super_admin can change passwords.';
  END IF;

  -- Update auth.users encrypted password
  UPDATE auth.users
  SET encrypted_password = crypt(new_password, gen_salt('bf'))
  WHERE id = target_user_id;
END;
$$;

-- 2. Secure RPC to update any user's role (strictly restricted to super_admin)
CREATE OR REPLACE FUNCTION public.admin_update_user_role(target_user_id uuid, new_role public.app_role)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Verify caller is super_admin
  IF NOT EXISTS (
    SELECT 1 FROM public.app_user 
    WHERE id = auth.uid() AND role = 'super_admin'::public.app_role
  ) THEN
    RAISE EXCEPTION 'Access denied. Only super_admin can change roles.';
  END IF;

  -- Update the role
  UPDATE public.app_user
  SET role = new_role
  WHERE id = target_user_id;
END;
$$;

-- 3. Secure RPC to delete any user (strictly restricted to super_admin)
CREATE OR REPLACE FUNCTION public.admin_delete_user(target_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Verify caller is super_admin
  IF NOT EXISTS (
    SELECT 1 FROM public.app_user 
    WHERE id = auth.uid() AND role = 'super_admin'::public.app_role
  ) THEN
    RAISE EXCEPTION 'Access denied. Only super_admin can delete users.';
  END IF;

  -- Delete from auth.users (will trigger cascade or we delete from app_user manually)
  DELETE FROM auth.users WHERE id = target_user_id;
  DELETE FROM public.app_user WHERE id = target_user_id;
END;
$$;

-- Revoke execute from public to be highly secure
REVOKE EXECUTE ON FUNCTION public.admin_update_user_password(uuid, text) FROM public;
REVOKE EXECUTE ON FUNCTION public.admin_update_user_role(uuid, public.app_role) FROM public;
REVOKE EXECUTE ON FUNCTION public.admin_delete_user(uuid) FROM public;

-- Grant execute only to authenticated users (who will then be validated inside the function body)
GRANT EXECUTE ON FUNCTION public.admin_update_user_password(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_user_role(uuid, public.app_role) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_user(uuid) TO authenticated;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';
