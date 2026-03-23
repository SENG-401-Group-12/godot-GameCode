-- =============================================================================
-- ONE-TIME: Clear all scores, then keep ONLY these three accounts (by display name).
-- Run in Supabase → SQL Editor.
--
-- Requires:
--   • public.runs with columns: user_id, score_total, duration_ms, waves_completed,
--     total_fed, total_missed
--   • public.profiles with id + display_name matching these players
--   • UNIQUE (user_id) on public.runs (from leaderboard_functions.sql)
--
-- If an INSERT inserts 0 rows, that display name was not found in profiles — fix the
-- name or create the profile first, then re-run just that INSERT block.
-- =============================================================================

DELETE FROM public.runs;

INSERT INTO public.runs (user_id, score_total, duration_ms, waves_completed, total_fed, total_missed)
SELECT p.id, 6650, 0, 9, 62, 6
FROM public.profiles p
WHERE p.display_name ILIKE 'nikolasic'
LIMIT 1;

INSERT INTO public.runs (user_id, score_total, duration_ms, waves_completed, total_fed, total_missed)
SELECT p.id, 5550, 0, 12, 50, 2
FROM public.profiles p
WHERE p.display_name ILIKE 'Mujtaba'
LIMIT 1;

INSERT INTO public.runs (user_id, score_total, duration_ms, waves_completed, total_fed, total_missed)
SELECT p.id, 5450, 0, 12, 49, 2
FROM public.profiles p
WHERE p.display_name ILIKE 'yassin'
LIMIT 1;

-- Verify (should be 3 rows if all profiles matched).
SELECT
	r.score_total,
	r.waves_completed,
	r.total_fed,
	r.total_missed,
	p.display_name
FROM public.runs r
LEFT JOIN public.profiles p ON p.id = r.user_id
ORDER BY r.score_total DESC;
