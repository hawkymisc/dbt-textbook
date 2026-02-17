---
title: "6. Snapshots"
---

# 6. Snapshots

この章では、dbt Snapshotsを使ってデータの履歴を管理する方法を学びます。

## 6-1. Snapshotsとは

Snapshotsは、データの**変更履歴**を記録する機能です。

### なぜ履歴管理が必要か

```
問題:
- 顧客の住所が変わった → 古い住所は失われる
- 商品価格が変わった → 過去の価格がわからない
- ステータスが変わった → 変更日時が記録されない
```

```
解決: Snapshots
- 変更前のデータを保存
- 変更日時を記録
- 過去の時点でのデータを再現可能
```

## 6-2. SCD Type 2

dbt Snapshotsは、**SCD Type 2**（Slowly Changing Dimension Type 2）を実装します。

### SCD Type 2とは

- 各レコードに有効期間（`valid_from`, `valid_to`）を持つ
- 変更があると新しいバージョンのレコードを作成
- 古いバージョンは `valid_to` で無効化

### Snapshotsの出力

Snapshotsを実行すると、以下のカラムが自動的に追加されます：

| カラム名 | 説明 |
|---------|------|
| `dbt_scd_id` | レコードの一意識別子（ハッシュ値） |
| `dbt_valid_from` | レコードの有効開始日時 |
| `dbt_valid_to` | レコードの有効終了日時（現在のレコードはNULL） |
| `dbt_updated_at` | レコードが更新された日時 |
| `dbt_is_deleted` | 削除フラグ（invalidate_hard_deletes=True時） |

**出力例**:

| customer_id | name | email | dbt_valid_from | dbt_valid_to | dbt_scd_id |
|------------|------|-------|----------------|--------------|------------|
| 1 | 田中太郎 | old@email.com | 2024-01-01 | 2024-06-15 | abc123... |
| 1 | 田中太郎 | new@email.com | 2024-06-15 | NULL | def456... |

現在のレコードは `dbt_valid_to` が `NULL` です。

## 6-3. 基本的なSnapshot

### Snapshotファイルの作成

```sql
-- snapshots/customers_snapshot.sql

{% snapshot customers_snapshot %}

{{
    config(
        target_schema='snapshots',
        unique_key='customer_id',
        strategy='timestamp',
        updated_at='updated_at',
        invalidate_hard_deletes=True
    )
}}

SELECT * FROM {{ source('raw', 'customers') }}

{% endsnapshot %}
```

### 設定項目

| 項目 | 説明 |
|-----|------|
| `target_schema` | Snapshotの保存先スキーマ |
| `unique_key` | レコードを一意に識別するキー |
| `strategy` | 変更検出方法（timestamp/check） |
| `updated_at` | 更新日時カラム（timestamp戦略） |
| `invalidate_hard_deletes` | 削除されたレコードを無効化 |

### Snapshotの実行

```bash
dbt snapshot
```

## 6-4. 変更検出戦略

### Timestamp戦略

更新日時カラムで変更を検出します：

```sql
{{
    config(
        strategy='timestamp',
        updated_at='updated_at'
    )
}}
```

- 最も一般的
- 効率的
- 更新日時カラムが必要

### Check戦略

指定したカラムの値で変更を検出します：

```sql
{{
    config(
        strategy='check',
        check_cols=['name', 'email', 'status']
    )
}}
```

- 更新日時がない場合に使用
- 指定カラムの変更のみ追跡
- 全カラムをチェック: `check_cols='all'`

### Check戦略の完全例

```sql
{% snapshot products_snapshot %}

{{
    config(
        target_schema='snapshots',
        unique_key='product_id',
        strategy='check',
        check_cols=['product_name', 'price', 'category']
    )
}}

SELECT * FROM {{ source('raw', 'products') }}

{% endsnapshot %}
```

## 6-5. Snapshotの参照

### モデルでSnapshotを使用

```sql
-- models/marts/dim_customers_history.sql

WITH current_customers AS (
    SELECT * FROM {{ ref('customers_snapshot') }}
    WHERE dbt_valid_to IS NULL
),

historical_customers AS (
    SELECT * FROM {{ ref('customers_snapshot') }}
)

-- 現在の顧客
SELECT
    customer_id,
    full_name,
    email,
    dbt_valid_from,
    dbt_valid_to,
    'current' as record_type
FROM current_customers

UNION ALL

-- 履歴（過去のバージョン）
SELECT
    customer_id,
    full_name,
    email,
    dbt_valid_from,
    dbt_valid_to,
    'historical' as record_type
FROM historical_customers
WHERE dbt_valid_to IS NOT NULL
```

### 特定時点のデータを取得

```sql
-- 2024年3月1日時点のデータ
SELECT *
FROM {{ ref('customers_snapshot') }}
WHERE dbt_valid_from <= '2024-03-01'
  AND (dbt_valid_to > '2024-03-01' OR dbt_valid_to IS NULL)
```

## 6-6. 高度な設定

### ハードデリートの処理

```sql
{{
    config(
        invalidate_hard_deletes=True
    )
}}
```

`True`: 削除されたレコードの `dbt_valid_to` を更新
`False`: 削除されたレコードはそのまま

### カスタムSnapshot名

```sql
{% snapshot products_snapshot %}

{{
    config(
        alias='products_history'  -- テーブル名をカスタマイズ
    )
}}

{% endsnapshot %}
```

### 複数Snapshots

```sql
-- snapshots/customers_snapshot.sql
{% snapshot customers_snapshot %}
{{ config(...) }}
SELECT * FROM {{ source('raw', 'customers') }}
{% endsnapshot %}

-- snapshots/products_snapshot.sql
{% snapshot products_snapshot %}
{{ config(...) }}
SELECT * FROM {{ source('raw', 'products') }}
{% endsnapshot %}
```

## 6-7. 実践例：商品価格の履歴

```sql
-- snapshots/products_snapshot.sql

{% snapshot products_snapshot %}

{{
    config(
        target_schema='snapshots',
        unique_key='product_id',
        strategy='check',
        check_cols=['price', 'cost'],
        invalidate_hard_deletes=True
    )
}}

SELECT
    product_id,
    product_name,
    category,
    price,
    cost,
    updated_at
FROM {{ source('raw', 'products') }}

{% endsnapshot %}
```

### 価格変動の分析

```sql
-- models/marts/fct_price_changes.sql

WITH price_history AS (
    SELECT
        product_id,
        product_name,
        price,
        cost,
        dbt_valid_from,
        dbt_valid_to,
        LAG(price) OVER (PARTITION BY product_id ORDER BY dbt_valid_from) as prev_price
    FROM {{ ref('products_snapshot') }}
)

SELECT
    product_id,
    product_name,
    prev_price as old_price,
    price as new_price,
    (price - prev_price) as price_change,
    dbt_valid_from as change_date
FROM price_history
WHERE prev_price IS NOT NULL
  AND prev_price != price
```

## 6-8. BigQuery固有の設定

```sql
{% snapshot orders_snapshot %}

{{
    config(
        target_schema='snapshots',
        unique_key='order_id',
        strategy='timestamp',
        updated_at='updated_at',
        cluster_by=['customer_id']
    )
}}

SELECT * FROM {{ source('raw', 'orders') }}

{% endsnapshot %}
```

## 6-9. Snapshotsのベストプラクティス

### どのテーブルにSnapshotを使うか

| 使用すべき | 使用しないべき |
|----------|--------------|
| 顧客マスタ | 大量のトランザクションデータ |
| 商品マスタ | 頻繁に変わる一時データ |
| 設定テーブル | ログデータ |
| ステータス管理 | 一度しか更新されないデータ |

### 実行頻度

```bash
# 1日1回（推奨）
0 6 * * * dbt snapshot

# 変更頻度に応じて調整
```

### ディレクトリ構成

```
snapshots/
├── customers_snapshot.sql
├── products_snapshot.sql
└── orders_status_snapshot.sql
```

## 6-10. トラブルシューティング

### 重複レコード

```
問題: 同じunique_keyで複数レコード
原因: unique_keyが一意でない
解決: unique_keyを見直す
```

### 変更が検出されない

```
問題: データが変わっても新しいレコードが作成されない
原因: updated_atが更新されていない
解決: check戦略に切り替え、またはupdated_atの更新を確認
```

### パフォーマンス問題

```
問題: Snapshot実行が遅い
原因: データ量が多い
解決:
- 不要なカラムをSELECTから除外
- 適切なパーティショニング（BigQuery）
- 定期的な古いデータのアーカイブ
```

## 6-11. サンプルプロジェクトへの適用

```bash
# snapshotsディレクトリにファイルを作成
mkdir -p snapshots
```

```sql
-- snapshots/customers_snapshot.sql
{% snapshot customers_snapshot %}

{{
    config(
        target_schema='snapshots',
        unique_key='customer_id',
        strategy='timestamp',
        updated_at='updated_at'
    )
}}

SELECT * FROM {{ source('raw', 'customers') }}

{% endsnapshot %}
```

```bash
# 実行
dbt snapshot
```

## まとめ

- Snapshotsでデータの変更履歴を管理
- SCD Type 2を実装（有効期間付きレコード）
- `strategy='timestamp'` または `check` で変更検出
- `dbt snapshot` コマンドで実行
- マスターデータなど、変更履歴が必要なデータに使用

次の章では、Seedsについて学びます。
