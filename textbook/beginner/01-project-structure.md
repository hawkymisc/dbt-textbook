---
title: "1. プロジェクト構造の理解"
---

# 1. プロジェクト構造の理解

この章では、dbtプロジェクトの構造と設定ファイルについて詳しく学びます。

## 1-1. Git管理のルール

まず、どのファイルをGit管理するかを理解しておきましょう：

| Git管理する | Git管理しない |
|------------|--------------|
| `dbt_project.yml` | `profiles.yml`（認証情報を含む） |
| `models/*.sql` | `target/`（生成物） |
| `sources.yml`, `schema.yml` | `dbt_packages/`（パッケージ） |
| `macros/*.sql` | `logs/`（ログ） |
| `seeds/*.csv` | `.venv/`（仮想環境） |
| `.gitignore` | |

:::message
`profiles.yml` には認証情報が含まれるため、**絶対にGitにコミットしない**でください。代わりに `profiles.yml.example` をコミットし、各自がコピーして使用します。
:::

## 1-2. dbtプロジェクトのディレクトリ構造

推奨されるディレクトリ構造は以下の通りです：

```
sample-project/
├── dbt_project.yml        # プロジェクト設定
├── profiles.yml.example   # 接続設定の例（Git管理）
├── .gitignore             # Git除外設定
├── README.md              # プロジェクトの説明
│
├── models/                # モデル（SQLファイル）
│   ├── staging/           # Staging層
│   │   ├── sources.yml    # ソース定義
│   │   └── stg_*.sql
│   ├── intermediate/      # Intermediate層
│   │   └── int_*.sql
│   └── marts/             # Marts層
│       ├── schema.yml     # テスト・ドキュメント定義
│       └── fct_*.sql / dim_*.sql
│
├── seeds/                 # シードデータ（CSV）
├── macros/                # マクロ
├── tests/                 # カスタムテスト
└── snapshots/             # スナップショット
```

## 1-3. dbt_project.ymlの設定

`dbt_project.yml` はプロジェクトの中心となる設定ファイルです：

### 必須の基本設定

```yaml
# プロジェクトの基本情報
name: 'sample_ec_project'
version: '1.0.0'
config-version: 2

# profiles.yml内のプロファイル名
profile: 'sample_ec_project'

# 各種ファイルの配置場所
model-paths: ["models"]
seed-paths: ["seeds"]
macro-paths: ["macros"]
test-paths: ["tests"]

# 生成物の出力先
target-path: "target"
clean-targets:
  - "target"
  - "dbt_packages"
```

### モデルの設定（レイヤーごと）

```yaml
models:
  sample_ec_project:
    staging:
      +materialized: view      # ビューとして作成
      +schema: staging         # スキーマ名（BigQueryではdataset）

    intermediate:
      +materialized: ephemeral # CTEとして展開

    marts:
      +materialized: table     # テーブルとして作成
      +schema: marts
```

:::message
`+schema: staging` とすると、BigQueryでは `dbt_dev_staging` のようにdataset名にサフィックスが付きます。
:::

### 設定の継承

設定は階層構造で継承されます：

```
dbt_project.yml（プロジェクト全体）
    └── models:（全モデル）
        └── staging:（stagingディレクトリ）
            └── stg_customers.sql（個別ファイル）
```

個別ファイルでの設定が最も優先されます。

### オプション設定（必要に応じて）

```yaml
# 変数の定義
vars:
  start_date: '2024-01-01'
  end_date: '2024-12-31'

# シードの設定
seeds:
  sample_ec_project:
    +schema: raw

# テストの設定
tests:
  sample_ec_project:
    +severity: error
```

## 1-4. profiles.ymlの構造

`profiles.yml` はデータウェアハウスへの接続設定を管理します。**Git管理外**です。

```yaml
# プロファイル名（dbt_project.ymlのprofileと対応）
sample_ec_project:
  target: dev  # デフォルトのターゲット

  outputs:
    # 開発環境
    dev:
      type: bigquery
      method: oauth
      project: my-gcp-project
      dataset: dbt_dev
      threads: 4
      location: asia-northeast1

    # 本番環境
    prod:
      type: bigquery
      method: service_account
      project: my-gcp-project
      dataset: dbt_prod
      keyfile: /path/to/keyfile.json
      threads: 8
```

### ターゲットの切り替え

```bash
dbt run --target dev   # 開発環境
dbt run --target prod  # 本番環境
```

### 環境変数の使用

```yaml
dev:
  type: bigquery
  project: "{{ env_var('GCP_PROJECT') }}"
  dataset: "{{ env_var('DBT_DATASET', 'dbt_dev') }}"  # デフォルト値付き
```

## 1-5. ソース（Sources）の定義

ソースは、生データがどこにあるかを定義します：

```yaml
# models/staging/sources.yml
version: 2

sources:
  - name: raw
    description: "ECサイトの生データ"
    database: my-project      # BigQueryの場合
    schema: raw_data          # dataset名
    loader: Fivetran

    tables:
      - name: customers
        description: "顧客マスタテーブル"
        freshness:
          warn_after: {count: 24, period: hour}
          error_after: {count: 48, period: hour}
        loaded_at_field: updated_at
        columns:
          - name: customer_id
            description: "顧客ID（主キー）"
            tests:
              - unique
              - not_null
```

:::message
`sources.yml` と `schema.yml`（モデル定義）は分けて管理することを推奨します。理由：ソースは外部データ、モデルは内部データと責任が異なるため。
:::

### ソースのメリット

1. **明示的な依存関係**: ソースとモデルの境界が明確
2. **データリネージ**: ドキュメントでソースまで追跡可能
3. **鮮度チェック**: データの更新頻度を監視

## 1-6. ディレクトリ構造のベストプラクティス

### レイヤー分け

```
models/
├── staging/      # 生データのクリーニング・正規化
├── intermediate/ # ビジネスロジック・結合・集計
└── marts/        # ビジネスユーザー向けの最終形
```

| レイヤー | 役割 | マテリアライゼーション |
|---------|------|---------------------|
| staging | ソースデータの読み込み・基本変換 | view |
| intermediate | 複雑な結合・集計・ビジネスロジック | ephemeral |
| marts | 分析・レポート用の最終モデル | table |

## 1-7. プロジェクトの初期化チェックリスト

新しいプロジェクトを作成する際のチェックリスト：

### Git管理対象

- [ ] `dbt init` でプロジェクト作成
- [ ] `dbt_project.yml` の設定
- [ ] `.gitignore` の設定
- [ ] ディレクトリ構造の作成（staging/intermediate/marts）
- [ ] `sources.yml` の作成
- [ ] `profiles.yml.example` の作成

### Git管理対象外（各自のローカル環境）

- [ ] `profiles.yml` の作成
- [ ] `dbt debug` で接続確認

## まとめ

- Git管理する/しないを最初に決める
- dbtプロジェクトは `dbt_project.yml` で設定
- 接続情報は `profiles.yml` で管理（**Git管理外**）
- ソースは `sources.yml`、モデルは `schema.yml` で定義（分ける）
- レイヤー分け（staging/intermediate/marts）が推奨

次の章では、モデルの作成について詳しく学びます。
