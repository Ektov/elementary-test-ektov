{{ config(
    materialized='view',
    tags=['demo_showcase']
) }}

select
    shipment_id::integer as shipment_id,
    order_id::integer as order_id,
    upper(trim(carrier))::varchar(50) as carrier,
    lower(trim(shipment_status))::varchar(50) as shipment_status,
    shipped_at::timestamp as shipped_at,
    _loaded_at::timestamp as loaded_at
-- Use ref() (not source) so Cosmos/Airflow create seed → staging dependencies
from {{ ref('raw_shipments') }}
