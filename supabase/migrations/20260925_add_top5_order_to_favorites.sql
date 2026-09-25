-- =============================================================================
-- Migración: Añadir columna top5_order a la tabla favorites
-- Archivo: 20260925_add_top5_order_to_favorites.sql
-- Fecha: 2026-09-25
-- Descripción: Permite guardar el orden posicional exacto (0..4) de las
--              mezclas favoritas marcadas como Top 5 por cada usuario.
-- =============================================================================

ALTER TABLE public.favorites ADD COLUMN IF NOT EXISTS top5_order integer;
