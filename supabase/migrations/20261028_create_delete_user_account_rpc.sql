-- Migración: Función RPC segura para eliminación completa de cuenta de usuario
-- Cumple con los requisitos de Apple App Store (Guideline 5.1.1(v)) y Google Play Data Safety.
-- Usa SECURITY DEFINER y SET search_path = public para permitir que el usuario autenticado
-- elimine su propio registro en auth.users (lo que aplica ON DELETE CASCADE / SET NULL
-- en public.profiles y tablas dependientes) sin exponer privilegios de administración.

CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid;
BEGIN
  v_uid := (select auth.uid());
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'No hay sesión autenticada para eliminar la cuenta';
  END IF;

  -- Eliminar perfil público primero (dispara cascades en favoritos, ajustes, historial, etc.
  -- y preserva mezclas/reseñas de la comunidad con author_id = NULL)
  DELETE FROM public.profiles WHERE id = v_uid;

  -- Eliminar identidad de autenticación en Supabase Auth
  DELETE FROM auth.users WHERE id = v_uid;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_user_account() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_user_account() TO authenticated;

