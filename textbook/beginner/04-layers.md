---
title: "4. プロジェクトのレイヤー構造"
---

# 4. プロジェクトのレイヤー構造

この章では、dbtプロジェクトのレイヤー構造（Staging、Intermediate、Marts）について学びます。

## 4-1. なぜレイヤー分けが必要か

### レイヤー分けのない場合

```sql
-- 全てを1つのクエリで書くと...
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name as customer_name,
    COUNT(DISTINCT o.order_id) as total_orders,
    SUM(oi.quantity * oi.unit_price) as total_amount,
    SUM(oi.quantity * p.cost) as total_cost,
    -- ...数百行続く...
FROM raw_customers c
LEFT JOIN raw_orders o ON c.customer_id = o.customer_id
LEFT JOIN raw_order_items oi ON o.order_id = oi.order_id
LEFT JOIN raw_products p ON oi.product_id = p.product_id
WHERE o.order_status = 'completed'
GROUP BY c.customer_id, c.first_name, c.last_name
```

**問題点**:
- 可読性が低い
- デバッグが困難
- 再利用できない
- テストが難しい

### レイヤー分けのある場合

```
[ソースデータ]
      ↓
[Staging] ... クリーニング・正規化
      ↓
[Intermediate] ... 結合・集計
      ↓
[Marts] ... ビジネス向け最終形
```

**メリット**:
- 各レイヤーで責任が明確
- 再利用可能なコンポーネント
- テストしやすい
- デバッグが容易

## 4-2. Staging層（ステージング層）

### 目的

- 生データの読み込み
- カラム名の統一
- 基本的な型変換
- 明らかな不要データの除去

### 特徴

- ソースと1対1で対応
- ビジネスロジックを含まない
- シンプルな変換のみ

### サンプルコード

```sql
-- models/staging/stg_orders.sql

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
        created_at,
        updated_at
    from source
),

final as (
    select
        *,
        date(created_at) as order_date,
        date_trunc('month', created_at) as order_month
    from renamed
)

select * from final
```

### Staging層のルール

| やること | やらないこと |
|---------|-------------|
| カラム名の統一 | ビジネスロジック |
| 型変換 | 複雑な結合 |
| NULL処理 | 集計 |
| 不要カラムの削除 | 他テーブルとの結合 |

## 4-3. Intermediate層（中間層）

### 目的

- 複数テーブルの結合
- ビジネスロジックの実装
- 中間的な集計
- 再利用可能な変換

### 特徴

- Staging層のモデルを参照
- 複雑なロジックを含む
- Marts層の準備

### サンプルコード

```sql
-- models/intermediate/int_order_items_with_product.sql

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
        -- 計算フィールド
        oi.quantity * oi.unit_price as line_total,
        oi.quantity * p.cost as cost_of_goods_sold,
        (oi.quantity * oi.unit_price) - (oi.quantity * p.cost) as gross_profit
    from order_items oi
    left join products p on oi.product_id = p.product_id
)

select * from joined
```

```sql
-- models/intermediate/int_orders_with_details.sql

with orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

order_items as (
    select * from {{ ref('int_order_items_with_product') }}
),

-- 注文ごとの集計
order_summary as (
    select
        order_id,
        count(*) as item_count,
        sum(quantity) as total_quantity,
        sum(line_total) as calculated_total,
        sum(gross_profit) as total_profit
    from order_items
    group by order_id
),

-- 全てを結合
final as (
    select
        o.order_id,
        o.customer_id,
        c.full_name as customer_name,
        o.order_status,
        o.total_amount,
        o.order_date,
        os.item_count,
        os.total_quantity,
        os.calculated_total,
        os.total_profit
    from orders o
    left join customers c on o.customer_id = c.customer_id
    left join order_summary os on o.order_id = os.order_id
)

select * from final
```

### Intermediate層の命名規則

| プレフィックス | 用途 |
|--------------|------|
| `int_` | 中間モデル全般 |
| `int_[entity]_with_[entity]` | 結合モデル |
| `int_[entity]_agg` | 集計モデル |
| `int_[entity]_pivoted` | ピボット変換 |

## 4-4. Marts層（マート層）

### 目的

- ビジネスユーザー向けの最終成果物
- 分析・レポート用のテーブル
- BIツールからの直接参照

### 特徴

- 完全に変換されたデータ
- 高いクエリパフォーマンス
- ドキュメント・テストが充実

### ファクトテーブル

```sql
-- models/marts/fct_orders.sql
{{ config(
    materialized='table',
    cluster_by=['order_date']
) }}

with orders as (
    select * from {{ ref('int_orders_with_details') }}
),

final as (
    select
        order_id,
        customer_id,
        customer_name,
        order_status,
        -- ビジネスユーザー向けに日本語表示を追加
        case order_status
            when 'completed' then '完了'
            when 'shipped' then '発送済み'
            when 'cancelled' then 'キャンセル'
            when 'returned' then '返品'
            else 'その他'
        end as order_status_ja,
        total_amount,
        order_date,
        item_count,
        total_quantity,
        calculated_total,
        total_profit,
        -- 利益率
        case
            when calculated_total > 0
            then round(total_profit / calculated_total, 4)
            else 0
        end as profit_margin
    from orders
    where order_status in ('completed', 'shipped')
)

select * from final
```

### ディメンションテーブル

```sql
-- models/marts/dim_customers.sql
{{ config(materialized='table') }}

with customers as (
    select * from {{ ref('stg_customers') }}
),

orders as (
    select * from {{ ref('int_orders_with_details') }}
),

customer_orders as (
    select
        customer_id,
        count(*) as total_orders,
        sum(calculated_total) as lifetime_value,
        min(order_date) as first_order_date,
        max(order_date) as last_order_date
    from orders
    where order_status = 'completed'
    group by customer_id
),

final as (
    select
        c.customer_id,
        c.full_name,
        c.email,
        coalesce(co.total_orders, 0) as total_orders,
        coalesce(co.lifetime_value, 0) as lifetime_value,
        co.first_order_date,
        co.last_order_date,
        -- 顧客セグメント
        case
            when co.lifetime_value >= 50000 then 'VIP'
            when co.lifetime_value >= 20000 then 'Regular'
            when co.lifetime_value > 0 then 'New'
            else 'No Purchase'
        end as customer_segment
    from customers c
    left join customer_orders co on c.customer_id = co.customer_id
)

select * from final
```

### Marts層の命名規則

| プレフィックス | 用途 |
|--------------|------|
| `fct_` | ファクトテーブル（出来事・トランザクション） |
| `dim_` | ディメンションテーブル（属性・マスタ） |
| `rpt_` | レポート用テーブル |

## 4-5. データリネージ（DAG）

### リネージの可視化

```
dbt docs generate
dbt docs serve
```

### サンプルプロジェクトのリネージ

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   sources   │     │   sources   │     │   sources   │
│  customers  │     │   orders    │     │ order_items │
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │                   │                   │
       ▼                   ▼                   ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   staging   │     │   staging   │     │   staging   │
│stg_customers│     │ stg_orders  │     │stg_order_   │
└──────┬──────┘     └──────┬──────┘     │   items     │
       │                   │            └──────┬──────┘
       │                   │                   │
       │    ┌──────────────┼───────────────────┘
       │    │              │
       ▼    ▼              ▼
┌──────────────────────────────────────┐
│         intermediate                  │
│  int_orders_with_details              │
└──────────────────┬───────────────────┘
                   │
         ┌─────────┼─────────┐
         ▼         ▼         ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│    marts    │ │    marts    │ │    marts    │
│ fct_orders  │ │fct_daily_   │ │dim_customers│
│             │ │   sales     │ │             │
└─────────────┘ └─────────────┘ └─────────────┘
```

## 4-6. レイヤー構造のベストプラクティス

### DO（推奨）

```sql
-- ✅ Staging層はシンプルに
select * from {{ source('raw', 'orders') }}

-- ✅ 複雑なロジックはIntermediate層で
-- ✅ 最終形はMarts層で

-- ✅ 各レイヤーで責任を分ける
-- Staging: データの準備
-- Intermediate: ビジネスロジック
-- Marts: 最終成果物
```

### DON'T（非推奨）

```sql
-- ❌ Staging層で結合
select * from {{ source('raw', 'orders') }} o
join {{ source('raw', 'customers') }} c ...

-- ❌ スキップ（Staging → Marts直接）
-- Intermediate層を経由せずに複雑な変換

-- ❌ Marts層で生データを参照
select * from {{ source('raw', 'orders') }}
```

## 4-7. 小規模プロジェクトでの対応

小規模プロジェクトでは、Intermediate層を省略することもあります：

```
models/
├── staging/
│   ├── stg_orders.sql
│   └── stg_customers.sql
└── marts/
    ├── fct_orders.sql
    └── dim_customers.sql
```

:::message
**小規模構成のリスク**
- Marts層のSQLが複雑になりやすい
- 再利用可能なコンポーネントが作りにくい
- プロジェクトが成長したら、すぐにIntermediate層を追加することをお勧めします
:::

## 4-8. 大規模プロジェクトでの対応

大規模プロジェクトでは、ドメインごとに分割します：

```
models/
├── staging/
│   ├── sales/
│   │   ├── stg_orders.sql
│   │   └── stg_order_items.sql
│   └── marketing/
│       ├── stg_campaigns.sql
│       └── stg_leads.sql
│
├── intermediate/
│   ├── sales/
│   │   └── int_order_summary.sql
│   └── marketing/
│       └── int_campaign_performance.sql
│
└── marts/
    ├── sales/
    │   ├── fct_orders.sql
    │   └── dim_customers.sql
    └── marketing/
        └── fct_campaigns.sql
```

:::message
**大規模構成のリスク**
- ディレクトリ構造が複雑になり、理解に時間がかかる
- ドメイン間の依存関係の管理が必要
- 最初は3層構造で始め、必要に応じて分割することをお勧めします
:::

## 4-9. 実践：サンプルプロジェクトの確認

```bash
# サンプルプロジェクトの構造を確認
tree models/

# リネージを可視化
dbt docs generate
dbt docs serve
```

## まとめ

- 3層構造: Staging → Intermediate → Marts
- Staging層: 生データの準備・クリーニング
- Intermediate層: ビジネスロジック・結合
- Marts層: 最終成果物（ファクト/ディメンション）
- 各レイヤーで責任を明確に分ける

次の章では、テストについて学びます。
