-- 日次売上サマリーテーブル
-- 日ごとの売上、利益、注文数を集計

with orders as (
    select * from {{ ref('fct_orders') }}
),

daily_summary as (
    select
        order_date,
        count(distinct order_id) as total_orders,
        count(distinct customer_id) as unique_customers,
        sum(calculated_total) as daily_revenue,
        sum(total_cogs) as daily_cogs,
        sum(total_gross_profit) as daily_profit,
        avg(calculated_total) as avg_order_value,
        sum(total_quantity) as total_items_sold
    from orders
    group by order_date
),

final as (
    select
        order_date,
        -- 曜日情報を追加
        dayname(order_date) as day_of_week_name,
        total_orders,
        unique_customers,
        daily_revenue,
        daily_cogs,
        daily_profit,
        -- 利益率
        case
            when daily_revenue > 0
            then round(daily_profit * 1.0 / daily_revenue, 4)
            else 0
        end as profit_margin,
        avg_order_value,
        total_items_sold,
        -- 1顧客あたりの平均注文数
        case
            when unique_customers > 0
            then round(total_orders * 1.0 / unique_customers, 2)
            else 0
        end as orders_per_customer
    from daily_summary
)

select * from final
order by order_date
