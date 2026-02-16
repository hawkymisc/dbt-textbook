---
title: "付録C: チートシート"
---

# dbt チートシート

## クイックリファレンス

### プロジェクト作成

```bash
dbt init my_project
cd my_project
dbt debug  # 接続確認
```

### 基本サイクル

```bash
dbt seed              # CSVデータをロード
dbt run               # モデルを実行
dbt test              # テストを実行
dbt docs generate     # ドキュメント生成
dbt docs serve        # ドキュメント表示
```

---

## モデル

### 基本構文

```sql
-- models/marts/fct_orders.sql
{{ config(materialized='table') }}

with source as (
    select * from {{ ref('stg_orders') }}
),

final as (
    select
        order_id,
        customer_id,
        total_amount
    from source
)

select * from final
```

### 参照関数

```sql
-- モデル参照
{{ ref('model_name') }}

-- パッケージ内のモデル
{{ ref('package_name', 'model_name') }}

-- ソース参照
{{ source('source_name', 'table_name') }}

-- 現在のモデル
{{ this }}
```

### 設定

```sql
-- ファイル内設定
{{ config(
    materialized='table',
    schema='analytics',
    cluster_by=['date']
) }}

-- 条件付き設定
{% if target.name == 'prod' %}
    {{ config(schema='prod_analytics') }}
{% endif %}
```

---

## マテリアライゼーション

| タイプ | 説明 | 使用場面 |
|-------|------|---------|
| `view` | ビュー | Staging層 |
| `table` | テーブル | Marts層 |
| `incremental` | 増分更新 | 大量データ |
| `ephemeral` | CTE | Intermediate層 |

### インクリメンタル

```sql
{{ config(
    materialized='incremental',
    unique_key='order_id'
) }}

select * from {{ source('raw', 'orders') }}

{% if is_incremental() %}
where updated_at > (select max(updated_at) from {{ this }})
{% endif %}
```

---

## テスト

### 基本テスト

```yaml
columns:
  - name: order_id
    tests:
      - unique
      - not_null

  - name: customer_id
    tests:
      - relationships:
          to: ref('dim_customers')
          field: customer_id

  - name: status
    tests:
      - accepted_values:
          values: ['active', 'inactive']
```

### テスト設定

```yaml
- name: amount
  tests:
    - not_null:
        severity: error
        config:
          store_failures: true
          tags: ['critical']
```

---

## Jinja

### 変数

```sql
-- プロジェクト変数
{{ var('start_date') }}
{{ var('start_date', '2024-01-01') }}  -- デフォルト値

-- コマンドライン変数
dbt run --vars '{"start_date": "2024-06-01"}'
```

### 制御構造

```sql
{% if condition %}
    -- 処理
{% elif other_condition %}
    -- 処理
{% else %}
    -- 処理
{% endif %}

{% for item in list %}
    {{ item }}{{ "," if not loop.last }}
{% endfor %}
```

### マクロ

```sql
-- 定義
{% macro calculate_profit(revenue, cost) %}
    {{ revenue }} - {{ cost }}
{% endmacro %}

-- 使用
{{ calculate_profit('total_amount', 'total_cost') }}
```

---

## 選択

```bash
# 特定モデル
dbt run --select my_model

# 依存関係を含む
dbt run --select +my_model    # 上流を含む
dbt run --select my_model+    # 下流を含む
dbt run --select +my_model+   # 両方向

# ディレクトリ
dbt run --select staging.*

# タグ
dbt run --select tag:nightly

# 正規表現
dbt run --select "stg_*"

# 除外
dbt run --exclude temp_*
```

---

## ソース定義

```yaml
# models/staging/sources.yml
version: 2

sources:
  - name: raw
    database: my_project
    schema: raw_data
    tables:
      - name: orders
        description: "注文データ"
        freshness:
          warn_after: {count: 24, period: hour}
        columns:
          - name: order_id
            tests:
              - unique
              - not_null
```

---

## ドキュメント

```yaml
models:
  - name: fct_orders
    description: |
      ## 注文ファクトテーブル

      完了した注文データを含みます。

      ### カラム説明
      - order_id: 注文ID
      - total_amount: 合計金額

    meta:
      owner: data_team

    columns:
      - name: order_id
        description: "注文ID（主キー）"
        meta:
          example: "ORD-001"
```

---

## Snapshots

```sql
{% snapshot orders_snapshot %}

{{
    config(
        target_schema='snapshots',
        unique_key='order_id',
        strategy='timestamp',
        updated_at='updated_at'
    )
}}

select * from {{ source('raw', 'orders') }}

{% endsnapshot %}
```

---

## Seeds

```yaml
# dbt_project.yml
seeds:
  my_project:
    +schema: reference_data
    my_seed:
      +column_types:
        id: integer
        name: varchar(100)
```

```bash
dbt seed --select my_seed
```

---

## よく使うパターン

### 日付フィルタ

```sql
{% if var('start_date') %}
    where order_date >= '{{ var("start_date") }}'
{% endif %}
```

### 環境分岐

```sql
{% if target.name == 'prod' %}
    select * from {{ source('prod', 'orders') }}
{% else %}
    select * from {{ source('dev', 'orders') }}
{% endif %}
```

### NULL安全

```sql
coalesce(column, 0)
nullif(column, '')
```

### 安全な除算

```sql
numerator / nullif(denominator, 0)
```

---

## トラブルシューティング

```bash
# 接続確認
dbt debug

# 詳細ログ
dbt --debug run

# コンパイル結果確認
dbt compile
cat target/compiled/my_project/models/marts/fct_orders.sql

# 失敗レコード確認
dbt test --store-failures
```
