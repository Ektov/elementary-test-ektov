{{ config(
    materialized='table',
    tags=['demo_showcase'],
    contract={'enforced': true}
) }}

-- Leaf demo: enforced model contract that PASSES (columns + types match YAML).
select
    1::integer as contract_id,
    'ok'::varchar(50) as status,
    10.50::numeric(12, 2) as amount
