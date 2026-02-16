-- 注文明細に商品情報を結合した中間モデル
-- 商品カテゴリや原価情報を追加します

with order_items as (
    select * from {{ ref('stg_order_items') }}
),

products as (
    select * from {{ ref('stg_products') }}
),

joined as (
    select
        oi.order_item_id,
        oi.order_id,
        oi.product_id,
        p.product_name,
        p.category,
        oi.quantity,
        oi.unit_price,
        p.cost as unit_cost,
        oi.line_total,
        -- 売上原価
        (oi.quantity * p.cost) as cost_of_goods_sold,
        -- 粗利益
        (oi.line_total - (oi.quantity * p.cost)) as gross_profit,
        oi.created_at
    from order_items oi
    left join products p on oi.product_id = p.product_id
)

select * from joined
