---
title: "4. ドキュメントとリネージ"
---

# 4. ドキュメントとリネージ

この章では、dbtの自動ドキュメント生成とデータリネージ機能について学びます。

## 4-1. ドキュメントの重要性

データパイプラインのドキュメント化は重要です：

- **どこにデータがあるか** を知る
- **データがどう変換されているか** を理解する
- **各フィールドの意味** を共有する
- **信頼性** を高める

dbtはコードから自動的にドキュメントを生成します。

## 4-2. 基本的なドキュメント生成

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
- **Lineage Graph**: データの流れ（DAG）
- **Project**: プロジェクト構造
- **Models**: 各モデルの詳細

## 4-3. モデルのドキュメント

### YAMLでの定義

```yaml
# models/marts/schema.yml
version: 2

models:
  - name: fct_orders
    description: |
      ## 注文ファクトテーブル

      このテーブルは、完了または発送済みの注文データを含みます。
      キャンセル・返品された注文は含まれません。

      ### 使用場面
      - 売上分析
      - 顧客行動分析
      - 日次レポート

      ### 注意事項
      - `total_amount` は税込み金額です
      - データは毎日更新されます

    meta:
      owner: data_team
      pii: false

    columns:
      - name: order_id
        description: "注文を一意に識別するID"
        tests:
          - unique
          - not_null
        meta:
          example: "ORD-2024-00001"

      - name: customer_id
        description: "注文した顧客のID"
        tests:
          - not_null
          - relationships:
              to: ref('dim_customers')
              field: customer_id

      - name: total_amount
        description: "注文の合計金額（税込み、円）"
        tests:
          - not_null
        meta:
          metric_type: currency
          unit: JPY

      - name: order_status
        description: "注文の現在のステータス"
        tests:
          - accepted_values:
              values: ['completed', 'shipped']

      - name: profit_margin
        description: "利益率（0〜1の小数）"
```

### Markdown形式のサポート

```yaml
description: |
  ## 注文ファクトテーブル

  ### 概要
  完了した注文のデータを含みます。

  ### 計算ロジック
  ```
  利益率 = (売上 - 原価) / 売上
  ```

  ### 関連ドキュメント
  - [売上の定義](/docs/glossary#revenue)
```

## 4-4. ソースのドキュメント

```yaml
# models/staging/sources.yml
version: 2

sources:
  - name: raw
    description: "ECサイトの生データ（Fivetranでロード）"
    database: "{{ env_var('GCP_PROJECT') }}"
    schema: raw_data
    loader: Fivetran
    loaded_at_field: _fivetran_synced

    tables:
      - name: orders
        description: |
          ## 注文データ

          ECサイトでの注文記録。
          リアルタイムで更新されます。

          ### データ品質
          - 重複: なし
          - 欠損: `shipping_address` に一部NULLあり

        freshness:
          warn_after: {count: 24, period: hour}
          error_after: {count: 48, period: hour}

        columns:
          - name: order_id
            description: "注文ID（主キー）"
          - name: customer_id
            description: "顧客ID"
          - name: order_status
            description: "注文ステータス"
```

## 4-5. メタデータ

### metaフィールド

```yaml
models:
  - name: fct_orders
    meta:
      owner: data_team
      team: analytics
      pii: false
      refresh_frequency: daily
      sla_hours: 6

    columns:
      - name: email
        meta:
          pii: true
          masking_policy: hash
```

### メタデータの活用

- チーム間での所有権の明確化
- PII（個人情報）の識別
- SLA（サービスレベル契約）の定義

## 4-6. データリネージ（DAG）

### リネージとは

データリネージは、データがどこから来て、どう変換され、どこへ行くかを示す地図です。

```
[Raw Data]
    ↓
[Staging] → 中間テーブル（クリーニング）
    ↓
[Intermediate] → 変換・結合
    ↓
[Marts] → 最終成果物
    ↓
[BI Tools] → ダッシュボード
```

### リネージの可視化

1. `dbt docs serve` でドキュメントを開く
2. 画面右下の「Lineage Graph」をクリック
3. ノードをクリックで詳細表示

### リネージの活用

- **影響範囲の確認**: モデル変更時の影響を確認
- **依存関係の理解**: どのモデルがどのデータを使っているか
- **デバッグ**: 問題のあるデータの原因特定

## 4-7. ドキュメントのカスタマイズ

### overview.md

プロジェクトの概要ページをカスタマイズできます：

```markdown
<!-- models/overview.md -->

{% docs __overview__ %}

# ECサイトデータウェアハウス

## プロジェクト概要

このdbtプロジェクトは、ECサイトの売上データを分析するための
データウェアハウスを構築・管理しています。

## データフロー

```
Raw Data → Staging → Intermediate → Marts
```

## 主要なモデル

| モデル | 説明 |
|-------|------|
| fct_orders | 注文ファクトテーブル |
| dim_customers | 顧客ディメンション |
| fct_daily_sales | 日次売上サマリー |

## お問い合わせ

データに関する質問は `data-team@example.com` まで。

{% enddocs %}
```

### ブロックドキュメント

```markdown
<!-- models/docs.md -->

{% docs order_status %}

## 注文ステータス

| 値 | 説明 |
|---|------|
| pending | 注文受付中 |
| shipped | 発送済み |
| completed | 完了 |
| cancelled | キャンセル |
| returned | 返品 |

{% enddocs %}
```

```yaml
# schema.yml
columns:
  - name: order_status
    description: "{{ doc('order_status') }}"
```

## 4-8. ドキュメントの永続化

データウェアハウスにドキュメントを永続化できます：

```yaml
# dbt_project.yml
models:
  sample_ec_project:
    +persist_docs:
      relation: true   # テーブル/ビューの説明を永続化
      columns: true    # カラムの説明を永続化
```

これにより、BigQueryなどのUIでドキュメントが表示されます。

## 4-9. CI/CDでのドキュメント生成

```yaml
# .github/workflows/dbt_docs.yml
name: Generate dbt Docs

on:
  push:
    branches: [main]

jobs:
  docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.10'

      - name: Install dbt
        run: pip install dbt-bigquery

      - name: Generate docs
        run: dbt docs generate

      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./target
```

## 4-10. ドキュメントのベストプラクティス

### DO（推奨）

```yaml
# ✅ 詳細な説明
- name: total_amount
  description: |
    注文の合計金額（税込み、日本円）。
    配送料は含まれません。

# ✅ メタデータの活用
meta:
  owner: data_team
  pii: false

# ✅ 関連情報へのリンク
description: |
  詳細は[用語集](/docs/glossary)を参照してください。
```

### DON'T（非推奨）

```yaml
# ❌ 説明なし
- name: total_amount

# ❌ 曖昧な説明
- name: total_amount
  description: "金額"

# ❌ 古い情報
description: "2023年のデータのみ"
```

## まとめ

- `dbt docs generate` でドキュメントを生成
- `dbt docs serve` でローカルサーバーを起動
- YAMLでモデル・カラムの説明を定義
- Markdownで詳細なドキュメントを記述
- `meta` フィールドでメタデータを追加
- リネージでデータの流れを可視化

次の章では、高度なテストについて学びます。
