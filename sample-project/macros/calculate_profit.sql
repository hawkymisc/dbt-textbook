-- 利益と利益率を計算するマクロ

{% macro calculate_profit(revenue, cost) %}
    ({{ revenue }} - {{ cost }}) as profit,
    ({{ revenue }} - {{ cost }}) * 1.0 / NULLIF({{ revenue }}, 0) as profit_margin
{% endmacro %}

-- 使用例:
-- SELECT
--     order_id,
--     {{ calculate_profit('total_amount', 'total_cost') }}
-- FROM {{ ref('fct_orders') }}
