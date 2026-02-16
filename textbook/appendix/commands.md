---
title: "付録B: コマンドリファレンス"
---

# コマンドリファレンス

## 基本コマンド

### dbt init
新しいdbtプロジェクトを作成します。

```bash
dbt init [project_name]
```

### dbt run
モデルを実行してテーブル/ビューを作成します。

```bash
dbt run                          # 全モデルを実行
dbt run --select my_model        # 特定のモデル
dbt run --select +my_model       # モデルとその依存元
dbt run --select my_model+       # モデルとその被依存先
dbt run --select staging.*       # ディレクトリ全体
dbt run --full-refresh           # フルリフレッシュ
dbt run --target prod            # 特定ターゲット
```

### dbt test
テストを実行します。

```bash
dbt test                         # 全テスト
dbt test --select my_model       # 特定モデルのテスト
dbt test --select test_type:unique  # 特定タイプのテスト
dbt test --select tag:critical   # タグで選択
```

### dbt compile
SQLをコンパイル（実行はしない）。

```bash
dbt compile                      # 全モデルをコンパイル
dbt compile --select my_model    # 特定のモデル
```

### dbt docs
ドキュメントを生成・表示します。

```bash
dbt docs generate                # ドキュメント生成
dbt docs serve                   # ローカルサーバーで表示
dbt docs serve --port 8081       # ポート指定
```

## データ管理

### dbt seed
CSVファイルからデータをロードします。

```bash
dbt seed                         # 全シード
dbt seed --select my_seed        # 特定のシード
dbt seed --full-refresh          # 既存データを削除して再作成
```

### dbt snapshot
スナップショットを実行します。

```bash
dbt snapshot                     # 全スナップショット
dbt snapshot --select my_snapshot  # 特定のスナップショット
```

## ユーティリティ

### dbt debug
接続と設定を診断します。

```bash
dbt debug
```

### dbt clean
生成物を削除します。

```bash
dbt clean                        # target/, dbt_packages/ を削除
```

### dbt deps
パッケージをインストールします。

```bash
dbt deps                         # packages.yml からインストール
dbt deps --upgrade               # アップグレード
```

### dbt list
リソースを一覧表示します。

```bash
dbt list                         # 全リソース
dbt list --resource-type model   # モデルのみ
dbt list --resource-type test    # テストのみ
dbt list --select staging.*      # 選択したリソース
```

### dbt parse
プロジェクトを解析（コンパイルはしない）。

```bash
dbt parse
```

### dbt build
コンパイル、シード、スナップショット、モデル実行、テストを一括実行。

```bash
dbt build                        # 全リソース
dbt build --select my_model      # 特定のモデル
dbt build --resource-type model  # モデルのみ
```

### dbt show
モデルのデータをプレビュー。

```bash
dbt show --select my_model       # モデルのプレビュー
dbt show --select my_model --limit 10  # 行数制限
```

### dbt source
ソースの鮮度チェック。

```bash
dbt source freshness             # 鮮度チェック実行
```

## 選択オプション

### --select / -s
リソースを選択します。

```bash
dbt run --select my_model
dbt run --select my_model+       # 下流（被依存先）を含む
dbt run --select +my_model       # 上流（依存元）を含む
dbt run --select +my_model+      # 両方向
dbt run --select tag:nightly     # タグで選択
dbt run --select staging.*       # ディレクトリで選択
dbt run --select resource_type:model  # タイプで選択
```

### --exclude
リソースを除外します。

```bash
dbt run --exclude my_model
dbt run --select staging.* --exclude stg_temp
```

## 実行オプション

### --target / -t
ターゲット環境を指定します。

```bash
dbt run --target prod
dbt run --target staging
```

### --full-refresh
フルリフレッシュを実行します。

```bash
dbt run --full-refresh
dbt run --select my_model --full-refresh
```

### --vars
変数を渡します。

```bash
dbt run --vars '{"start_date": "2024-01-01", "end_date": "2024-12-31"}'
```

### --threads
並列スレッド数を指定します。

```bash
dbt run --threads 8
```

### --profiles-dir
プロファイルディレクトリを指定します。

```bash
dbt run --profiles-dir /path/to/profiles
```

### --project-dir
プロジェクトディレクトリを指定します。

```bash
dbt run --project-dir /path/to/project
```

## グローバルオプション

### --debug
デバッグログを出力します。

```bash
dbt --debug run
```

### --quiet
最小限の出力にします。

```bash
dbt --quiet run
```

### --no-print
SQLを出力しません。

```bash
dbt --no-print compile
```

### --record-timing-info
タイミング情報を記録します。

```bash
dbt --record-timing-info timing.json run
```

## よく使う組み合わせ

```bash
# CI用: コンパイル、テスト、ビルド
dbt compile && dbt test && dbt run

# 特定モデルと依存関係
dbt run --select +fct_orders

# タグ付きモデルのテスト
dbt test --select tag:critical

# 本番デプロイ
dbt run --target prod --full-refresh

# ドキュメント更新
dbt docs generate && dbt docs serve

# 開発サイクル
dbt run --select my_model && dbt test --select my_model
```
