---
title: "3. 環境構築"
---

# 3. 環境構築

この章では、dbtの開発環境を構築します。BigQueryとDuckDBの2つのパターンを解説します。

## 3-1. 前提条件

以下がインストールされていることを確認してください：

### 必須

- **Python 3.8以上**
- **Git**

### 推奨

- **VS Code**（または他のエディタ）
- **dbt Power User**（VS Code拡張機能）

## 3-2. Python環境の準備

### Pythonのバージョン確認

```bash
python --version
# Python 3.10.x 以上を推奨
```

### 仮想環境の作成（推奨）

```bash
# プロジェクトディレクトリに移動
cd ~/Studies/dbt

# 仮想環境を作成
python -m venv .venv

# 仮想環境を有効化
source .venv/bin/activate  # Linux/Mac
# .venv\Scripts\activate   # Windows
```

:::message
仮想環境を使用することで、プロジェクトごとに異なるパッケージバージョンを管理できます。強く推奨します。
:::

## 3-3. dbt Coreのインストール

### BigQueryを使用する場合

```bash
pip install dbt-bigquery
```

これにより、dbt-coreとdbt-bigqueryアダプタが一緒にインストールされます。

### DuckDBを使用する場合

```bash
pip install dbt-duckdb
```

### インストールの確認

```bash
dbt --version
```

以下のような出力が表示されれば成功です：

```
Core:
  - installed: 1.8.0
  - latest:    1.8.0

Plugins:
  - bigquery: 1.8.0 - Up to date!
```

## 3-4. プロファイルの設定

dbtは `profiles.yml` というファイルでデータウェアハウスへの接続設定を管理します。

### プロファイルの場所

デフォルトでは `~/.dbt/profiles.yml` に配置されます。

### BigQuery用の設定

#### 方法1: OAuth認証（推奨・学習用）

```yaml
# ~/.dbt/profiles.yml
sample_ec_project:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: oauth
      project: your-gcp-project-id
      dataset: dbt_dev
      threads: 4
      timeout_seconds: 300
      location: asia-northeast1
```

**前提条件**:
- Google Cloud SDKがインストールされていること
- `gcloud auth application-default login` を実行済み

#### 方法2: サービスアカウント

```yaml
sample_ec_project:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: service_account
      project: your-gcp-project-id
      dataset: dbt_dev
      keyfile: /path/to/service-account.json
      threads: 4
      timeout_seconds: 300
      location: asia-northeast1
```

### DuckDB用の設定

```yaml
# ~/.dbt/profiles.yml
sample_ec_project:
  target: dev
  outputs:
    dev:
      type: duckdb
      path: ./dev.duckdb
      threads: 4
```

または、メモリ上で動作させる場合：

```yaml
sample_ec_project:
  target: dev
  outputs:
    dev:
      type: duckdb
      path: ":memory:"
      threads: 1
```

:::message alert
**セキュリティ上の注意**

`profiles.yml` には認証情報が含まれるため、Gitにコミットしないでください。`.gitignore` に追加することを忘れないでください。
:::

## 3-5. BigQuery設定の詳細

BigQueryを使用する場合、以下の手順が必要です。

### Google Cloud SDKのインストール

```bash
# Linux
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Mac (Homebrew)
brew install google-cloud-sdk
```

### 認証の設定

```bash
# ユーザー認証
gcloud auth application-default login

# プロジェクトの設定
gcloud config set project your-gcp-project-id
```

### BigQuery APIの有効化

Google Cloud Console で BigQuery API を有効にしてください：

1. [Google Cloud Console](https://console.cloud.google.com/) にアクセス
2. 「APIとサービス」→「ライブラリ」
3. 「BigQuery API」を検索して有効化

## 3-6. 接続テスト

### dbt debugの実行

```bash
cd sample-project
dbt debug
```

成功すると以下のように表示されます：

```
dbt debug
Running with dbt=1.8.0
dbt version: 1.8.0
python version: 3.10.12
os info: Linux-6.5.0-14-generic-x86_64-with-glibc2.35
Using profiles.yml file at /home/user/.dbt/profiles.yml
Using dbt_project.yml file at /home/user/Studies/dbt/sample-project/dbt_project.yml

Configuration:
  profiles.yml file [OK found and valid]
  dbt_project.yml file [OK found and valid]

Required dependencies:
 - git [OK found]

Connection:
  method: oauth
  database: your-project-id
  schema: dbt_dev
  Connection test: [OK connection ok]
```

もしエラーが表示された場合は、設定を見直してください。

## 3-7. サンプルプロジェクトの準備

本書のサンプルプロジェクトを使用する場合：

```bash
# サンプルプロジェクトのディレクトリに移動
cd ~/Studies/dbt/sample-project

# サンプルデータをシードとしてロード（DuckDBの場合）
cp ../data/raw/*.csv seeds/

# 初回実行
dbt seed
dbt run
dbt test
```

## 3-8. VS Codeの設定（推奨）

### dbt Power User拡張機能

VS Codeに「dbt Power User」拡張機能をインストールすると、以下の機能が利用できます：

- シンタックスハイライト
- 自動補完
- ドキュメントのプレビュー
- クエリの実行
- リネージの可視化

### インストール方法

1. VS Codeの拡張機能タブを開く（`Ctrl+Shift+X` / `Cmd+Shift+X`）
2. 「dbt Power User」を検索
3. インストール

## 3-9. トラブルシューティング

### よくあるエラーと解決方法

#### エラー1: "Could not connect to BigQuery"

```
原因: 認証情報が正しく設定されていない
解決: gcloud auth application-default login を実行
```

#### エラー2: "Profile not found"

```
原因: profiles.yml の場所が間違っている
解決: ~/.dbt/profiles.yml に配置するか、
      環境変数 DBT_PROFILES_DIR でディレクトリを指定
```

#### エラー3: "Dataset not found"

```
原因: 指定したデータセットが存在しない
解決: BigQueryコンソールでデータセットを作成するか、
      dbtが自動作成するのを待つ
```

#### エラー4: Permission denied

```
原因: BigQueryへの権限がない
解決: GCPプロジェクトで適切なIAMロールを付与
      (BigQuery Data Editor, BigQuery Job User 等)
```

## 3-10. 環境構築のチェックリスト

以下を確認してください：

- [ ] Python 3.8以上がインストールされている
- [ ] dbt（dbt-bigquery または dbt-duckdb）がインストールされている
- [ ] `dbt --version` でバージョンが表示される
- [ ] `profiles.yml` が正しく設定されている
- [ ] `dbt debug` で接続テストが成功する

## まとめ

- dbt Coreは `pip install dbt-bigquery`（または `dbt-duckdb`）でインストール
- 接続設定は `~/.dbt/profiles.yml` に記述
- `dbt debug` で接続テストが可能
- BigQueryはOAuth認証が手軽でおすすめ
- DuckDBはローカル学習用に最適

次の章では、最初のモデルを作成して実行します。
