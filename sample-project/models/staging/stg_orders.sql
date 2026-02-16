-- 注文データのステージングモデル
-- 生データから基本的なクリーニングと変換を行います

with source as (
    select * from {{ source('raw', 'orders') }}
),

renamed as (
    select
        order_id,
        customer_id,
        order_status,
        payment_method,
        shipping_address,
        total_amount,
        -- 注文日時から日付部分を抽出
        date(created_at) as order_date,
        -- 注文日時から年月を抽出
        date_trunc('month', created_at) as order_month,
        -- 曜日を抽出（0=日曜日、6=土曜日）
        dayofweek(created_at) as order_day_of_week,
        -- 時間帯を抽出
        hour(created_at) as order_hour,
        created_at,
        updated_at
    from source
)

select * from renamed
