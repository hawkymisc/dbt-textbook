---
title: "3. パッケージの活用"
---

# 3. パッケージの活用

この章では、dbtパッケージを使って、コミュニティの成果物を活用する方法を学びます。

## 3-1. パッケージとは

dbtパッケージは、再利用可能なモデル、マクロ、テストを含むdbtプロジェクトです。

npm（Node.js）やpip（Python）のように、dbt Hubからパッケージをインストールできます。

### パッケージでできること

- 共通のユーティリティマクロを使用
- ソースデータのクリーンアップ
- テストの拡張
- ドキュメント生成の強化

## 3-2. パッケージのインストール

### packages.ymlの作成

```yaml
# packages.yml
packages:
  - package: dbt-labs/dbt_utils
    version: 1.1.1

  - package: dbt-labs/codegen
    version: 0.12.1

  - package: calogica/dbt_expectations
    version: 0.10.3
```

### インストールの実行

```bash
dbt deps
```

**出力例**:
```
Running with dbt=1.8.0
Installing dbt-labs/dbt_utils@1.1.1
  Installed from revision 1.1.1
Installing dbt-labs/codegen@0.12.1
  Installed from revision 0.12.1
Installing calogica/dbt_expectations@0.10.3
  Installed from revision 0.10.3

Updates available for packages: dbt-labs/dbt_utils
```

### インストール場所

パッケージは `dbt_packages/` ディレクトリにインストールされます。

```
sample-project/
├── dbt_packages/        # インストールされたパッケージ
│   ├── dbt_utils/
│   ├── codegen/
│   └── dbt_expectations/
├── dbt_project.yml
└── packages.yml
```

## 3-3. 主要なパッケージ

### dbt_utils（必須）

最も広く使われているユーティリティパッケージです。

```yaml
packages:
  - package: dbt-labs/dbt_utils
    version: [">=1.0.0", "<2.0.0"]
```

#### よく使うマクロ

```sql
-- サロゲートキー生成
{{ dbt_utils.generate_surrogate_key(['customer_id', 'order_id']) }}

-- 日付スパイン
{{ dbt_utils.date_spine(
    "day",
    "DATE '2024-01-01'",
    "DATE '2024-12-31'"
) }}

-- 安全な除算
{{ dbt_utils.safe_divide('numerator', 'denominator') }}

-- スターマークアップ
{{ dbt_utils.star(from=ref('stg_orders'), except=['created_at', 'updated_at']) }}
```

#### よく使うテスト

```yaml
# 行数比較
tests:
  - dbt_utils.equal_rowcount:
      compare_model: ref('source_table')

# 式がtrue
tests:
  - dbt_utils.expression_is_true:
      expression: "total_amount >= 0"

# 重複なし
tests:
  - dbt_utils.unique_combination_of_columns:
      combination_of_columns:
        - customer_id
        - order_date
```

### dbt_expectations

データ品質テストを拡張するパッケージです。

```yaml
packages:
  - package: calogica/dbt_expectations
    version: 0.10.3
```

#### 使用例

```yaml
# 数値の範囲チェック
- name: total_amount
  tests:
    - dbt_expectations.expect_column_values_to_be_between:
        min_value: 0
        max_value: 1000000

# 正規表現マッチ
- name: email
  tests:
    - dbt_expectations.expect_column_values_to_match_regex:
        regex: "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"

# 日付の範囲
- name: order_date
  tests:
    - dbt_expectations.expect_column_values_to_be_between:
        min_value: "'2020-01-01'"
        max_value: "CURRENT_DATE()"

# ユニークな組み合わせ
- name: customer_id
  tests:
    - dbt_expectations.expect_compound_columns_to_be_unique:
        column_list: ["customer_id", "order_date"]
```

### codegen

コード生成を自動化するパッケージです。

```yaml
packages:
  - package: dbt-labs/codegen
    version: 0.12.1
```

#### ソースYAMLの生成

```bash
dbt run-operation generate_source --args '{"schema_name": "raw", "database_name": "my_project"}'
```

#### モデルYAMLの生成

```bash
dbt run-operation generate_model_yaml --args '{"model_name": "stg_orders"}'
```

## 3-4. パッケージの参照

### マクロの参照

```sql
-- パッケージ名を明示的に指定
{{ dbt_utils.generate_surrogate_key(['id']) }}

-- 省略も可能（名前が一意な場合）
{{ generate_surrogate_key(['id']) }}
```

### モデルの参照

```sql
-- パッケージ内のモデル
SELECT * FROM {{ ref('dbt_utils', 'date_spine') }}
```

## 3-5. バージョン管理

### バージョンの指定方法

```yaml
packages:
  # 特定バージョン
  - package: dbt-labs/dbt_utils
    version: 1.1.1

  # 範囲指定
  - package: dbt-labs/dbt_utils
    version: [">=1.0.0", "<2.0.0"]

  # 最新版（非推奨）
  - package: dbt-labs/dbt_utils
    version: latest

  # Gitブランチ
  - git: "https://github.com/dbt-labs/dbt-utils.git"
    revision: "main"

  # ローカルパス
  - local: /path/to/local/package
```

### バージョンのベストプラクティス

```yaml
# ✅ 範囲指定（マイナーバージョン更新を許可）
packages:
  - package: dbt-labs/dbt_utils
    version: [">=1.0.0", "<2.0.0"]

# ❌ 最新版（予期しない変更が入る可能性）
packages:
  - package: dbt-labs/dbt_utils
    version: latest
```

## 3-6. パッケージの更新

```bash
# 更新の確認
dbt list --output json | jq '.[] | select(.resource_type == "package")'

# 更新の実行
dbt deps --upgrade
```

## 3-7. サンプルプロジェクトへの適用

サンプルプロジェクトにパッケージを追加しましょう。

```yaml
# packages.yml
packages:
  - package: dbt-labs/dbt_utils
    version: [">=1.0.0", "<2.0.0"]
```

```bash
dbt deps
```

### 使用例

```sql
-- models/marts/fct_orders.sql
{{ config(materialized='table') }}

with orders as (
    select * from {{ ref('int_orders_with_details') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['order_id']) }} as order_key,
    order_id,
    customer_id,
    customer_name,
    order_status,
    total_amount,
    order_date,
    -- 利益率（ゼロ除算対策）
    {{ dbt_utils.safe_divide('total_profit', 'calculated_total') }} as profit_margin
from orders
where order_status in ('completed', 'shipped')
```

```yaml
# models/marts/schema.yml（追加のテスト）
models:
  - name: fct_orders
    columns:
      - name: total_amount
        tests:
          - dbt_utils.expression_is_true:
              expression: ">= 0"
              config:
                severity: warn

      - name: profit_margin
        tests:
          - dbt_utils.expression_is_true:
              expression: "BETWEEN 0 AND 1"
```

## 3-8. その他の便利なパッケージ

### dbt_date

日付操作のためのパッケージ

```yaml
packages:
  - package: calogica/dbt_date
    version: 0.10.0
```

```sql
-- 日付ディメンションの生成
{{ dbt_date.get_date_dimension("2024-01-01", "2024-12-31") }}
```

### audit_helper

データ品質監査のためのパッケージ

```yaml
packages:
  - package: dbt-labs/audit_helper
    version: 0.9.0
```

```sql
-- モデル比較
{{ audit_helper.compare_column_values(
    a_model=ref("old_model"),
    b_model=ref("new_model"),
    primary_key="id"
) }}
```

### re_data

データ監視のためのパッケージ

```yaml
packages:
  - package: re-data/re_data
    version: 1.2.0
```

## 3-9. パッケージ開発

自社固有のパッケージを開発することもできます。

### 基本構造

```
my-dbt-package/
├── dbt_project.yml
├── README.md
├── macros/
│   ├── my_macro.sql
│   └── ...
├── models/
│   └── ...
└── tests/
    └── ...
```

### dbt_project.yml

```yaml
name: 'my_dbt_package'
version: '1.0.0'
config-version: 2

# このパッケージが使用するモデルの設定
models:
  my_dbt_package:
    +materialized: ephemeral
```

### 公開方法

1. GitHubリポジトリを作成
2. タグを付けてプッシュ
3. dbt Hubに自動的にインデックスされる

## 3-10. パッケージ管理のベストプラクティス

### チェックリスト

- [ ] バージョンを範囲指定で固定
- [ ] 不要なパッケージは削除
- [ ] 定期的にアップデート
- [ ] `dbt_packages/` を `.gitignore` に追加
- [ ] セキュリティアップデートを確認

### .gitignore

```gitignore
# dbt packages
dbt_packages/
```

## まとめ

- パッケージは `packages.yml` で定義
- `dbt deps` でインストール
- `dbt_utils` は必須級のパッケージ
- バージョンは範囲指定で管理
- 自社パッケージの開発も可能

次の章では、ドキュメントとリネージについて学びます。
