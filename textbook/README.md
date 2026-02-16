---
title: "dbt実践ガイド：SQLだけで作るモダンなデータパイプライン"
summary: "SQLはわかるけどETLは本格的にやったことない人向けに、dbtのメリットと使い方を入門→初級→中級と順次説明していく教科書です。"
topics: ["dbt", "SQL", "ETL", "データ分析", "データエンジニアリング"]
published: false
price: 0
chapters:
  - introduction/01-invitation
  - introduction/02-overview
  - introduction/03-setup
  - introduction/04-hello-dbt
  - beginner/01-project-structure
  - beginner/02-models
  - beginner/03-materializations
  - beginner/04-layers
  - beginner/05-tests
  - intermediate/01-advanced-materializations
  - intermediate/02-jinja-macros
  - intermediate/03-packages
  - intermediate/04-documentation-lineage
  - intermediate/05-advanced-tests
  - intermediate/06-snapshots
  - intermediate/07-seeds
  - intermediate/08-hooks
  - intermediate/09-cicd-deployment
---

# dbt実践ガイド：SQLだけで作るモダンなデータパイプライン

## 本書の対象読者

本書は以下のような読者を想定しています：

- **SQLは書ける**（SELECT, JOIN, GROUP BY など基本的な構文を理解している）
- **ETL/ELTの概念は漠然とわかるが、実務経験はない**
- **データ分析やデータエンジニアリングに興味がある**

## 本書のゴール

本書を読み終える頃には、以下のことができるようになります：

1. dbtを使ったデータ変換パイプラインを構築できる
2. チームで開発しやすい構造でプロジェクトを整理できる
3. データ品質を確保するためのテストを書ける
4. 本格的な運用を見据えたCI/CD環境を構築できる

## 本書の構成

本書は3つのパートで構成されています：

### 📖 入門編
dbtとは何かを理解し、環境構築を完了します。最初のモデルを作成して動作確認まで行います。

### 📘 初級編
基本的なdbtプロジェクトを構築できるようになります。プロジェクト構造、モデル、マテリアライゼーション、テストの基本を学びます。

### 📕 中級編
本格的なデータパイプラインを構築・運用できるようになります。高度な機能、CI/CD、デプロイ戦略までをカバーします。

## 使用するデータウェアハウス

本書では主に **BigQuery** を使用して解説します。ただし、学習目的で **DuckDB** を使用することも可能です。

- **BigQuery**: 本格的な開発・本番環境向け（Google Cloudアカウントが必要）
- **DuckDB**: ローカル環境での学習用（インストールのみで使用可能）

## サンプルプロジェクト

本書の内容は、付属のサンプルプロジェクト（`sample-project/`）で実際に手を動かして学ぶことができます。

サンプルプロジェクトは「ECサイトの注文データ分析」を題材としており、以下のデータを扱います：

- 顧客データ（customers）
- 商品データ（products）
- 注文データ（orders）
- 注文明細データ（order_items）

## 必要な前提知識

本書を効果的に学ぶために、以下の知識があると望ましいです：

- **SQL**: SELECT, WHERE, JOIN, GROUP BY, ORDER BY などの基本構文
- **コマンドライン**: 基本的なcd, ls, cat などのコマンド
- **Git**: 基本的な使い方（commit, push, pull）

## 使用するツール

- **dbt Core**: オープンソース版のdbt（無料）
- **Python 3.8+**: dbt Coreの実行に必要
- **Git**: バージョン管理用

## フィードバック・お問い合わせ

本書に関するご質問やご意見は、GitHubリポジトリのIssueにてお受けしています。

---

それでは、dbtの世界へようこそ！
