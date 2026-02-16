---
title: "3. マテリアライゼーション"
---

# 3. マテリアライゼーション

この章では、dbtのマテリアライゼーションについて学びます。マテリアライゼーションは、モデルがどのようにデータウェアハウスに保存されるかを決定します。

## 3-1. マテリアライゼーションとは

マテリアライゼーションは、dbtモデルのSQLクエリがどのように物理的に表現されるかを定義します。

```
SQLクエリ → マテリアライゼーション → 物理オブジェクト
```

例えば、同じSQLでも：
- `view` なら → データベースのビューが作成される
- `table` なら → 実際のテーブルとして保存される

## 3-2. 4つの基本マテリアライゼーション

### view（ビュー）

```sql
{{ config(materialized='view') }}

SELECT * FROM {{ source('raw', 'orders') }}
```

**特徴**:
- データベースにビューとして作成
- データは保存されず、クエリ実行時に計算
- ストレージを消費しない
- クエリ実行時は元のテーブルを参照

**メリット**:
- ストレージコストが低い
- 常に最新のデータを反映

**デメリット**:
- クエリが遅くなる可能性（複雑なビューの場合）
- 元テーブルへの負荷が高い

**使用場面**:
- Staging層
- データ量が少ないモデル
- 頻繁に更新されるが、頻繁にはクエリされないモデル

### table（テーブル）

```sql
{{ config(materialized='table') }}

SELECT * FROM {{ ref('stg_orders') }}
```

**特徴**:
- 実際のテーブルとして保存
- `dbt run` のたびに再作成（DROP → CREATE）
- データが物理的に保存される

**メリット**:
- クエリが高速
- 元テーブルへのアクセスが不要

**デメリット**:
- ストレージを消費
- 更新に時間がかかる（全件再作成）

**使用場面**:
- Marts層（ビジネスユーザーがクエリするモデル）
- 複雑な変換を経たモデル
- 頻繁にクエリされるモデル

### incremental（インクリメンタル）

```sql
{{ config(materialized='incremental', unique_key='order_id') }}

SELECT * FROM {{ source('raw', 'orders') }}

{% if is_incremental() %}
WHERE updated_at > (SELECT MAX(updated_at) FROM {{ this }})
{% endif %}
```

**特徴**:
- 初回は全件作成、2回目以降は増分のみ追加/更新
- `unique_key` で重複を制御
- 大量データの更新に最適

**メリット**:
- 大量データでも高速に更新
- リソース効率が良い

**デメリット**:
- 設定が複雑
- データ整合性の管理が必要

**使用場面**:
- 大量のデータを扱うモデル
- 頻繁に更新が必要なモデル
- 履歴データを蓄積するモデル

:::message
インクリメンタルモデルの詳細は中級編で解説します。
:::

### ephemeral（エフェメラル）

```sql
{{ config(materialized='ephemeral') }}

SELECT
    order_id,
    customer_id,
    total_amount
FROM {{ source('raw', 'orders') }}
```

**特徴**:
- 物理的なオブジェクトは作成されない
- 参照元のモデル内でCTEとして展開される
- データベースには何も保存されない

**メリット**:
- ストレージを消費しない
- 依存関係を整理できる

**デメリット**:
- 直接クエリできない
- 複数のモデルから参照されると同じクエリが重複実行される

**使用場面**:
- Intermediate層
- 1つのモデルからのみ参照される中間モデル
- 軽量な変換ロジック

## 3-3. マテリアライゼーションの比較

| タイプ | 物理オブジェクト | クエリ速度 | 更新速度 | ストレージ |
|-------|----------------|-----------|---------|-----------|
| view | ビュー | 遅い場合あり | 高速 | なし |
| table | テーブル | 高速 | 遅い（全件） | あり |
| incremental | テーブル | 高速 | 高速（増分） | あり |
| ephemeral | なし | 中間 | 高速 | なし |

## 3-4. マテリアライゼーションの設定方法

### 方法1: dbt_project.yml（推奨）

```yaml
# dbt_project.yml
models:
  sample_ec_project:
    staging:
      +materialized: view
    intermediate:
      +materialized: ephemeral
    marts:
      +materialized: table
```

### 方法2: モデルファイル内

```sql
-- models/marts/fct_orders.sql
{{ config(materialized='table') }}

SELECT * FROM {{ ref('stg_orders') }}
```

### 方法3: schema.yml

```yaml
# models/marts/schema.yml
version: 2

models:
  - name: fct_orders
    config:
      materialized: table
```

## 3-5. 適切なマテリアライゼーションの選択

### 選択フローチャート

```
1. そのモデルを直接クエリするか？
   └─ No → ephemeral
   └─ Yes → 次へ

2. データ量は大きいか？（数百万行以上）
   └─ Yes → incremental（または table）
   └─ No → 次へ

3. 頻繁にクエリされるか？
   └─ Yes → table
   └─ No → view
```

### レイヤー別の推奨設定

```yaml
models:
  sample_ec_project:
    # Staging: ソースデータの準備
    staging:
      +materialized: view

    # Intermediate: 中間処理
    intermediate:
      +materialized: ephemeral

    # Marts: 最終成果物
    marts:
      +materialized: table
```

## 3-6. BigQuery固有の設定

### クラスタリング

```sql
{{ config(
    materialized='table',
    cluster_by=['order_date', 'customer_id']
) }}

SELECT * FROM {{ ref('stg_orders') }}
```

### パーティショニング

```sql
{{ config(
    materialized='table',
    partition_by={
      "field": "order_date",
      "data_type": "date",
      "granularity": "day"
    }
) }}

SELECT * FROM {{ ref('stg_orders') }}
```

### パーティション + クラスタリング

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

SELECT * FROM {{ ref('stg_orders') }}

{% if is_incremental() %}
WHERE order_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
{% endif %}
```

## 3-7. DuckDBの設定

DuckDBはシンプルな設定で動作します：

```sql
-- 基本的なテーブル
{{ config(materialized='table') }}

-- インクリメンタル（DuckDBでも利用可能）
{{ config(
    materialized='incremental',
    unique_key='order_id'
) }}
```

## 3-8. 実践例：サンプルプロジェクト

サンプルプロジェクトでのマテリアライゼーション設定を確認しましょう：

```yaml
# dbt_project.yml
models:
  sample_ec_project:
    staging:
      +materialized: view
      +schema: staging

    intermediate:
      +materialized: ephemeral
      +schema: intermediate

    marts:
      +materialized: table
      +schema: marts
```

### 実行結果の確認

```bash
# 全モデルを実行
dbt run

# BigQuery/DuckDBで確認
# staging層: ビューとして作成
# intermediate層: 物理オブジェクトなし（CTE展開）
# marts層: テーブルとして作成
```

## 3-9. トラブルシューティング

### ビューが遅い

```
問題: 複雑なビューのクエリが遅い
解決: テーブルに変更するか、中間モデルを追加
```

### インクリメンタルの重複

```
問題: 同じデータが重複して登録される
解決: unique_keyを正しく設定
```

### メモリ不足

```
問題: 大きなテーブルの作成でエラー
解決: パーティション化、またはインクリメンタル化
```

## 3-10. マテリアライゼーション選択チェックリスト

モデルのマテリアライゼーションを決定する際のチェックリスト：

- [ ] このモデルは直接クエリされるか？
- [ ] データ量はどの程度か？
- [ ] 更新頻度はどの程度か？
- [ ] クエリのパフォーマンス要件は？
- [ ] ストレージコストの制約は？
- [ ] どのレイヤーに属しているか？

## まとめ

- マテリアライゼーションはモデルの物理的表現方法を決定
- 4つの基本タイプ: view, table, incremental, ephemeral
- レイヤーごとに適切なマテリアライゼーションを選択
- BigQueryではパーティションとクラスタリングも活用

次の章では、レイヤー構造について詳しく学びます。
