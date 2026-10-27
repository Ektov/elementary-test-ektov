{{ config(
    meta={
        "is_incremental": false,
        "impact": "medium",
        "dimension": "freshness",
        "description": "Fact orders should not have updated_at in the last 24 hours",
        "test_sample_row_count": 2
    }
) }}

select *
from {{ ref('fct_orders') }}
where updated_at > current_date - interval '24 hour'
