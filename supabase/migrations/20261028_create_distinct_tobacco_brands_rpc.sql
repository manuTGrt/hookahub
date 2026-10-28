-- Migración: Función RPC para obtener marcas únicas de tabacos directamente desde PostgreSQL
-- Evita el overfetching de descargar todas las filas de `tobaccos` y el truncado de 1.000 filas de PostgREST.

CREATE OR REPLACE FUNCTION public.get_available_tobacco_brands()
RETURNS TABLE(brand text)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT DISTINCT t.brand
  FROM public.tobaccos t
  WHERE t.brand IS NOT NULL
    AND btrim(t.brand) <> ''
  ORDER BY t.brand ASC;
$$;

GRANT EXECUTE ON FUNCTION public.get_available_tobacco_brands() TO anon, authenticated;

