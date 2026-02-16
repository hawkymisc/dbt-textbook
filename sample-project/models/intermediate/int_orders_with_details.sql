-- 注文に顧客情報と注文明細の集計を結合した中間モデル
-- 1注文につき1行の形式で、関連情報を全て含みます

with orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

order_items as (
    select * from {{ ref('int_order_items_with_product') }}
),

-- 注文ごとの集計
order_summary as (
    select
        order_id,
        count(*) as item_count,
        sum(quantity) as total_quantity,
        sum(line_total) as calculated_total,
        sum(cost_of_goods_sold) as total_cogs,
        sum(gross_profit) as total_gross_profit
    from order_items
    group by order_id
),

-- 全てを結合
joined as (
    select
        o.order_id,
        o.customer_id,
        c.full_name as customer_name,
        c.email as customer_email,
        o.order_status,
        o.payment_method,
        o.shipping_address,
        o.total_amount,
        o.order_date,
        o.order_month,
        o.order_day_of_week,
        o.order_hour,
        o.created_at,
        o.updated_at,
        os.item_count,
        os.total_quantity,
        os.calculated_total,
        os.total_cogs,
        os.total_gross_profit,
        -- 粗利率
        case
            when os.calculated_total > 0
            then round(os.total_gross_profit * 1.0 / os.calculated_total, 4)
            else 0
        end as gross_profit_margin
    from orders o
    left join customers c on o.customer_id = c.customer_id
    left join order_summary os on o.order_id = os.order_id
)

select * from joined
