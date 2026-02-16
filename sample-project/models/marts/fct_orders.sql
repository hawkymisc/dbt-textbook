-- 注文ファクトテーブル
-- ビジネスユーザーが分析に使用する、完全に変換された注文データ

with orders_with_details as (
    select * from {{ ref('int_orders_with_details') }}
),

final as (
    select
        order_id,
        customer_id,
        customer_name,
        customer_email,
        order_status,
        -- 注文ステータスの日本語表示
        case order_status
            when 'pending' then '保留中'
            when 'shipped' then '発送済み'
            when 'completed' then '完了'
            when 'cancelled' then 'キャンセル'
            when 'returned' then '返品'
            else order_status
        end as order_status_ja,
        payment_method,
        shipping_address,
        total_amount,
        order_date,
        order_month,
        order_day_of_week,
        order_hour,
        item_count,
        total_quantity,
        calculated_total,
        total_cogs,
        total_gross_profit,
        gross_profit_margin,
        created_at,
        updated_at
    from orders_with_details
    -- 完了した注文のみを含める（必要に応じて条件を変更）
    where order_status in ('completed', 'shipped')
)

select * from final
