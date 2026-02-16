---
title: "2. dbtの概要"
---

# 2. dbtの概要

この章では、dbtのアーキテクチャと基本的な概念を理解しましょう。

## 2-1. dbtとは

**dbt（data build tool）** は、SQLを使ってデータ変換パイプラインを構築するためのツールです。

公式サイトでは以下のように説明されています：

> dbt enables data analysts and engineers to transform their data using the same practices that software engineers use to build applications.
>
> （dbtは、ソフトウェアエンジニアがアプリケーションを構築する際と同じ手法で、データアナリストやエンジニアがデータを変換できるようにします。）

### dbtが「しない」こと

dbtを理解する上で重要なのは、dbtが**何をしないか**を知ることです：

| しないこと | 責任を持つツール |
|-----------|----------------|
| データの抽出（Extract） | Fivetran, Airbyte, カスタムスクリプト |
| データのロード（Load） | Fivetran, BigQuery Data Transfer |
| データの保存 | データウェアハウス（BigQuery, Snowflake等） |
| スケジューリング | dbt Cloud, Airflow, Prefect（※） |

**dbtがすること**: データの変換（Transform）のみ

:::message
（※）dbt Coreにはスケジューリング機能がないため、Airflow等の外部ツールが必要です。dbt Cloudには組み込みのスケジューリング機能があります。
:::

## 2-2. dbt Core vs dbt Cloud

dbtには2つのエディションがあります：

| 項目 | dbt Core | dbt Cloud |
|-----|----------|-----------|
| 料金 | 無料（OSS） | 有料（Freeプランあり） |
| インターフェース | CLI | Web UI + CLI |
| スケジューリング | 外部ツール必要 | 内蔵 ✓ |
| CI/CD | 手動設定 | 統合済み ✓ |
| 学習コスト | やや高め | 低い |

本書では主に **dbt Core** を使用します：

1. 無料で学習できる
2. 仕組みを深く理解できる
3. 本番環境での選択肢としても有力

:::message
dbt CloudのFreeプランは1ユーザー・1プロジェクトまで無料で使用できます。学習目的であれば十分です。
:::

## 2-3. dbtのアーキテクチャ

### 基本的な流れ

```
┌─────────────────────────────────────────────────────────────┐
│                     ソースデータ                             │
│  (Fivetran等でロードされた生データ)                         │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    Staging 層                               │
│  ・生データのクリーニング                                    │
│  ・カラム名の統一                                           │
│  ・materialized: view が一般的                              │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                  Intermediate 層                            │
│  ・ビジネスロジックの実装                                    │
│  ・結合と集計                                               │
│  ・materialized: ephemeral が一般的                         │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                      Marts 層                               │
│  ・ビジネスユーザー向けモデル                               │
│  ・materialized: table が一般的                             │
└─────────────────────────────────────────────────────────────┘
```

### 主要コンポーネント

| コンポーネント | 説明 |
|--------------|------|
| **Model（モデル）** | SQLファイルで定義されたデータ変換ロジック。1ファイル=1テーブル/ビュー |
| **Source（ソース）** | 生データの定義。外部システムからロードされたデータを指す |
| **Seed（シード）** | CSVファイルからの静的データ（マスタデータ等） |
| **Macro（マクロ）** | 再利用可能なSQLコード片（関数のようなもの） |
| **Test（テスト）** | データ品質を検証するルール |
| **Snapshot（スナップショット）** | データの履歴管理 |
| **Documentation（ドキュメント）** | モデルの説明とリネージ |

## 2-4. dbtの主要コマンド

### ★ まず覚える4つのコマンド

| コマンド | 説明 | 使用頻度 |
|---------|------|---------|
| `dbt run` | モデルを実行してテーブル/ビューを作成 | 毎日 |
| `dbt test` | テストを実行 | 毎日 |
| `dbt docs generate` | ドキュメントを生成 | 週次 |
| `dbt docs serve` | ドキュメントをローカルサーバーで表示 | 必要時 |

### 必要に応じて覚えるコマンド

| コマンド | 説明 |
|---------|------|
| `dbt init` | 新しいプロジェクトを作成（最初の1回のみ） |
| `dbt debug` | 接続設定を確認（トラブル時） |
| `dbt compile` | SQLをコンパイル（実行はしない） |
| `dbt clean` | 生成物を削除 |
| `dbt deps` | パッケージをインストール（パッケージ使用時） |

## 2-5. 対応データウェアハウス

dbtは**アダプタ**（adapter）と呼ばれるプラグインを通じて、様々なデータウェアハウスに対応しています。アダプタはPythonパッケージとしてインストールします。

### 主要アダプタ

| インストールコマンド | データウェアハウス |
|-------------------|------------------|
| `pip install dbt-bigquery` | Google BigQuery |
| `pip install dbt-snowflake` | Snowflake |
| `pip install dbt-redshift` | Amazon Redshift |
| `pip install dbt-postgres` | PostgreSQL |
| `pip install dbt-duckdb` | DuckDB |
| `pip install dbt-spark` | Apache Spark / Databricks |

本書では主に **BigQuery** を使用しますが、**DuckDB** も学習用として使用できます。

:::message alert
**DuckDBの利点**

DuckDBはローカル環境で動作する軽量なデータベースです：
- クラウドアカウントが不要
- 課金を気にせず学習できる
- `pip install dbt-duckdb` だけでOK
- `profiles.yml` で `type: duckdb` を設定

学習目的や小規模なプロジェクトには最適です。
:::

## 2-6. Jinjaテンプレートの基礎

dbtはJinjaテンプレートエンジンを使用して、SQLに動的な要素を追加できます。

### なぜJinjaを使うのか

```sql
-- ❌ Jinjaを使わない場合：テーブル名をハードコード
SELECT * FROM my_project.raw.orders

-- 問題点：
-- 1. 環境（dev/prod）が変わるたびに書き換えが必要
-- 2. テーブル名のタイポに気づかない
-- 3. 依存関係が追えない

-- ✅ Jinjaを使う場合：ref()で参照
SELECT * FROM {{ ref('stg_orders') }}

-- メリット：
-- 1. dbtが自動的にテーブル名を解決
-- 2. 環境ごとの切り替えが自動
-- 3. 依存関係がDAGで可視化される
```

### 最初に覚える2つの関数

```sql
-- 他のモデルを参照
SELECT * FROM {{ ref('stg_orders') }}

-- ソース（生データ）を参照
SELECT * FROM {{ source('raw', 'orders') }}
```

この2つだけ覚えれば、基本的なモデルは作成できます。

### その他の構文（中級編で解説）

```sql
-- 条件分岐
{% if is_incremental() %}
WHERE created_at > (SELECT MAX(created_at) FROM {{ this }})
{% endif %}

-- ループ
{% for column in ['a', 'b', 'c'] %}
SUM({{ column }}) as {{ column }}_sum
{% endfor %}
```

:::message
`{{ this }}` は「このモデル自身」を指す特別な変数です。例えば `fct_orders.sql` 内で `{{ this }}` を使うと、`fct_orders` テーブルを指します。
:::

## 2-7. マテリアライゼーション

マテリアライゼーションは、モデルがどのようにデータウェアハウスに実体化されるかを決定します：

| タイプ | 説明 | 使用場面 | 典型的なレイヤー |
|-------|------|---------|----------------|
| **view** | ビューとして作成 | 変更が少ないモデル | staging |
| **table** | テーブルとして作成 | 頻繁にクエリされる | marts |
| **incremental** | 増分更新 | 大量データ | 中級編で解説 |
| **ephemeral** | CTEとして展開 | 中間モデル | intermediate |

```sql
-- モデル内で設定
{{ config(materialized='table') }}

SELECT * FROM {{ ref('stg_orders') }}
```

デフォルトは `view` です。初級編第3章で詳しく解説します。

## まとめ

- dbtはデータの変換（Transform）に特化したツール
- dbt Core（無料・CLI）と dbt Cloud（有料・Web UI）がある
- 主なコンポーネントは Model, Source, Test, Macro, Snapshot
- まず覚えるコマンドは `dbt run` `dbt test` `dbt docs`
- Jinjaの `ref()` と `source()` でテーブルを参照
- マテリアライゼーションでデータの実体化方法を制御

次の章では、実際に環境構築を行います。
