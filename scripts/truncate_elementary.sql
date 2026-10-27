-- Truncate all tables in schema `elementary` (Elementary Data sandbox).
-- Preserves table structure; only removes rows.
-- CASCADE handles FKs between Elementary tables.

DO $$
DECLARE
  r RECORD;
  truncated INT := 0;
BEGIN
  FOR r IN
    SELECT c.relname AS tablename
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'elementary'
      AND c.relkind = 'r'  -- ordinary tables only (skip views/matviews)
    ORDER BY c.relname
  LOOP
    EXECUTE format('TRUNCATE TABLE elementary.%I CASCADE', r.tablename);
    RAISE NOTICE 'truncated: elementary.%', r.tablename;
    truncated := truncated + 1;
  END LOOP;

  IF truncated = 0 THEN
    RAISE NOTICE 'No tables found in schema elementary';
  ELSE
    RAISE NOTICE 'Done: truncated % table(s) in elementary', truncated;
  END IF;
END $$;
