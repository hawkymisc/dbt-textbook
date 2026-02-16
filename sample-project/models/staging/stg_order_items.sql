-- 注文明細データのステージングモデル
-- 生データから基本的なクリーニングと変換を行います

with source as (
    select * from {{ source('raw', 'order_items') }}
),

renamed as (
    select
        order_item_id,
        order_id,
        product_id,
        quantity,
        unit_price,
        -- 小計を計算
        (quantity * unit_price) as line_total,
        created_at
    from source
)

select * from renamed
