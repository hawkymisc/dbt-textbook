-- 顧客ディメンションテーブル
-- 顧客ごとの購入行動を集計した分析用テーブル

with customers as (
    select * from {{ ref('stg_customers') }}
),

orders as (
    select * from {{ ref('int_orders_with_details') }}
),

-- 顧客ごとの注文集計
customer_orders as (
    select
        customer_id,
        count(*) as total_orders,
        count(case when order_status = 'completed' then 1 end) as completed_orders,
        count(case when order_status = 'cancelled' then 1 end) as cancelled_orders,
        count(case when order_status = 'returned' then 1 end) as returned_orders,
        sum(calculated_total) as lifetime_value,
        sum(total_gross_profit) as total_profit,
        avg(calculated_total) as avg_order_value,
        min(order_date) as first_order_date,
        max(order_date) as last_order_date,
        -- 初回購入からの日数
        datediff('day', min(order_date), max(order_date)) as customer_tenure_days
    from orders
    group by customer_id
),

-- 全てを結合
final as (
    select
        c.customer_id,
        c.full_name,
        c.email,
        c.created_at as customer_created_at,
        co.total_orders,
        coalesce(co.completed_orders, 0) as completed_orders,
        coalesce(co.cancelled_orders, 0) as cancelled_orders,
        coalesce(co.returned_orders, 0) as returned_orders,
        coalesce(co.lifetime_value, 0) as lifetime_value,
        coalesce(co.total_profit, 0) as total_profit,
        coalesce(co.avg_order_value, 0) as avg_order_value,
        co.first_order_date,
        co.last_order_date,
        coalesce(co.customer_tenure_days, 0) as customer_tenure_days,
        -- 顧客セグメント
        case
            when co.lifetime_value >= 50000 then 'VIP'
            when co.lifetime_value >= 20000 then 'Regular'
            when co.lifetime_value > 0 then 'New'
            else 'No Purchase'
        end as customer_segment
    from customers c
    left join customer_orders co on c.customer_id = co.customer_id
)

select * from final
