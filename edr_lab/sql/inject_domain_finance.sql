-- Synthetic "second domain" project rows for the edr multi-project experiment.
-- Clones a slice of dbt_demo artifacts into package/project domain_finance.

BEGIN;

CREATE TEMP TABLE _lab AS
SELECT 'domain_finance'::text AS pkg,
       'inv_domain_finance_lab_001'::text AS inv_id,
       now() AS ts;

-- 1) Invocation
INSERT INTO elementary.dbt_invocations (
  invocation_id, job_id, job_name, job_run_id,
  run_started_at, run_completed_at, generated_at, created_at,
  command, dbt_version, elementary_version, full_refresh,
  invocation_vars, vars, target_name, target_database, target_schema,
  target_profile_name, threads, selected, yaml_selector,
  project_id, project_name, env, env_id,
  cause_category, cause, pull_request_id, git_sha, orchestrator,
  dbt_user, job_url, job_run_url, account_id, target_adapter_specific_fields
)
SELECT
  (_lab.inv_id),
  'job_domain_finance',
  'domain_finance_dbt_build',
  'run_domain_finance_001',
  to_char(_lab.ts - interval '10 minutes', 'YYYY-MM-DD HH24:MI:SS'),
  to_char(_lab.ts, 'YYYY-MM-DD HH24:MI:SS'),
  to_char(_lab.ts, 'YYYY-MM-DD HH24:MI:SS'),
  _lab.ts,
  'build',
  src.dbt_version,
  src.elementary_version,
  false,
  '{}',
  '{}',
  'prod',
  'edr_lab',
  'finance_marts',
  'domain_finance',
  4,
  '[]',
  NULL,
  'domain_finance_project_id',
  'domain_finance',
  'prod',
  'lab',
  'manual',
  'synthetic multi-project experiment',
  NULL,
  'deadbeef',
  'docker',
  'lab_user',
  NULL,
  NULL,
  NULL,
  '{}'
FROM elementary.dbt_invocations src, _lab
ORDER BY src.created_at DESC NULLS LAST
LIMIT 1;

-- 2) Models (non-elementary only)
INSERT INTO elementary.dbt_models (
  unique_id, alias, checksum, materialization, tags, meta, owner,
  database_name, schema_name, depends_on_macros, depends_on_nodes,
  description, name, package_name, original_path, path, patch_path,
  generated_at, metadata_hash, unique_key, incremental_strategy,
  group_name, access
)
SELECT
  replace(unique_id, 'dbt_demo', 'domain_finance'),
  alias,
  checksum,
  materialization,
  tags,
  meta,
  'finance_owner',
  'edr_lab',
  CASE
    WHEN schema_name = 'dbt_marts' THEN 'finance_marts'
    WHEN schema_name = 'dbt_test' THEN 'finance_staging'
    ELSE schema_name
  END,
  replace(coalesce(depends_on_macros, ''), 'dbt_demo', 'domain_finance'),
  replace(coalesce(depends_on_nodes, ''), 'dbt_demo', 'domain_finance'),
  coalesce(description, '') || ' [synthetic domain_finance]',
  name,
  'domain_finance',
  replace(coalesce(original_path, ''), 'dbt_demo', 'domain_finance'),
  path,
  patch_path,
  to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SS'),
  md5(unique_id || 'domain_finance'),
  unique_key,
  incremental_strategy,
  'finance',
  access
FROM elementary.dbt_models
WHERE package_name = 'dbt_demo';

-- 3) Sources
INSERT INTO elementary.dbt_sources (
  unique_id, database_name, schema_name, source_name, name, identifier,
  loaded_at_field, freshness_warn_after, freshness_error_after, freshness_filter,
  freshness_description, relation_name, tags, meta, owner, package_name,
  original_path, path, source_description, description, generated_at, metadata_hash
)
SELECT
  replace(unique_id, 'dbt_demo', 'domain_finance'),
  'edr_lab',
  'finance_raw',
  source_name || '_finance',
  name,
  identifier,
  loaded_at_field,
  freshness_warn_after,
  freshness_error_after,
  freshness_filter,
  freshness_description,
  replace(coalesce(relation_name, ''), 'dbt_demo', 'domain_finance'),
  tags,
  meta,
  'finance_owner',
  'domain_finance',
  original_path,
  path,
  coalesce(source_description, '') || ' [synthetic domain_finance]',
  description,
  to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SS'),
  md5(unique_id || 'domain_finance')
FROM elementary.dbt_sources
WHERE package_name = 'dbt_demo' OR unique_id LIKE '%dbt_demo%';

-- Fallback: clone all sources if package filter matched nothing unusual
INSERT INTO elementary.dbt_sources (
  unique_id, database_name, schema_name, source_name, name, identifier,
  loaded_at_field, freshness_warn_after, freshness_error_after, freshness_filter,
  freshness_description, relation_name, tags, meta, owner, package_name,
  original_path, path, source_description, description, generated_at, metadata_hash
)
SELECT
  replace(unique_id, split_part(unique_id, '.', 2), 'domain_finance'),
  'edr_lab',
  'finance_raw',
  source_name || '_finance',
  name,
  identifier,
  loaded_at_field,
  freshness_warn_after,
  freshness_error_after,
  freshness_filter,
  freshness_description,
  relation_name,
  tags,
  meta,
  'finance_owner',
  'domain_finance',
  original_path,
  path,
  coalesce(source_description, '') || ' [synthetic domain_finance]',
  description,
  to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SS'),
  md5(unique_id || 'domain_finance_v2')
FROM elementary.dbt_sources s
WHERE NOT EXISTS (
  SELECT 1 FROM elementary.dbt_sources x
  WHERE x.unique_id = replace(s.unique_id, split_part(s.unique_id, '.', 2), 'domain_finance')
)
AND s.package_name IS DISTINCT FROM 'domain_finance';

-- 4) Tests tied to dbt_demo models
INSERT INTO elementary.dbt_tests (
  unique_id, database_name, schema_name, name, short_name, alias,
  test_column_name, severity, warn_if, error_if, test_params, test_namespace,
  test_original_name, tags, model_tags, model_owners, meta,
  depends_on_macros, depends_on_nodes, parent_model_unique_id, description,
  package_name, type, original_path, path, generated_at, metadata_hash,
  quality_dimension, group_name
)
SELECT
  replace(unique_id, 'dbt_demo', 'domain_finance'),
  'edr_lab',
  CASE
    WHEN schema_name = 'dbt_marts' THEN 'finance_marts'
    WHEN schema_name = 'dbt_test' THEN 'finance_staging'
    ELSE coalesce(schema_name, 'finance_marts')
  END,
  name,
  short_name,
  alias,
  test_column_name,
  severity,
  warn_if,
  error_if,
  test_params,
  test_namespace,
  test_original_name,
  tags,
  model_tags,
  'finance_owner',
  meta,
  replace(coalesce(depends_on_macros, ''), 'dbt_demo', 'domain_finance'),
  replace(coalesce(depends_on_nodes, ''), 'dbt_demo', 'domain_finance'),
  replace(coalesce(parent_model_unique_id, ''), 'dbt_demo', 'domain_finance'),
  coalesce(description, '') || ' [synthetic domain_finance]',
  'domain_finance',
  type,
  original_path,
  path,
  to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SS'),
  md5(unique_id || 'domain_finance'),
  quality_dimension,
  'finance'
FROM elementary.dbt_tests
WHERE package_name = 'dbt_demo'
   OR unique_id LIKE '%.dbt_demo.%'
   OR parent_model_unique_id LIKE '%.dbt_demo.%';

-- 5) Latest test results per test for dbt_demo → clone as domain_finance
WITH latest AS (
  SELECT DISTINCT ON (test_unique_id) *
  FROM elementary.elementary_test_results
  WHERE test_unique_id LIKE '%.dbt_demo.%'
     OR model_unique_id LIKE '%.dbt_demo.%'
  ORDER BY test_unique_id, detected_at DESC NULLS LAST
)
INSERT INTO elementary.elementary_test_results (
  id, data_issue_id, test_execution_id, test_unique_id, model_unique_id,
  invocation_id, detected_at, created_at, database_name, schema_name,
  table_name, column_name, test_type, test_sub_type, test_results_description,
  owners, tags, test_results_query, other, test_name, test_params, severity,
  status, failures, test_short_name, test_alias, result_rows, failed_row_count
)
SELECT
  md5(id || 'domain_finance'),
  data_issue_id,
  'exec_finance_' || md5(coalesce(test_execution_id, id)),
  replace(test_unique_id, 'dbt_demo', 'domain_finance'),
  replace(coalesce(model_unique_id, ''), 'dbt_demo', 'domain_finance'),
  (SELECT inv_id FROM _lab),
  now() - interval '5 minutes',
  now() - interval '5 minutes',
  'edr_lab',
  CASE
    WHEN schema_name = 'dbt_marts' THEN 'finance_marts'
    WHEN schema_name = 'dbt_test' THEN 'finance_staging'
    ELSE coalesce(schema_name, 'finance_marts')
  END,
  table_name,
  column_name,
  test_type,
  test_sub_type,
  coalesce(test_results_description, '') || ' [synthetic domain_finance]',
  'finance_owner',
  tags,
  test_results_query,
  other,
  test_name,
  test_params,
  severity,
  status,
  failures,
  test_short_name,
  test_alias,
  result_rows,
  failed_row_count
FROM latest;

-- 6) Run results for finance models + tests (latest per unique_id)
WITH latest_rr AS (
  SELECT DISTINCT ON (unique_id) *
  FROM elementary.dbt_run_results
  WHERE unique_id LIKE '%.dbt_demo.%'
  ORDER BY unique_id, created_at DESC NULLS LAST
)
INSERT INTO elementary.dbt_run_results (
  model_execution_id, unique_id, invocation_id, generated_at, created_at,
  name, message, status, resource_type, execution_time,
  execute_started_at, execute_completed_at, compile_started_at, compile_completed_at,
  rows_affected, full_refresh, compiled_code, failures, query_id, thread_id,
  materialization, adapter_response, group_name
)
SELECT
  'exec_finance_' || md5(coalesce(model_execution_id, unique_id)),
  replace(unique_id, 'dbt_demo', 'domain_finance'),
  (SELECT inv_id FROM _lab),
  to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SS'),
  now() - interval '5 minutes',
  name,
  coalesce(message, '') || ' [synthetic domain_finance]',
  status,
  resource_type,
  execution_time,
  execute_started_at,
  execute_completed_at,
  compile_started_at,
  compile_completed_at,
  rows_affected,
  full_refresh,
  compiled_code,
  failures,
  query_id,
  thread_id,
  materialization,
  adapter_response,
  'finance'
FROM latest_rr;

-- 7) Source freshness clone (if any)
INSERT INTO elementary.dbt_source_freshness_results (
  source_freshness_execution_id, unique_id, max_loaded_at, snapshotted_at,
  generated_at, created_at, max_loaded_at_time_ago_in_s, status, error,
  compile_started_at, compile_completed_at, execute_started_at, execute_completed_at,
  invocation_id, warn_after, error_after, filter
)
SELECT
  'exec_finance_fresh_' || md5(coalesce(source_freshness_execution_id, unique_id)),
  regexp_replace(unique_id, '\.[^.]+\.', '.domain_finance.', 1),
  max_loaded_at,
  snapshotted_at,
  to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SS'),
  now() - interval '5 minutes',
  max_loaded_at_time_ago_in_s,
  status,
  error,
  compile_started_at,
  compile_completed_at,
  execute_started_at,
  execute_completed_at,
  (SELECT inv_id FROM _lab),
  warn_after,
  error_after,
  filter
FROM elementary.dbt_source_freshness_results src
WHERE unique_id NOT LIKE '%.domain_finance.%'
  AND NOT EXISTS (
    SELECT 1
    FROM elementary.dbt_source_freshness_results x
    WHERE x.unique_id = regexp_replace(src.unique_id, '\.[^.]+\.', '.domain_finance.', 1)
  );

COMMIT;

-- Summary
SELECT 'invocations_by_project' AS metric, project_name AS key, count(*)::text AS value
FROM elementary.dbt_invocations GROUP BY 1, 2
UNION ALL
SELECT 'models_by_package', package_name, count(*)::text
FROM elementary.dbt_models GROUP BY 1, 2
UNION ALL
SELECT 'tests_by_package', package_name, count(*)::text
FROM elementary.dbt_tests GROUP BY 1, 2
UNION ALL
SELECT 'test_results_domain_finance', 'rows',
       count(*)::text
FROM elementary.elementary_test_results
WHERE test_unique_id LIKE '%domain_finance%'
ORDER BY 1, 2;
