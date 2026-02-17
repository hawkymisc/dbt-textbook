---
title: "1. 高度なマテリアライゼーション"
---

# 1. 高度なマテリアライゼーション

この章では、インクリメンタルマテリアライゼーションと、より高度な設定について学びます。

## 1-1. インクリメンタルマテリアライゼーションの基礎

### なぜインクリメンタルか

大規模なデータセットで `table` マテリアライゼーションを使用すると：

```
問題:
- 毎回全件再作成で時間がかかる
- リソースを大量に消費
- コストが増大
```

インクリメンタルマテリアライゼーションなら：

```
解決:
- 初回は全件作成
- 2回目以降は増分のみ処理
- 高速で効率的
```

### 基本的な構文

```sql
-- models/marts/fct_orders_incremental.sql
{{ config(
    materialized='incremental',
    unique_key='order_id'
) }}

select
    order_id,
    customer_id,
    total_amount,
    updated_at
from {{ source('raw', 'orders') }}

{% if is_incremental() %}
-- 前回実行以降に更新されたレコードのみ
where updated_at > (select max(updated_at) from {{ this }})
{% endif %}
```

## 1-2. is_incremental()マクロ

`is_incremental()` は、モデルが既に存在し、増分更新モードで実行されている場合に `true` を返します。

```sql
{% if is_incremental() %}
-- 増分更新時の条件
where updated_at > (select max(updated_at) from {{ this }})
{% endif %}
```

### 実行の流れ

```
1回目（初回）:
- is_incremental() = false
- WHERE句なし
- 全件をテーブルに作成

2回目以降:
- is_incremental() = true
- WHERE句あり
- 増分データのみを追加/更新
```

## 1-3. unique_keyの理解

`unique_key` は、レコードを一意に識別するキーです。

### 挙動

```sql
{{ config(
    materialized='incremental',
    unique_key='order_id',
    incremental_strategy='merge'  -- BigQuery/Snowflakeのデフォルト
) }}
```

:::message
**重要**: `unique_key` は `incremental_strategy='merge'`（デフォルト）または `insert_overwrite` の場合のみ重複排除に有効です。`append` 戦略では重複が解消されないため注意してください。
:::

- 同じ `unique_key` のレコードが存在する場合 → **更新**
- 存在しない場合 → **挿入**

### 複合キー

```sql
{{ config(
    materialized='incremental',
    unique_key=['customer_id', 'order_date']
) }}
```

## 1-4. インクリメンタルの戦略

### 戦略1: 時間ベース（最も一般的）

```sql
{{ config(materialized='incremental') }}

select * from {{ source('raw', 'orders') }}

{% if is_incremental() %}
where updated_at > (select max(updated_at) from {{ this }})
{% endif %}
```

### 戦略2: 一意キーベース（merge戦略と組み合わせ）

```sql
{{ config(
    materialized='incremental',
    unique_key='order_id',
    incremental_strategy='merge'  -- 明示的に指定
) }}

select * from {{ source('raw', 'orders') }}

{% if is_incremental() %}
-- ソースから増分のみ取得
where updated_at > (select coalesce(max(updated_at), '1900-01-01') from {{ this }})
{% endif %}
```

:::message
`unique_key` と `incremental_strategy='merge'` を組み合わせると、増分データ内の重複のみを制御します。ソース全体をスキャンしないよう `is_incremental()` で条件を絞ることを推奨します。
:::

### 戦略3: ハッシュベース（変更検出）

```sql
{{ config(
    materialized='incremental',
    unique_key='order_id',
    on_schema_change='append_new_columns'
) }}

with source as (
    select
        order_id,
        customer_id,
        total_amount,
        -- レコード全体のハッシュ
        {{ dbt_utils.generate_surrogate_key(['order_id', 'customer_id', 'total_amount']) }} as record_hash
    from {{ source('raw', 'orders') }}
),

existing as (
    select order_id, record_hash
    from {{ this }}
)

select s.*
from source s
{% if is_incremental() %}
left join existing e on s.order_id = e.order_id
where e.order_id is null  -- 新規レコード
   or s.record_hash != e.record_hash  -- 変更あり
{% endif %}
```

## 1-5. BigQuery固有の設定

### パーティション + インクリメンタル

```sql
{{ config(
    materialized='incremental',
    partition_by={
      "field": "order_date",
      "data_type": "date",
      "granularity": "day"
    },
    cluster_by=['customer_id'],
    require_partition_filter=true
) }}

select * from {{ source('raw', 'orders') }}

{% if is_incremental() %}
where order_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
{% endif %}
```

### 増分戦略（BigQuery）

```sql
{{ config(
    materialized='incremental',
    incremental_strategy='merge',  -- デフォルト
    unique_key='order_id'
) }}
```

| 戦略 | 説明 |
|-----|------|
| `merge` | MERGE文を使用（デフォルト） |
| `insert_overwrite` | パーティションごとに置き換え |
| `append` | 単純に追加 |

### insert_overwriteの例

```sql
{{ config(
    materialized='incremental',
    incremental_strategy='insert_overwrite',
    partition_by={
      "field": "order_date",
      "data_type": "date",
      "granularity": "day"
    }
) }}

select * from {{ source('raw', 'orders') }}

{% if is_incremental() %}
where order_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
{% endif %}
```

## 1-6. DuckDBのインクリメンタル

```sql
{{ config(
    materialized='incremental',
    unique_key='order_id'
) }}

select * from {{ source('raw', 'orders') }}

{% if is_incremental() %}
where updated_at > (select coalesce(max(updated_at), '1900-01-01') from {{ this }})
{% endif %}
```

## 1-7. スキーマ変更の対応

`on_schema_change` でスキーマ変更時の挙動を制御します：

```sql
{{ config(
    materialized='incremental',
    unique_key='order_id',
    on_schema_change='append_new_columns'
) }}
```

| 値 | 挙動 |
|---|------|
| `ignore` | スキーマ変更を無視（デフォルト） |
| `fail` | スキーマ変更でエラー |
| `append_new_columns` | 新規カラムを追加 |
| `sync_all_columns` | カラムを同期（追加・削除） |

## 1-8. フルリフレッシュ

インクリメンタルモデルを完全に再作成する場合：

```bash
# 特定のモデルをフルリフレッシュ
dbt run --select fct_orders_incremental --full-refresh

# 全モデルをフルリフレッシュ
dbt run --full-refresh
```

### フルリフレッシュが必要な場面

- ソースデータの修正
- モデルロジックの大幅な変更
- スキーマ変更
- インクリメンタルロジックのバグ修正

## 1-9. インクリメンタルのベストプラクティス

### DO（推奨）

```sql
-- ✅ 更新日時カラムを使用
{% if is_incremental() %}
where updated_at > (select max(updated_at) from {{ this }})
{% endif %}

-- ✅ unique_keyを設定
{{ config(materialized='incremental', unique_key='order_id') }}

-- ✅ 定期的なフルリフレッシュを計画

-- ✅ パーティショニングを活用（BigQuery）
{{ config(
    materialized='incremental',
    partition_by={"field": "order_date", "data_type": "date"}
) }}
```

### DON'T（非推奨）

```sql
-- ❌ 適切な条件なし
{% if is_incremental() %}
-- 条件なしで全件処理
{% endif %}

-- ❌ unique_keyなしで重複データ

-- ❌ 小さなテーブルにインクリメンタル
-- → table または view で十分
```

## 1-10. トラブルシューティング

### 重複データ

```
問題: 同じorder_idのレコードが複数存在
原因: unique_keyの設定ミス、または条件の不備
解決: unique_keyを確認、またはフルリフレッシュ
```

### データが更新されない

```
問題: 新しいデータが反映されない
原因: updated_atの条件が正しくない
解決: 条件を見直し、またはフルリフレッシュ
```

### パフォーマンス問題

```
問題: インクリメンタル実行が遅い
原因: パーティショニングなし、または条件が広すぎる
解決: パーティション化、条件を絞り込み
```

## 1-11. ephemeralの活用

### 中間モデルとしてのephemeral

```sql
-- models/intermediate/int_order_summary.sql
{{ config(materialized='ephemeral') }}

select
    order_id,
    sum(quantity) as total_quantity,
    sum(line_total) as total_amount
from {{ ref('stg_order_items') }}
group by order_id
```

```sql
-- models/marts/fct_orders.sql
{{ config(materialized='table') }}

with orders as (
    select * from {{ ref('stg_orders') }}
),
order_summary as (
    -- int_order_summaryがCTEとして展開される
    select * from {{ ref('int_order_summary') }}
)
select
    o.order_id,
    o.customer_id,
    s.total_quantity,
    s.total_amount
from orders o
left join order_summary s on o.order_id = s.order_id
```

### ephemeralの使いどころ

- 1つのモデルからのみ参照される
- 軽量な変換
- ストレージを節約したい

## まとめ

- インクリメンタルは大規模データに最適
- `unique_key` で重複を制御
- `is_incremental()` で条件分岐
- BigQueryではパーティションとクラスタリングを活用
- `on_schema_change` でスキーマ変更に対応
- 定期的なフルリフレッシュを計画

次の章では、Jinjaとマクロについて学びます。
