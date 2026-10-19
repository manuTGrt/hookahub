-- =============================================================================
-- Migración: Tabla de Feedback y Contacto de Usuarios (user_feedback)
-- Nombre de migración: create_user_feedback_table
-- Fecha: 2026-10-19
-- Descripción: Permite a usuarios autenticados enviar reportes de bugs, sugerencias
--              y dudas de soporte técnico persistidos para su gestión interna.
-- =============================================================================

-- Tabla para almacenar reportes, sugerencias y consultas de los usuarios
CREATE TABLE IF NOT EXISTS public.user_feedback (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  category    text        NOT NULL 
                          CHECK (category IN ('bug', 'suggestion', 'other')),
  subject     text        NOT NULL,
  message     text        NOT NULL,
  platform    text        CHECK (platform IN ('android', 'ios', 'web', 'other')),
  app_version text,
  status      text        NOT NULL DEFAULT 'pending'
                          CHECK (status IN ('pending', 'in_progress', 'resolved', 'closed')),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

-- Índices para optimizar consultas de administración y métricas
CREATE INDEX IF NOT EXISTS idx_user_feedback_user_id ON public.user_feedback(user_id);
CREATE INDEX IF NOT EXISTS idx_user_feedback_category ON public.user_feedback(category);
CREATE INDEX IF NOT EXISTS idx_user_feedback_status ON public.user_feedback(status);
CREATE INDEX IF NOT EXISTS idx_user_feedback_created_at ON public.user_feedback(created_at DESC);

-- Habilitar Row Level Security
ALTER TABLE public.user_feedback ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------------------------------
-- Política INSERT: solo usuarios autenticados pueden insertar sus propias filas.
-- Se usa subconsulta `(select auth.uid())` para evitar el problema de
-- rendimiento "Auth RLS Initialization Plan" (auth_rls_initplan).
-- Referencia: GEMINI.md → Rendimiento en RLS
-- -----------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
      AND tablename = 'user_feedback' 
      AND policyname = 'Users can insert their own feedback'
  ) THEN
    CREATE POLICY "Users can insert their own feedback"
      ON public.user_feedback
      FOR INSERT
      TO authenticated
      WITH CHECK ((select auth.uid()) = user_id);
  END IF;
END $$;

-- -----------------------------------------------------------------------------
-- NOTA: No existe política SELECT para usuarios finales.
-- Los usuarios no listan su feedback histórico en la app del cliente.
-- La gestión completa es responsabilidad exclusiva del panel de administración
-- a través del service_role o roles administrativos (sin restricciones RLS).
-- -----------------------------------------------------------------------------
