{{ config(
    materialized='table',
    tags=['demo_showcase'],
    contract={'enforced': true}
) }}

-- Leaf demo: enforced model contract that FAILS at run.
-- YAML declares amount as integer, but SQL returns numeric → contract breach → model error.
select
    1::integer as contract_id,
    'broken'::varchar(50) as status,
    10.50::numeric(12, 2) as amount
