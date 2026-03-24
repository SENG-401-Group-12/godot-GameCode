-- =============================================================================
-- Endless mode leaderboard (separate from base `runs` table).
-- Run in Supabase SQL Editor after `leaderboard_functions.sql` exists.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.runs_endless (
	user_id uuid NOT NULL PRIMARY KEY,
	score_total int NOT NULL DEFAULT 0,
	duration_ms int NOT NULL DEFAULT 0,
	waves_completed int NOT NULL DEFAULT 0,
	total_fed int NOT NULL DEFAULT 0,
	total_missed int NOT NULL DEFAULT 0
);

CREATE OR REPLACE FUNCTION public.submit_run_best_endless(
	p_score_total int,
	p_duration_ms int,
	p_waves_completed int,
	p_total_fed int,
	p_total_missed int
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
	uid uuid := auth.uid();
BEGIN
	IF uid IS NULL THEN
		RAISE EXCEPTION 'Not authenticated';
	END IF;

	INSERT INTO public.runs_endless (
		user_id, score_total, duration_ms, waves_completed, total_fed, total_missed
	)
	VALUES (
		uid, p_score_total, p_duration_ms, p_waves_completed, p_total_fed, p_total_missed
	)
	ON CONFLICT (user_id) DO UPDATE SET
		score_total = EXCLUDED.score_total,
		duration_ms = EXCLUDED.duration_ms,
		waves_completed = EXCLUDED.waves_completed,
		total_fed = EXCLUDED.total_fed,
		total_missed = EXCLUDED.total_missed
	WHERE public.runs_endless.score_total < EXCLUDED.score_total;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_top_10_endless()
RETURNS TABLE (
	user_id text,
	display_name text,
	score_total int,
	waves_completed int,
	total_fed int,
	total_missed int
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
	SELECT
		r.user_id::text AS user_id,
		COALESCE(p.display_name, r.user_id::text) AS display_name,
		r.score_total,
		r.waves_completed,
		r.total_fed,
		r.total_missed
	FROM public.runs_endless r
	LEFT JOIN public.profiles p ON p.id = r.user_id
	ORDER BY r.score_total DESC, r.waves_completed DESC
	LIMIT 10;
$$;

CREATE OR REPLACE FUNCTION public.get_personal_best_endless(p_user_id uuid)
RETURNS TABLE (
	score_total int,
	waves_completed int,
	total_fed int,
	total_missed int
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
	SELECT
		r.score_total,
		r.waves_completed,
		r.total_fed,
		r.total_missed
	FROM public.runs_endless r
	WHERE r.user_id = p_user_id
	LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.submit_run_best_endless(int, int, int, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_top_10_endless() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_personal_best_endless(uuid) TO authenticated;
