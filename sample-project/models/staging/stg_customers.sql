-- 顧客データのステージングモデル
-- 生データから基本的なクリーニングと変換を行います

with source as (
    select * from {{ source('raw', 'customers') }}
),

renamed as (
    select
        customer_id,
        first_name,
        last_name,
        -- フルネームを作成
        {{ dbt.concat(['first_name', "' '", 'last_name']) }} as full_name,
        email,
        created_at,
        updated_at
    from source
)

select * from renamed
