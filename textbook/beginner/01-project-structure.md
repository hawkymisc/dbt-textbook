---
title: "1. プロジェクト構造の理解"
---

# 1. プロジェクト構造の理解

この章では、dbtプロジェクトの構造と設定ファイルについて詳しく学びます。

## 1-1. dbtプロジェクトのディレクトリ構造

推奨されるディレクトリ構造は以下の通りです：

```
sample-project/
├── dbt_project.yml        # プロジェクト設定
├── profiles.yml.example   # 接続設定の例
├── README.md              # プロジェクトの説明
│
├── models/                # モデル（SQLファイル）
│   ├── staging/           # Staging層
│   │   ├── sources.yml    # ソース定義
│   │   ├── stg_customers.sql
│   │   ├── stg_products.sql
│   │   ├── stg_orders.sql
│   │   └── stg_order_items.sql
│   │
│   ├── intermediate/      # Intermediate層
│   │   ├── int_order_items_with_product.sql
│   │   └── int_orders_with_details.sql
│   │
│   └── marts/             # Marts層
│       ├── schema.yml     # テスト・ドキュメント定義
│       ├── fct_orders.sql
│       ├── fct_daily_sales.sql
│       └── dim_customers.sql
│
├── seeds/                 # シードデータ（CSV）
│   ├── customers.csv
│   ├── products.csv
│   ├── orders.csv
│   └── order_items.csv
│
├── macros/                # マクロ（再利用可能な関数）
│   └── generate_surrogate_key.sql
│
├── tests/                 # カスタムテスト
│   └── assert_positive_amount.sql
│
├── snapshots/             # スナップショット（履歴管理）
│   └── products_snapshot.sql
│
├── analyses/              # 分析用クエリ（実行されない）
│   └── adhoc_analysis.sql
│
└── target/                # 生成物（git管理しない）
    └── ...
```

## 1-2. dbt_project.ymlの詳細設定

`dbt_project.yml` はプロジェクトの中心となる設定ファイルです：

```yaml
# プロジェクトの基本情報
name: 'sample_ec_project'
version: '1.0.0'
config-version: 2

# profiles.yml内のプロファイル名
profile: 'sample_ec_project'

# 各種ファイルの配置場所
model-paths: ["models"]
analysis-paths: ["analyses"]
test-paths: ["tests"]
seed-paths: ["seeds"]
macro-paths: ["macros"]
snapshot-paths: ["snapshots"]

# 生成物の出力先
target-path: "target"
clean-targets:
  - "target"
  - "dbt_packages"

# 変数の定義（オプション）
vars:
  start_date: '2024-01-01'
  end_date: '2024-12-31'

# モデルの設定
models:
  sample_ec_project:
    # Staging層
    staging:
      +materialized: view      # ビューとして作成
      +schema: staging         # スキーマ名にプレフィックスを追加

    # Intermediate層
    intermediate:
      +materialized: ephemeral # CTEとして展開（物理テーブルを作らない）
      +schema: intermediate

    # Marts層
    marts:
      +materialized: table     # テーブルとして作成
      +schema: marts

# シードの設定
seeds:
  sample_ec_project:
    +schema: raw
    # カラム型の指定（オプション）
    customers:
      +column_types:
        customer_id: integer
        email: varchar(100)

# テストの設定
tests:
  sample_ec_project:
    +severity: error           # テスト失敗時の深刻度
    +store_failures: true      # 失敗レコードを保存
```

### 設定の継承

設定は階層構造で継承されます：

```
dbt_project.yml（プロジェクト全体）
    └── models:（全モデル）
        └── staging:（stagingディレクトリ）
            └── stg_customers.sql（個別ファイル）
```

個別ファイルでの設定が最も優先されます。

## 1-3. profiles.ymlの構造

`profiles.yml` はデータウェアハウスへの接続設定を管理します：

```yaml
# プロファイル名（dbt_project.ymlのprofileと対応）
sample_ec_project:
  # デフォルトのターゲット
  target: dev

  # 各環境の設定
  outputs:
    # 開発環境
    dev:
      type: bigquery
      method: oauth
      project: my-gcp-project
      dataset: dbt_dev
      threads: 4
      timeout_seconds: 300
      location: asia-northeast1

    # 本番環境
    prod:
      type: bigquery
      method: service_account
      project: my-gcp-project
      dataset: dbt_prod
      keyfile: /path/to/keyfile.json
      threads: 8
      timeout_seconds: 600
      location: asia-northeast1
```

### ターゲットの切り替え

```bash
# 開発環境で実行
dbt run --target dev

# 本番環境で実行
dbt run --target prod
```

### 環境変数の使用

セキュリティのため、機密情報は環境変数で管理できます：

```yaml
sample_ec_project:
  target: dev
  outputs:
    dev:
      type: bigquery
      project: "{{ env_var('GCP_PROJECT') }}"
      dataset: "{{ env_var('DBT_DATASET', 'dbt_dev') }}"
```

```bash
export GCP_PROJECT=my-project
dbt run
```

## 1-4. ソース（Sources）の定義

ソースは、生データがどこにあるかを定義します：

```yaml
# models/staging/sources.yml
version: 2

sources:
  - name: raw
    description: "ECサイトの生データ"
    database: my-project      # BigQueryの場合
    schema: raw_data
    loader: Fivetran          # データをロードしたツール（ドキュメント用）

    tables:
      - name: customers
        description: "顧客マスタテーブル"
        freshness:            # データの鮮度チェック
          warn_after: {count: 24, period: hour}
          error_after: {count: 48, period: hour}
        loaded_at_field: updated_at
        columns:
          - name: customer_id
            description: "顧客ID（主キー）"
            tests:
              - unique
              - not_null

      - name: orders
        description: "注文ヘッダテーブル"
        columns:
          - name: order_id
            tests:
              - unique
              - not_null
          - name: customer_id
            tests:
              - relationships:
                  to: source('raw', 'customers')
                  field: customer_id
```

### ソースのメリット

1. **明示的な依存関係**: ソースとモデルの境界が明確
2. **データリネージ**: ドキュメントでソースまで追跡可能
3. **鮮度チェック**: データの更新頻度を監視
4. **再利用性**: 環境ごとに切り替えが容易

## 1-5. ディレクトリ構造のベストプラクティス

### レイヤー分け

```
models/
├── staging/      # 生データのクリーニング・正規化
├── intermediate/ # ビジネスロジック・結合・集計
└── marts/        # ビジネスユーザー向けの最終形
```

各レイヤーの役割：

| レイヤー | 役割 | マテリアライゼーション |
|---------|------|---------------------|
| staging | ソースデータの読み込み・基本変換 | view |
| intermediate | 複雑な結合・集計・ビジネスロジック | ephemeral |
| marts | 分析・レポート用の最終モデル | table |

### ドメイン分け（大規模プロジェクトの場合）

```
models/
├── staging/
│   ├── sales/
│   ├── marketing/
│   └── finance/
├── intermediate/
│   ├── sales/
│   ├── marketing/
│   └── finance/
└── marts/
    ├── sales/
    ├── marketing/
    └── finance/
```

## 1-6. .gitignoreの設定

Gitで管理すべきでないファイルを設定します：

```gitignore
# dbt生成物
target/
dbt_packages/

# ログ
logs/

# 環境固有の設定
profiles.yml

# OS固有のファイル
.DS_Store
Thumbs.db

# IDE設定
.vscode/
.idea/

# 仮想環境
.venv/
venv/
```

## 1-7. プロジェクトの初期化チェックリスト

新しいプロジェクトを作成する際のチェックリスト：

- [ ] `dbt init` でプロジェクト作成
- [ ] `dbt_project.yml` の設定
- [ ] `profiles.yml` の作成（Git管理外）
- [ ] `.gitignore` の設定
- [ ] ディレクトリ構造の作成（staging/intermediate/marts）
- [ ] `sources.yml` の作成
- [ ] `dbt debug` で接続確認

## まとめ

- dbtプロジェクトは `dbt_project.yml` で設定を管理
- 接続情報は `profiles.yml` で管理（Git管理外）
- ソースは `sources.yml` で定義
- レイヤー分け（staging/intermediate/marts）が推奨
- 設定は階層構造で継承される

次の章では、モデルの作成について詳しく学びます。
