---
title: "2. モデルの作成"
---

# 2. モデルの作成

この章では、dbtモデルの基本的な作成方法と、モデル間の参照について学びます。

## 2-1. モデルとは

モデルは、データウェアハウスで実行されるSQLクエリの定義です。各モデルは1つのテーブルまたはビューに対応します。

```
モデル（SQLファイル） → 実行 → テーブル/ビュー
```

### 最もシンプルなモデル

```sql
-- models/hello.sql
SELECT 1 as id, 'Hello' as message
```

このモデルを実行すると、`hello` という名前のビューが作成されます。

## 2-2. モデルの命名規則

### 推奨される命名規則

| プレフィックス | 用途 | 例 |
|--------------|------|-----|
| `stg_` | Staging層 | `stg_customers.sql` |
| `int_` | Intermediate層 | `int_order_summary.sql` |
| `fct_` | ファクトテーブル | `fct_orders.sql` |
| `dim_` | ディメンションテーブル | `dim_customers.sql` |
| `rpt_` | レポート用 | `rpt_monthly_sales.sql` |

:::message
一貫した命名規則を使用することで、モデルの役割が一目でわかるようになります。
:::

## 2-3. モデルの基本構造

### CTE（Common Table Expression）パターン

dbtではCTEパターンを使用することが推奨されています：

```sql
-- models/staging/stg_orders.sql

-- コメントで各CTEの目的を説明
with source as (
    -- ソースからデータを取得
    select * from {{ source('raw', 'orders') }}
),

renamed as (
    -- カラム名の統一・変更
    select
        order_id,
        customer_id,
        order_status,
        payment_method,
        shipping_address,
        total_amount,
        created_at,
        updated_at
    from source
),

final as (
    -- 最終的な変換
    select
        *,
        -- 注文日を抽出
        date(created_at) as order_date
    from renamed
)

select * from final
```

### CTEパターンのメリット

1. **可読性**: 各CTEで何をしているかが明確
2. **デバッグ**: 各CTEを個別に確認可能
3. **再利用**: CTEを再利用しやすい
4. **保守性**: 変更箇所が限定される

## 2-4. ref()関数によるモデル参照

`ref()` 関数を使うと、他のモデルを参照できます：

```sql
-- models/marts/fct_orders.sql

with orders as (
    -- 別のモデルを参照
    select * from {{ ref('stg_orders') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

final as (
    select
        o.order_id,
        o.customer_id,
        c.full_name as customer_name,
        o.total_amount
    from orders o
    left join customers c on o.customer_id = c.customer_id
)

select * from final
```

### ref()の動作

`ref('stg_orders')` は、データウェアハウス上の実際のテーブル名に変換されます：

```
{{ ref('stg_orders') }}
↓
`project_id.dataset_name.stg_orders`  -- BigQuery
```

### 依存関係の自動解決

dbtは `ref()` の呼び出しから依存関係を自動的に構築します：

```
stg_customers ──┐
                ├──→ fct_orders
stg_orders ─────┘
```

これにより、`dbt run` で正しい順序でモデルが実行されます。

## 2-5. source()関数によるソース参照

`source()` 関数でソーステーブルを参照します：

```yaml
# models/staging/sources.yml
sources:
  - name: raw
    tables:
      - name: customers
      - name: orders
```

```sql
-- models/staging/stg_customers.sql
select * from {{ source('raw', 'customers') }}
```

### source()とref()の違い

| 項目 | source() | ref() |
|-----|----------|-------|
| 参照先 | 生データ（外部システム） | dbtモデル |
| 定義場所 | sources.yml | 自動検出 |
| テスト | ソーステスト | モデルテスト |
| リネージ | 入力元として表示 | モデル間の依存関係 |

## 2-6. モデルの設定

### ファイル内での設定

```sql
-- models/marts/fct_orders.sql
{{ config(
    materialized='table',
    schema='analytics',
    cluster_by=['order_date']
) }}

with orders as (
    select * from {{ ref('stg_orders') }}
)

select * from orders
```

### 主要な設定オプション

| オプション | 説明 | 例 |
|-----------|------|-----|
| `materialized` | マテリアライゼーション | `'table'`, `'view'`, `'incremental'` |
| `schema` | スキーマ名のプレフィックス | `'analytics'` |
| `cluster_by` | クラスタリングキー（BigQuery） | `['order_date']` |
| `tags` | タグ（選択実行用） | `['nightly']` |
| `persist_docs` | ドキュメントを永続化 | `{'columns': true}` |

### YAMLでの設定

```yaml
# models/marts/schema.yml
version: 2

models:
  - name: fct_orders
    config:
      materialized: table
      cluster_by: ['order_date']
      tags: ['critical']
```

## 2-7. 選択実行（Selection）

特定のモデルだけを実行するには、`--select` オプションを使用します：

```bash
# 特定のモデルのみ
dbt run --select fct_orders

# 複数のモデル
dbt run --select fct_orders dim_customers

# ディレクトリ単位
dbt run --select staging.*

# タグで選択
dbt run --select tag:nightly

# 正規表現
dbt run --select "stg_*"
```

### 依存関係を含む選択

```bash
# 指定モデルとその依存元（上游）
dbt run --select +fct_orders

# 指定モデルとその被依存先（下游）
dbt run --select stg_orders+

# 両方向
dbt run --select +fct_orders+

# 範囲指定
dbt run --select stg_orders+int_orders
```

### グラフの可視化

```
stg_customers ──┐
                ├──→ int_orders ──→ fct_orders
stg_orders ─────┘        │
                         └──→ dim_customers

# dbt run --select +fct_orders
# → stg_customers, stg_orders, int_orders, fct_orders が実行される

# dbt run --select stg_orders+
# → stg_orders, int_orders, fct_orders, dim_customers が実行される
```

## 2-8. モデルのドキュメント

### インラインドキュメント

```sql
-- models/staging/stg_orders.sql

with source as (
    select * from {{ source('raw', 'orders') }}
),

final as (
    select
        order_id,
        customer_id,
        -- 注文の合計金額（税込み）
        total_amount,
        -- 注文日時（JST）
        created_at
    from source
)

select * from final
```

### YAMLでのドキュメント

```yaml
# models/staging/schema.yml
version: 2

models:
  - name: stg_orders
    description: "注文データのステージングモデル。生データから基本的な変換を行う。"
    columns:
      - name: order_id
        description: "注文ID（主キー）"
      - name: customer_id
        description: "顧客ID"
      - name: total_amount
        description: "注文の合計金額（税込み、円）"
        meta:
          metric_type: currency
      - name: created_at
        description: "注文日時（日本標準時）"
```

## 2-9. モデル作成のベストプラクティス

### DO（推奨）

```sql
-- ✅ CTEを使用
with source as (
    select * from {{ source('raw', 'orders') }}
),
renamed as (
    select
        order_id,
        customer_id
    from source
)
select * from renamed

-- ✅ 明示的なカラム指定
select
    order_id,
    customer_id,
    total_amount
from {{ source('raw', 'orders') }}

-- ✅ コメントで意図を説明
-- 顧客IDで集計し、各顧客の注文数を計算
```

### DON'T（非推奨）

```sql
-- ❌ SELECT * の多用（最終層では）
select * from {{ source('raw', 'orders') }}

-- ❌ ネストしたサブクエリ
select * from (
    select * from (
        select * from orders
    )
)

-- ❌ マジックナンバー
where amount > 1000000  -- なぜ100万？

-- ❌ コメントなしの複雑なロジック
case when a > b then c else d end
```

## 2-10. 実践：サンプルプロジェクトのモデル

サンプルプロジェクトのモデル構成を確認しましょう：

```
models/
├── staging/
│   ├── sources.yml           # ソース定義
│   ├── stg_customers.sql     # 顧客データの変換
│   ├── stg_products.sql      # 商品データの変換
│   ├── stg_orders.sql        # 注文データの変換
│   └── stg_order_items.sql   # 注文明細の変換
│
├── intermediate/
│   ├── int_order_items_with_product.sql  # 明細に商品情報を結合
│   └── int_orders_with_details.sql       # 注文に集計情報を結合
│
└── marts/
    ├── schema.yml            # テスト定義
    ├── fct_orders.sql        # 注文ファクトテーブル
    ├── fct_daily_sales.sql   # 日次売上サマリー
    └── dim_customers.sql     # 顧客ディメンション
```

### 実行と確認

```bash
# 全モデルを実行
dbt run

# 特定のモデルとその依存元を実行
dbt run --select +fct_orders

# ドキュメントを生成
dbt docs generate
dbt docs serve
```

## まとめ

- モデルはSQLファイルで定義、1ファイル1テーブル/ビュー
- CTEパターンで可読性を高める
- `ref()` でモデルを、`source()` でソースを参照
- `--select` オプションで特定のモデルを実行
- ドキュメントはYAMLで定義

次の章では、マテリアライゼーションについて詳しく学びます。
