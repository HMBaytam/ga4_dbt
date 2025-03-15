{{
    config(
        materialized = 'table',
        partitioned_by = {
            'field': 'event_date', 
            'data_type': 'date', 
            'granularity': 'day'
        },
        incremental_strategy = 'insert_overwrite',
        unique_key='event_id',
        on_schema_change = 'fail',
        tags=['incremental', 'daily']
    )
}}

    SELECT
        -- partitioning key:
        PARSE_DATE('%Y%m%d', occurrence_date) AS occurrence_date, -- equivalent to _table_suffix; convert to DATE type
        users_info,
        device,
        geo,
        audiences,
        user_properties,
        user_ltv,
        predictions,
        privacy_info,
        PARSE_DATE('%Y%m%d', last_update_date) AS last_update_date
    FROM
        {{ source('google_analytics', 'events') }}
{% if is_incremental() %}
    WHERE
           -- events from the 'intraday' tables should always be included
           _table_suffix LIKE 'intraday_%'
        OR (
           -- add/replace data from last daily partition onwards, regardless:
              PARSE_DATE('%Y%m%d', _table_suffix) >= DATE(_dbt_max_partition)
           -- add/replace data originally generated
           -- today, yesterday, or the day-before-yesterday
           -- (events_intraday data can be mutated on transfer to events)
           OR PARSE_DATE('%Y%m%d', _table_suffix) >= DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY)
           )
{% endif %}