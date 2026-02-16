# dbt教科書プロジェクト

SQLはわかるがETLを本格的に実務でやったことのない人に向けて、dbtのメリットと使い方を入門→初級→中級と順次説明していく教科書プロジェクトです。

## プロジェクト構成

```
dbt/
├── textbook/           # 教科書本文（Zenn用Markdown）
│   ├── README.md       # 教科書の概要
│   ├── introduction/   # 入門編（4章）
│   ├── beginner/       # 初級編（5章）
│   ├── intermediate/   # 中級編（9章）
│   └── images/         # 画像ファイル
│
├── sample-project/     # サンプルdbtプロジェクト
│   ├── models/         # モデル（staging/intermediate/marts）
│   ├── seeds/          # CSVデータ
│   ├── macros/         # マクロ
│   └── snapshots/      # スナップショット
│
└── data/               # 元データ（CSV）
    └── raw/
```

## 教科書の内容

### 📖 入門編

| 章 | タイトル | 内容 |
|---|---------|------|
| 1 | dbtへの招待 | データパイプラインの課題とdbtの価値 |
| 2 | dbtの概要 | アーキテクチャ、主要コンポーネント |
| 3 | 環境構築 | BigQuery/DuckDBの設定 |
| 4 | Hello dbt | 最初のモデル作成 |

### 📘 初級編

| 章 | タイトル | 内容 |
|---|---------|------|
| 1 | プロジェクト構造の理解 | ディレクトリ構成、設定ファイル |
| 2 | モデルの作成 | ref/source関数、選択実行 |
| 3 | マテリアライゼーション | view/table/incremental/ephemeral |
| 4 | レイヤー構造 | staging/intermediate/marts |
| 5 | 基本的なテスト | unique/not_null/accepted_values/relationships |

### 📕 中級編

| 章 | タイトル | 内容 |
|---|---------|------|
| 1 | 高度なマテリアライゼーション | インクリメンタルの詳細設定 |
| 2 | Jinjaとマクロ | テンプレーティング、カスタムマクロ |
| 3 | パッケージの活用 | dbt_utils、dbt_expectations |
| 4 | ドキュメントとリネージ | 自動ドキュメント生成、DAG可視化 |
| 5 | 高度なテスト | カスタムテスト、テスト戦略 |
| 6 | Snapshots | データの履歴管理（SCD Type 2） |
| 7 | Seeds | CSVからのデータロード |
| 8 | Hooks | pre-hook/post-hook |
| 9 | CI/CDとデプロイ | GitHub Actions、dbt Cloud |

## サンプルプロジェクト

ECサイトの注文データを題材とした、完全に動作するdbtプロジェクトです。

### データセット

- **customers**: 顧客マスタ（10件）
- **products**: 商品マスタ（10件）
- **orders**: 注文ヘッダ（15件）
- **order_items**: 注文明細（24件）

### モデル構成

```
staging/           → 中間テーブル（クリーニング・正規化）
intermediate/      → ビジネスロジック（結合・集計）
marts/            → 最終成果物（ファクト・ディメンション）
```

### 実行方法

```bash
cd sample-project

# 仮想環境の作成
python -m venv .venv
source .venv/bin/activate

# dbtのインストール（DuckDB版）
pip install dbt-duckdb

# 実行
dbt seed
dbt run
dbt test
dbt docs generate
dbt docs serve
```

## 対象読者

- SQLは書ける（SELECT, JOIN, GROUP BY等）
- ETL/ELTの概念は漠然とわかるが、実務経験はない
- データ分析やデータエンジニアリングに興味がある

## 使用技術

- **dbt Core**: データ変換ツール
- **BigQuery**: メインのデータウェアハウス（推奨）
- **DuckDB**: ローカル学習用（代替）

## 参考資料

- [dbt公式ドキュメント](https://docs.getdbt.com/)
- [dbt Fundamentals Course](https://learn.getdbt.com/courses/dbt-fundamentals)
- [Best Practice Guides](https://docs.getdbt.com/best-practices)

## ライセンス

MIT
