-- 商品データのステージングモデル
-- 生データから基本的なクリーニングと変換を行います

with source as (
    select * from {{ source('raw', 'products') }}
),

renamed as (
    select
        product_id,
        product_name,
        category,
        price,
        cost,
        -- 利益率を計算
        round((price - cost) * 1.0 / price, 4) as profit_margin,
        -- 利益額を計算
        (price - cost) as profit_amount,
        created_at,
        updated_at
    from source
)

select * from renamed
