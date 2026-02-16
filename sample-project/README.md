# ECサイト dbt サンプルプロジェクト

このプロジェクトは、dbt教科書のハンズオン用サンプルプロジェクトです。

## 概要

ECサイトの注文データを分析するためのデータパイプラインを構築します。

### データセット

| テーブル | 説明 | レコード数 |
|---------|------|-----------|
| customers | 顧客マスタ | 10件 |
| products | 商品マスタ | 10件 |
| orders | 注文ヘッダ | 15件 |
| order_items | 注文明細 | 24件 |

### モデル構成

```
models/
├── staging/              # Staging層（生データの準備）
│   ├── sources.yml       # ソース定義
│   ├── stg_customers.sql
│   ├── stg_products.sql
│   ├── stg_orders.sql
│   └── stg_order_items.sql
│
├── intermediate/         # Intermediate層（ビジネスロジック）
│   ├── int_order_items_with_product.sql
│   └── int_orders_with_details.sql
│
└── marts/                # Marts層（最終成果物）
    ├── schema.yml        # テスト定義
    ├── fct_orders.sql
    ├── fct_daily_sales.sql
    └── dim_customers.sql
```

## セットアップ

### 前提条件

- Python 3.8+
- dbt Core 1.8+

### インストール

```bash
# 仮想環境の作成（推奨）
python -m venv .venv
source .venv/bin/activate

# dbtのインストール（DuckDBを使用する場合）
pip install dbt-duckdb

# または BigQueryを使用する場合
pip install dbt-bigquery
```

### プロファイルの設定

`~/.dbt/profiles.yml` を設定するか、以下のコマンドでプロジェクト内の設定を使用：

```bash
export DBT_PROFILES_DIR=.
```

#### DuckDB用設定

```yaml
sample_ec_project:
  target: dev
  outputs:
    dev:
      type: duckdb
      path: ./dev.duckdb
      threads: 4
```

#### BigQuery用設定

```yaml
sample_ec_project:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: oauth
      project: your-gcp-project-id
      dataset: dbt_dev
      threads: 4
      location: asia-northeast1
```

### データのロード

```bash
# サンプルデータをseedsディレクトリにコピー
cp ../data/raw/*.csv seeds/

# Seedsの実行
dbt seed
```

### 実行

```bash
# 全モデルの実行
dbt run

# テストの実行
dbt test

# ドキュメントの生成
dbt docs generate
dbt docs serve
```

## プロジェクト構造

```
sample-project/
├── README.md
├── dbt_project.yml       # プロジェクト設定
├── profiles.yml.example  # プロファイル設定例
├── models/               # モデル
│   ├── staging/
│   ├── intermediate/
│   └── marts/
├── seeds/                # CSVデータ
├── macros/               # マクロ
├── snapshots/            # スナップショット
└── tests/                # カスタムテスト
```

## モデルの説明

### Staging層

| モデル | 説明 |
|-------|------|
| stg_customers | 顧客データのクリーニング |
| stg_products | 商品データの変換（利益率計算） |
| stg_orders | 注文データの前処理 |
| stg_order_items | 注文明細の前処理 |

### Intermediate層

| モデル | 説明 |
|-------|------|
| int_order_items_with_product | 明細に商品情報を結合 |
| int_orders_with_details | 注文に顧客・集計情報を結合 |

### Marts層

| モデル | 説明 |
|-------|------|
| fct_orders | 注文ファクトテーブル |
| fct_daily_sales | 日次売上サマリー |
| dim_customers | 顧客ディメンション |

## よく使うコマンド

```bash
# 特定のモデルとその依存先を実行
dbt run --select +fct_orders

# 特定のモデルとその被依存元を実行
dbt run --select stg_orders+

# テストの実行
dbt test --select fct_orders

# コンパイル結果の確認
dbt compile --select stg_orders
cat target/compiled/sample_ec_project/models/staging/stg_orders.sql

# フルリフレッシュ
dbt run --full-refresh
```

## トラブルシューティング

### dbt debug

```bash
dbt debug
```

### ログの確認

```bash
# 詳細ログを出力
dbt run --debug
```

## 参考資料

- [dbt公式ドキュメント](https://docs.getdbt.com/)
- [dbt教科書](../textbook/README.md)

## ライセンス

MIT
