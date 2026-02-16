-- 商品データのスナップショット
-- 価格変更の履歴を管理します

{% snapshot products_snapshot %}

{{
    config(
        target_schema='snapshots',
        unique_key='product_id',
        strategy='check',
        check_cols=['product_name', 'category', 'price', 'cost'],
        invalidate_hard_deletes=True
    )
}}

SELECT * FROM {{ source('raw', 'products') }}

{% endsnapshot %}
