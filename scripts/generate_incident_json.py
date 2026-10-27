#!/usr/bin/env python3
"""Query Elementary failed tests from Postgres and print incident JSON per row.

Uses the same Postgres as the project Postgres MCP / dbt profile
(localhost:5432, demo_db, postgres/postgres). Override via PG* env vars.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys

SQL = """
select tr.test_unique_id,
       tr.invocation_id,
       tr.test_name,
       tr.test_short_name,
       tr.column_name,
       concat_ws('.', tr.database_name, tr.schema_name, tr.table_name) as full_table_name,
       tr.test_results_description,
       dt.description,
       tr.test_results_query,
       tr.severity,
        case
           when tr.severity ilike 'error' then '01JRXJBDH6KWXGZY63DJB7Z7WG'
           else '01JRXJBDH6V46GDFT3JZ19G325'
       end as severity_id,
        case
               when tr.severity ilike 'error' then 'Critical'
               else 'Major'
       end as severity_level,
       tr.status,
       tr.failures,
       (nullif(dm.owner, '')::jsonb ->> 0) as owner,
       dt.quality_dimension,
       dt.test_original_name
from elementary.elementary_test_results tr
left join elementary.dbt_models dm on tr.model_unique_id = dm.unique_id
left join elementary.dbt_tests dt on tr.test_unique_id = dt.unique_id
where tr.test_results_query ilike '%where%'
  and status <> 'pass'
"""

# Wrap as JSON array for stable parsing via psql.
SQL_AS_JSON = f"""
select coalesce(json_agg(row_to_json(q)), '[]'::json)
from (
{SQL}
) q
"""


def _val(value) -> str:
    if value is None:
        return ""
    return str(value)


def _clean_sql(value) -> str:
    """Strip leading/trailing blank lines and whitespace from test SQL."""
    return _val(value).strip()


def fetch_rows() -> list[dict]:
    env = os.environ.copy()
    env.setdefault("PGHOST", "localhost")
    env.setdefault("PGPORT", "5432")
    env.setdefault("PGDATABASE", "demo_db")
    env.setdefault("PGUSER", "postgres")
    env.setdefault("PGPASSWORD", "postgres")

    result = subprocess.run(
        [
            "psql",
            "-v",
            "ON_ERROR_STOP=1",
            "-t",
            "-A",
            "-c",
            SQL_AS_JSON,
        ],
        capture_output=True,
        text=True,
        env=env,
        check=False,
    )
    if result.returncode != 0:
        print(result.stderr.strip() or "psql failed", file=sys.stderr)
        raise SystemExit(result.returncode)

    payload = result.stdout.strip()
    if not payload:
        return []
    return json.loads(payload)


def build_incident(row: dict) -> dict:
    full_table_name = _val(row.get("full_table_name"))
    column_name = _val(row.get("column_name"))
    test_short_name = _val(row.get("test_short_name"))
    severity_level = _val(row.get("severity_level"))
    severity_id = _val(row.get("severity_id"))
    sql_query = _clean_sql(row.get("test_results_query"))

    title = (
        f"[AUTO][INCIDENT] {severity_level} / datamart / {full_table_name} "
        f"/ {test_short_name} for {column_name}"
    )

    description = (
        f"Test description: {_val(row.get('description'))}\n"
        f"\n"
        f"Test result description: {_val(row.get('test_results_description'))}\n"
        f"\n"
        f"Affected column: {column_name}\n"
        f"\n"
        f"SQL:\n"
        f"\n"
        f"```\n"
        f"{sql_query}\n"
        f"```\n"
        f"\n"
        f"Expected result: 0\n"
        f"\n"
        f"Actual result: {_val(row.get('failures'))}"
    )

    return {
        "title": title,
        "description": description,
        "deduplication_key": (
            f"{_val(row.get('test_unique_id'))}_{_val(row.get('invocation_id'))}"
        ),
        "status": "firing",
        "metadata": {
            "table": full_table_name,
            "owner": _val(row.get("owner")),
            "severity": severity_id,
        },
    }


def main() -> int:
    rows = fetch_rows()
    if not rows:
        print("No matching failed tests found.", file=sys.stderr)
        return 0

    for row in rows:
        print(json.dumps(build_incident(row), ensure_ascii=False, indent=2))
        print()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
