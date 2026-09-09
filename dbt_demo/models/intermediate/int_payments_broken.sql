{{ config(
    materialized='table',
    tags=['demo_showcase']
) }}

-- Intentional MODEL ERROR for Elementary Model Run Results (status = error).
-- References a column that does not exist on stg_payments.
select
    payment_id,
    order_id,
    payment_method,
    amount,
    nonexistent_column_for_demo_error as broken_metric
from {{ ref('stg_payments') }}
