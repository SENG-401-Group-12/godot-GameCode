-- =============================================================================
-- Run this entire script in Supabase: SQL Editor → New query → Run.
-- Order matters: cleanup duplicates → unique constraint → functions.
-- =============================================================================

-- 1) Keep only each user's best run (highest score, then waves) so one row per user_id.
DELETE FROM public.runs r
WHERE r.ctid NOT IN (
	SELECT DISTINCT ON (user_id) ctid
	FROM public.runs
	ORDER BY user_id, score_total DESC, waves_completed DESC
);

-- 2) Enforce at most one stored run per account (required for upsert below).
DO $$
BEGIN
	IF NOT EXISTS (
		SELECT 1
		FROM pg_constraint
		WHERE conname = 'runs_user_id_unique'
	) THEN
		ALTER TABLE public.runs ADD CONSTRAINT runs_user_id_unique UNIQUE (user_id);
	END IF;
END $$;

-- 3) Submit: insert first score, or replace row only when the new score is strictly higher.
CREATE OR REPLACE FUNCTION public.submit_run_best(
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

	INSERT INTO public.runs (
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
	WHERE public.runs.score_total < EXCLUDED.score_total;
END;
$$;

-- 4) Leaderboard: top 10 users by best score (one row per user after migration).
CREATE OR REPLACE FUNCTION public.get_top_10()
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
	FROM public.runs r
	LEFT JOIN public.profiles p ON p.id = r.user_id
	ORDER BY r.score_total DESC, r.waves_completed DESC
	LIMIT 10;
$$;

-- 5) Personal best for the signed-in user (single row).
CREATE OR REPLACE FUNCTION public.get_personal_best(p_user_id uuid)
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
	FROM public.runs r
	WHERE r.user_id = p_user_id
	LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.submit_run_best(int, int, int, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_top_10() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_personal_best(uuid) TO authenticated;
