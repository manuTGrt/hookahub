-- Migración: Función RPC transaccional para actualizar una mezcla y sus componentes atómicamente
-- Evita que un fallo de red intermedio entre DELETE mix_components e INSERT mix_components
-- deje la mezcla corrupta sin ingredientes en producción.

CREATE OR REPLACE FUNCTION public.update_user_mix(
  p_mix_id uuid,
  p_name text,
  p_description text,
  p_components jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_uid uuid;
BEGIN
  v_uid := (select auth.uid());
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'No hay sesión autenticada para actualizar la mezcla';
  END IF;

  -- 1. Actualizar la cabecera de la mezcla validando autoría
  UPDATE public.mixes
  SET
    name = p_name,
    description = p_description,
    updated_at = now()
  WHERE id = p_mix_id
    AND author_id = v_uid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Mezcla no encontrada o sin permisos de edición';
  END IF;

  -- 2. Reemplazar los componentes dentro de la misma transacción
  DELETE FROM public.mix_components
  WHERE mix_id = p_mix_id;

  IF jsonb_typeof(p_components) = 'array' AND jsonb_array_length(p_components) > 0 THEN
    INSERT INTO public.mix_components (
      mix_id,
      tobacco_name,
      brand,
      percentage,
      color
    )
    SELECT
      p_mix_id,
      c.tobacco_name,
      c.brand,
      c.percentage,
      c.color
    FROM jsonb_to_recordset(p_components) AS c(
      tobacco_name text,
      brand text,
      percentage numeric,
      color text
    );
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.update_user_mix(uuid, text, text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_user_mix(uuid, text, text, jsonb) TO authenticated;

