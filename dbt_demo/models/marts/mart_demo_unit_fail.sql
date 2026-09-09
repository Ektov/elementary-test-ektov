{{ config(
    materialized='table',
    tags=['demo_showcase']
) }}

-- Leaf target for the intentionally FAILING unit test.
-- On dbt build the unit test fails first, so this model is skipped —
-- that is expected and keeps dim_customers / fct_orders successful.
select
    1::integer as demo_id,
    100.00::numeric(12, 2) as amount
