-- =============================================================================
-- Migración: Tabla de Solicitudes de Tabacos (tobacco_requests)
-- Nombre de migración: create_tobacco_requests_table
-- Fecha: 2026-05-03
-- Descripción: Permite a usuarios autenticados enviar solicitudes de tabacos
--              que no existen en el catálogo para que los administradores
--              los añadan manualmente.
-- =============================================================================

-- Tabla para almacenar solicitudes de nuevos tabacos al catálogo
CREATE TABLE public.tobacco_requests (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  brand       text        NOT NULL,
  name        text        NOT NULL,
  description text,
  flavors     text,           -- Texto plano, ej: "Sandía, Melón, Maracuyá"
  status      text        NOT NULL DEFAULT 'pending'
                          CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- Habilitar Row Level Security
ALTER TABLE public.tobacco_requests ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------------------------------
-- Política INSERT: solo usuarios autenticados pueden insertar sus propias filas.
-- Se usa subconsulta `(select auth.uid())` para evitar el problema de
-- rendimiento "Auth RLS Initialization Plan" (auth_rls_initplan).
-- Referencia: GEMINI.md → Rendimiento en RLS
-- -----------------------------------------------------------------------------
CREATE POLICY "Users can insert their own requests"
  ON public.tobacco_requests
  FOR INSERT
  TO authenticated
  WITH CHECK ((select auth.uid()) = user_id);

-- -----------------------------------------------------------------------------
-- NOTA: No existe política SELECT para usuarios finales.
-- Los usuarios no pueden listar sus solicitudes (no hay historial en la app).
-- La gestión completa es responsabilidad exclusiva del panel de administración
-- a través del service_role (sin restricciones RLS).
-- -----------------------------------------------------------------------------
