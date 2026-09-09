{{ config(
    materialized='view',
    tags=['demo_showcase']
) }}

-- Leaf probe for Elementary TEST status=error (compile/runtime DB error).
-- Intentionally isolated: nothing depends on this model, so the error test
-- does not skip int_payments_broken / mart_payment_summary.
select 1::integer as probe_id
