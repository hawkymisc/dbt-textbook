---
title: "2. モデルの作成"
---

# 2. モデルの作成

この章では、dbtモデルの基本的な作成方法と、モデル間の参照について学びます。

## 2-1. モデルとは

モデルは、データウェアハウスで実行されるSQLクエリの定義です。各モデルは1つのテーブルまたはビューに対応します。

```
モデル（SQLファイル） → dbt run → テーブル/ビュー
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

**CTE**（共通テーブル式）は、WITH句で定義する一時的な結果セットです。dbtではCTEパターンを使用することが推奨されています：

```sql
-- models/staging/stg_orders.sql

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
        total_amount,
        created_at
    from source
),

final as (
    -- 最終的な変換
    select
        *,
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
    select * from {{ ref('stg_orders') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

final as (
    select
        o.order_id,
        c.full_name as customer_name,
        o.total_amount
    from orders o
    left join customers c on o.customer_id = c.customer_id
)

select * from final
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
| リネージ | 入力元として表示 | モデル間の依存関係 |

## 2-6. 選択実行（Selection）

特定のモデルだけを実行するには、`--select` オプションを使用します。

### 依存グラフと`+`記法

まず、依存グラフを理解しましょう：

```
stg_customers ──┐
                ├──→ int_orders ──→ fct_orders
stg_orders ─────┘        │
                         └──→ dim_customers
```

`+` 記号の意味：
- `+モデル名` = 上流（依存元）を含む
- `モデル名+` = 下流（被依存先）を含む

### コマンド例

```bash
# 特定のモデルのみ
dbt run --select fct_orders

# 上流を含む（fct_ordersと、それが依存する全モデル）
dbt run --select +fct_orders
# → stg_customers, stg_orders, int_orders, fct_orders

# 下流を含む（stg_ordersと、それに依存する全モデル）
dbt run --select stg_orders+
# → stg_orders, int_orders, fct_orders, dim_customers

# 両方向
dbt run --select +fct_orders+

# ディレクトリ単位
dbt run --select staging.*

# タグで選択
dbt run --select tag:nightly
```

## 2-7. モデル作成のベストプラクティス

### DO（推奨）

```sql
-- ✅ CTEを使用
with source as (
    select * from {{ source('raw', 'orders') }}
)
select * from source

-- ✅ 明示的なカラム指定
select
    order_id,
    customer_id,
    total_amount
from {{ ref('stg_orders') }}

-- ✅ コメントで意図を説明
-- 顧客IDで集計し、各顧客の注文数を計算
```

### DON'T（非推奨）

```sql
-- ❌ SELECT * の多用（最終層では）
-- 理由：ソースにカラムが追加されると、意図しないカラムが
--       出力に含まれてしまい、下流のモデルやBIツールに影響する
select * from {{ ref('stg_orders') }}

-- ❌ ネストしたサブクエリ（読みにくい）
select * from (
    select * from (
        select * from orders
    )
)

-- ❌ マジックナンバー（意図が不明）
where amount > 1000000  -- なぜ100万？

-- ❌ コメントなしの複雑なロジック
case when a > b then c else d end
```

:::message
**なぜ `SELECT *` を避けるか？**

Staging層では `SELECT *` を使っても良いですが、Marts層では明示的なカラム指定を推奨します。理由：
1. ソースにカラムが追加された場合、意図しないカラムが出力に含まれる
2. カラム名の変更時にエラーに気づきにくい
3. ドキュメントとしての役割が薄れる
:::

## 2-8. 実践：モデルを作成して実行

### 手順

1. **モデルファイルを作成**

```sql
-- models/staging/stg_orders.sql
with source as (
    select * from {{ source('raw', 'orders') }}
)

select
    order_id,
    customer_id,
    total_amount,
    created_at
from source
```

2. **dbt runを実行**

```bash
dbt run --select stg_orders
```

3. **実行結果を確認**

```
Running with dbt=1.8.0
Found 1 model, 0 tests

14:30:00  1 of 1 START view model dbt_dev.stg_orders ................ [RUN]
14:30:01  1 of 1 OK created view model dbt_dev.stg_orders ........... [OK in 1.23s]

Completed successfully

Done. PASS=1 WARN=0 ERROR=0 SKIP=0 TOTAL=1
```

4. **コンパイル結果を確認**

```bash
# コンパイルされたSQLを確認
cat target/compiled/sample_ec_project/models/staging/stg_orders.sql
```

```sql
-- コンパイル結果（refが実際のテーブル名に変換される）
with source as (
    select * from `my-project.raw_data.orders`
)

select
    order_id,
    customer_id,
    total_amount,
    created_at
from source
```

## まとめ

- モデルはSQLファイルで定義、1ファイル1テーブル/ビュー
- CTEパターンで可読性を高める
- `ref()` でモデルを、`source()` でソースを参照
- `--select` と `+` で特定のモデルと依存関係を実行
- 最終層では `SELECT *` を避け、明示的にカラムを指定

次の章では、マテリアライゼーションについて詳しく学びます。
