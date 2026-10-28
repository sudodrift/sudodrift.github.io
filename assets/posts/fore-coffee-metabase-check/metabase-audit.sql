-- metabase-audit.sql: read-only questions for the Metabase application database
-- (Postgres). Run as a read-only role. Change the date to when your exposure began.
-- Column names can drift between versions; if one errors, \d the table and adjust.

-- 1. Admins, newest first. Anyone you don't recognise, or a join date after Aug 6?
SELECT id, email, is_superuser, is_active, date_joined, last_login, updated_at
FROM core_user WHERE is_superuser ORDER BY date_joined DESC;

-- 2. API keys. Every key should have an owner you can name.
SELECT id, name, key_prefix, created_at, creator_id, updated_at FROM api_key ORDER BY created_at DESC;

-- 3. What changed since the advisory (audit_log exists on recent builds). Topic
-- names vary by version, so count them first, then read the rows for any that
-- touch users, passwords, API keys or settings.
SELECT topic, count(*) FROM audit_log WHERE timestamp > '2026-08-06' GROUP BY topic ORDER BY 2 DESC;
SELECT timestamp, topic, user_id, model, model_id FROM audit_log
WHERE timestamp > '2026-08-06' ORDER BY timestamp DESC LIMIT 200;

-- 4. Big pulls: exports and queries that returned a lot of rows.
SELECT started_at, executor_id, database_id, context, result_rows, native
FROM query_execution
WHERE started_at > '2026-08-06' AND (context::text ILIKE '%download%' OR result_rows > 100000)
ORDER BY result_rows DESC LIMIT 100;

-- 5. Anything shared by public link, which needs no login at all.
SELECT 'card' AS kind, id, name, public_uuid FROM report_card WHERE public_uuid IS NOT NULL
UNION ALL
SELECT 'dashboard', id, name, public_uuid FROM report_dashboard WHERE public_uuid IS NOT NULL;
