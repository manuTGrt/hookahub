-- Migración de Endurecimiento para Producción: Tabla de Notificaciones y Supabase Realtime
-- 1. Habilitar Row Level Security (RLS)
alter table if exists notifications enable row level security;

-- 2. Asegurar políticas RLS optimizadas con subconsulta ((select auth.uid()) = user_id)
drop policy if exists "notifications_select_policy" on notifications;
create policy "notifications_select_policy"
  on notifications for select
  to authenticated
  using (((select auth.uid()) = user_id));

drop policy if exists "notifications_update_policy" on notifications;
create policy "notifications_update_policy"
  on notifications for update
  to authenticated
  using (((select auth.uid()) = user_id))
  with check (((select auth.uid()) = user_id));

drop policy if exists "notifications_delete_policy" on notifications;
create policy "notifications_delete_policy"
  on notifications for delete
  to authenticated
  using (((select auth.uid()) = user_id));

-- 3. Configurar REPLICA IDENTITY FULL para que Realtime emita payloads íntegros en updates y deletes
alter table if exists notifications replica identity full;

-- 4. Agregar de forma idempotente la tabla 'notifications' a la publicación 'supabase_realtime'
do $$
begin
  if not exists (
    select 1 from pg_publication_tables 
    where pubname = 'supabase_realtime' and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table notifications;
  end if;
end $$;

-- 5. Índices de rendimiento para consultas concurrentes de conteo y paginación
create index if not exists idx_notifications_user_created 
  on notifications (user_id, created_at desc);

create index if not exists idx_notifications_user_unread 
  on notifications (user_id, is_read) 
  where is_read = false;
