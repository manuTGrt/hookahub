-- 1. Create the statistics table
CREATE TABLE IF NOT EXISTS public.app_statistics (
  id int PRIMARY KEY DEFAULT 1 CHECK (id = 1), -- Ensure only one row exists
  total_tobaccos int NOT NULL DEFAULT 0,
  total_mixes int NOT NULL DEFAULT 0,
  total_users int NOT NULL DEFAULT 0
);

-- 2. Insert initial row based on current counts
INSERT INTO public.app_statistics (id, total_tobaccos, total_mixes, total_users)
VALUES (
  1,
  (SELECT count(*) FROM public.tobaccos),
  (SELECT count(*) FROM public.mixes),
  (SELECT count(*) FROM public.profiles)
)
ON CONFLICT (id) DO UPDATE SET
  total_tobaccos = EXCLUDED.total_tobaccos,
  total_mixes = EXCLUDED.total_mixes,
  total_users = EXCLUDED.total_users;

-- 3. Enable Realtime for the table
ALTER PUBLICATION supabase_realtime ADD TABLE public.app_statistics;

-- 4. Enable RLS and add public select policy
ALTER TABLE public.app_statistics ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public select on app_statistics"
ON public.app_statistics
FOR SELECT
TO public, authenticated
USING (true);

-- 5. Create Trigger Functions to update statistics

-- Tobaccos
CREATE OR REPLACE FUNCTION public.update_statistics_tobaccos()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.app_statistics SET total_tobaccos = total_tobaccos + 1 WHERE id = 1;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.app_statistics SET total_tobaccos = total_tobaccos - 1 WHERE id = 1;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS update_tobaccos_stat_trigger ON public.tobaccos;
CREATE TRIGGER update_tobaccos_stat_trigger
AFTER INSERT OR DELETE ON public.tobaccos
FOR EACH ROW EXECUTE FUNCTION public.update_statistics_tobaccos();

-- Mixes
CREATE OR REPLACE FUNCTION public.update_statistics_mixes()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.app_statistics SET total_mixes = total_mixes + 1 WHERE id = 1;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.app_statistics SET total_mixes = total_mixes - 1 WHERE id = 1;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS update_mixes_stat_trigger ON public.mixes;
CREATE TRIGGER update_mixes_stat_trigger
AFTER INSERT OR DELETE ON public.mixes
FOR EACH ROW EXECUTE FUNCTION public.update_statistics_mixes();

-- Profiles (Users)
CREATE OR REPLACE FUNCTION public.update_statistics_users()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.app_statistics SET total_users = total_users + 1 WHERE id = 1;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.app_statistics SET total_users = total_users - 1 WHERE id = 1;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS update_users_stat_trigger ON public.profiles;
CREATE TRIGGER update_users_stat_trigger
AFTER INSERT OR DELETE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.update_statistics_users();
