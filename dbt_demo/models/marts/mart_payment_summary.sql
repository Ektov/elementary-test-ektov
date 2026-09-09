{{ config(
    materialized='table',
    tags=['demo_showcase']
) }}

-- Downstream of int_payments_broken → SKIPPED on dbt build when upstream errors.
select
    payment_method,
    count(*) as payment_count,
    coalesce(sum(amount), 0)::numeric(12, 2) as total_amount
from {{ ref('int_payments_broken') }}
group by 1
