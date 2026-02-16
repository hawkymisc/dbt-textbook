-- 日付範囲フィルタを適用するマクロ

{% macro date_range_filter(date_column, start_var='start_date', end_var='end_date') %}
    {% if var(start_var, none) %}
        AND {{ date_column }} >= '{{ var(start_var) }}'
    {% endif %}
    {% if var(end_var, none) %}
        AND {{ date_column }} <= '{{ var(end_var) }}'
    {% endif %}
{% endmacro %}

-- 使用例:
-- SELECT * FROM {{ ref('stg_orders') }}
-- WHERE 1=1
--     {{ date_range_filter('order_date') }}
