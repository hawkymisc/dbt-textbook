---
title: "4. Hello dbt"
---

# 4. Hello dbt

この章では、最初のモデルを作成して実行し、dbtの基本的なワークフローを体験します。

## 4-1. プロジェクトの作成

### dbt initの実行

新しいプロジェクトを作成するには、`dbt init` コマンドを使用します：

```bash
# 新しいディレクトリで実行
dbt init my_first_project
```

対話形式でプロジェクト名と使用するデータベースを聞かれます：

```
Enter a name for your project (letters, digits, underscore): my_first_project
Which database would you like to use?
[1] bigquery
[2] duckdb
[3] postgres
[4] redshift
[5] snowflake
(Don't see the one you want? Press Enter to re-scan)
```

### 生成されるファイル構造

```
my_first_project/
├── README.md
├── analyses/
├── dbt_project.yml      # プロジェクト設定ファイル
├── macros/
├── models/
│   └── example/
│       ├── my_first_dbt_model.sql
│       └── schema.yml
├── seeds/
├── snapshots/
└── tests/
```

:::message
本書では、付属の `sample-project` ディレクトリを使用します。以降のコマンドは `sample-project` ディレクトリ内で実行してください。
:::

## 4-2. dbt_project.ymlの理解

`dbt_project.yml` はプロジェクトの設定ファイルです：

```yaml
name: 'sample_ec_project'      # プロジェクト名
version: '1.0.0'               # バージョン
config-version: 2              # 設定ファイルのバージョン

profile: 'sample_ec_project'   # profiles.yml内のプロファイル名

model-paths: ["models"]        # モデルの配置場所
seed-paths: ["seeds"]          # シードファイルの配置場所
test-paths: ["tests"]          # テストの配置場所
macro-paths: ["macros"]        # マクロの配置場所
snapshot-paths: ["snapshots"]  # スナップショットの配置場所

# モデルの設定
models:
  sample_ec_project:
    staging:
      +materialized: view
    marts:
      +materialized: table
```

## 4-3. 最初のモデルを作成する

### モデルファイルの作成

`models/staging/` ディレクトリに最初のモデルを作成しましょう：

```sql
-- models/staging/hello_world.sql

SELECT
    1 as id,
    'Hello, dbt!' as message,
    CURRENT_TIMESTAMP() as created_at
```

このモデルを実行すると、データウェアハウスに `hello_world` というビュー（またはテーブル）が作成されます。

### dbt runで実行

```bash
dbt run
```

出力例：

```
Running with dbt=1.8.0
Found 1 model, 0 tests, 0 snapshots, 0 analyses, 0 macros, 0 operations

14:23:45  Concurrency: 4 threads (target='dev')
14:23:45
14:23:46  Finished running 1 view model in 0 hours 0 and 1.23 seconds (1.23s).

Completed successfully

Done. PASS=1 WARN=0 ERROR=0 SKIP=0 TOTAL=1
```

### 生成された結果の確認

#### BigQueryの場合

BigQueryコンソールで `dbt_dev` データセット内の `hello_world` ビューを確認できます。

```sql
SELECT * FROM `your-project.dbt_dev.hello_world`
```

#### DuckDBの場合

```bash
duckdb dev.duckdb -c "SELECT * FROM hello_world;"
```

## 4-4. サンプルデータを使用する

本書のサンプルプロジェクトでは、ECサイトのデータを使用します。まず、サンプルデータをロードしましょう。

### シードファイルの準備

サンプルデータ（CSVファイル）を `seeds/` ディレクトリにコピーします：

```bash
# sample-project ディレクトリ内で実行
cp ../data/raw/*.csv seeds/
```

### dbt seedでデータをロード

```bash
dbt seed
```

出力例：

```
Running with dbt=1.8.0
Found 4 models, 0 tests, 0 snapshots, 0 analyses, 0 macros, 0 operations, 4 seeds

14:25:30  Concurrency: 4 threads (target='dev')
14:25:30
14:25:31  1 of 4 START seed file sample_ec_project.customers ................. [RUN]
14:25:31  2 of 4 START seed file sample_ec_project.products ................. [RUN]
14:25:31  3 of 4 START seed file sample_ec_project.orders ................... [RUN]
14:25:31  4 of 4 START seed file sample_ec_project.order_items .............. [RUN]
14:25:32  1 of 4 OK loaded seed file sample_ec_project.customers ............ [INSERT 10 in 1.23s]
14:25:32  2 of 4 OK loaded seed file sample_ec_project.products ............ [INSERT 10 in 1.23s]
14:25:32  3 of 4 OK loaded seed file sample_ec_project.orders .............. [INSERT 15 in 1.23s]
14:25:32  4 of 4 OK loaded seed file sample_ec_project.order_items ......... [INSERT 24 in 1.23s]

Completed successfully

Done. PASS=4 WARN=0 ERROR=0 SKIP=0 TOTAL=4
```

### ロードされたデータの確認

```sql
-- 顧客データ
SELECT * FROM sample_ec_project.customers LIMIT 5;

-- 商品データ
SELECT * FROM sample_ec_project.products LIMIT 5;
```

## 4-5. ソースの定義

生データを参照するために、ソースを定義します。

`models/staging/sources.yml` を作成：

```yaml
version: 2

sources:
  - name: raw
    description: "ECサイトの生データ"
    schema: sample_ec_project  # シードデータのスキーマ
    tables:
      - name: customers
        description: "顧客マスタ"
        columns:
          - name: customer_id
            description: "顧客ID"
            tests:
              - unique
              - not_null
          - name: email
            description: "メールアドレス"
            tests:
              - unique

      - name: products
        description: "商品マスタ"

      - name: orders
        description: "注文ヘッダ"

      - name: order_items
        description: "注文明細"
```

### ソースの参照

`source()` 関数を使ってソースを参照します：

```sql
-- models/staging/stg_customers.sql

SELECT
    customer_id,
    first_name,
    last_name,
    email,
    created_at,
    updated_at
FROM {{ source('raw', 'customers') }}
```

## 4-6. モデルを連鎖させる

dbtの真価は、モデル間の依存関係を管理できる点にあります。

### 最初の変換モデル

```sql
-- models/staging/stg_customers.sql

WITH source AS (
    SELECT * FROM {{ source('raw', 'customers') }}
),

renamed AS (
    SELECT
        customer_id,
        first_name,
        last_name,
        first_name || ' ' || last_name AS full_name,
        email,
        created_at,
        updated_at
    FROM source
)

SELECT * FROM renamed
```

### 2番目のモデル（他のモデルを参照）

```sql
-- models/marts/dim_customers.sql

WITH customers AS (
    SELECT * FROM {{ ref('stg_customers') }}
),

final AS (
    SELECT
        customer_id,
        full_name,
        email,
        -- 顧客セグメント
        CASE
            WHEN email LIKE '%@example.com' THEN 'Test'
            ELSE 'Real'
        END AS customer_type,
        created_at
    FROM customers
)

SELECT * FROM final
```

`ref()` 関数を使うと、dbtは自動的に依存関係を解決し、正しい順序で実行します。

### 実行順序の確認

```bash
dbt run
```

dbtは自動的に以下の順序で実行します：

1. `stg_customers`（ソースに依存）
2. `dim_customers`（`stg_customers`に依存）

## 4-7. テストを実行する

データ品質を確保するためにテストを実行します。

### テストの定義

```yaml
# models/staging/schema.yml
version: 2

models:
  - name: stg_customers
    columns:
      - name: customer_id
        tests:
          - unique
          - not_null
      - name: email
        tests:
          - unique
```

### テストの実行

```bash
dbt test
```

出力例：

```
Running with dbt=1.8.0
Found 2 models, 3 tests, 0 snapshots, 0 analyses, 0 macros, 0 operations

14:30:00  Concurrency: 4 threads (target='dev')
14:30:00
14:30:01  1 of 3 START test unique_stg_customers_customer_id ............... [RUN]
14:30:01  2 of 3 START test not_null_stg_customers_customer_id ............. [RUN]
14:30:01  3 of 3 START test unique_stg_customers_email ..................... [RUN]
14:30:02  1 of 3 PASS unique_stg_customers_customer_id ..................... [PASS in 1.23s]
14:30:02  2 of 3 PASS not_null_stg_customers_customer_id ................... [PASS in 1.23s]
14:30:02  3 of 3 PASS unique_stg_customers_email ........................... [PASS in 1.23s]

Finished running 3 tests in 0 hours 0 and 2.34 seconds (2.34s).

Completed successfully

Done. PASS=3 WARN=0 ERROR=0 SKIP=0 TOTAL=3
```

## 4-8. ドキュメントを生成する

### ドキュメントの生成

```bash
dbt docs generate
```

### ドキュメントの表示

```bash
dbt docs serve
```

ブラウザで `http://localhost:8080` が開き、以下が表示されます：

- **Overview**: プロジェクトの概要
- **Lineage Graph**: モデルの依存関係（DAG）
- **Model Details**: 各モデルの詳細情報

## 4-9. 開発ワークフロー

dbt開発の基本的なワークフローは以下の通りです：

```
1. モデルを作成/編集
   ↓
2. dbt run で実行
   ↓
3. 結果を確認
   ↓
4. dbt test でテスト
   ↓
5. 問題なければコミット
   ↓
6. 必要に応じて dbt docs でドキュメント更新
```

### よく使うコマンドの組み合わせ

```bash
# モデルを実行してテスト
dbt run && dbt test

# 特定のモデルのみ実行
dbt run --select stg_customers

# モデルとその依存先を実行
dbt run --select +dim_customers

# モデルとその被依存元を実行
dbt run --select stg_customers+
```

## 4-10. サンプルプロジェクトの実行

本書のサンプルプロジェクトを完全に実行してみましょう：

```bash
# sample-project ディレクトリで実行
cd ~/Studies/dbt/sample-project

# データをロード
dbt seed

# 全モデルを実行
dbt run

# 全テストを実行
dbt test

# ドキュメントを生成・表示
dbt docs generate
dbt docs serve
```

## まとめ

- `dbt init` でプロジェクトを作成
- `dbt seed` でCSVデータをロード
- `dbt run` でモデルを実行
- `dbt test` でデータ品質をテスト
- `dbt docs` でドキュメントを生成
- `source()` でソースを、`ref()` で他のモデルを参照
- dbtが自動的に依存関係を解決

入門編はこれで終了です。おめでとうございます！

次は初級編で、より実践的なdbtプロジェクトの構築方法を学びます。
