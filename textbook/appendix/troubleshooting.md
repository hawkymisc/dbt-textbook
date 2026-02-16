---
title: "付録D: トラブルシューティング"
---

# トラブルシューティング

## よくあるエラーと解決方法

### 接続エラー

#### "Could not connect to BigQuery"

```
原因: 認証情報が正しく設定されていない
```

**解決方法**:
```bash
# OAuth認証をやり直す
gcloud auth application-default login

# プロジェクトを設定
gcloud config set project your-project-id

# 接続テスト
dbt debug
```

#### "Profile not found"

```
原因: profiles.yml の場所が間違っている
```

**解決方法**:
```bash
# デフォルトの場所に配置
mv profiles.yml ~/.dbt/profiles.yml

# または環境変数で指定
export DBT_PROFILES_DIR=/path/to/profiles
dbt debug
```

#### "Permission denied"

```
原因: データウェアハウスへの権限がない
```

**解決方法**:
- BigQuery: GCPコンソールでIAMロールを確認（BigQuery Data Editor等）
- Snowflake: ロールとウェアハウスへのアクセス権を確認

---

### モデルエラー

#### "Relation does not exist"

```
原因: 参照先のテーブル/モデルが存在しない
```

**解決方法**:
```bash
# 依存元のモデルを先に実行
dbt run --select +my_model

# または全モデルを実行
dbt run
```

#### "Compilation error in model"

```
原因: SQLまたはJinjaの構文エラー
```

**解決方法**:
```bash
# コンパイル結果を確認
dbt compile --select my_model
cat target/compiled/my_project/models/my_model.sql

# デバッグログを有効化
dbt --debug compile --select my_model
```

#### "Circular dependency detected"

```
原因: モデルが循環参照している
```

**解決方法**:
- モデルAがBを参照し、BがAを参照する構造を確認
- 参照関係を見直す

---

### テストエラー

#### "Found 1 duplicate value for order_id"

```
原因: unique_keyに重複がある
```

**解決方法**:
```sql
-- 重複を確認
SELECT order_id, COUNT(*)
FROM my_table
GROUP BY order_id
HAVING COUNT(*) > 1

-- 重複の原因を修正
```

#### "Found 5 null values for customer_id"

```
原因: 必須カラムにNULLが含まれる
```

**解決方法**:
```sql
-- NULLを確認
SELECT * FROM my_table WHERE customer_id IS NULL

-- ソースデータを修正、またはテスト条件を見直す
```

#### "Relationships test failed"

```
原因: 外部キーが参照先に存在しない
```

**解決方法**:
```sql
-- 存在しない値を確認
SELECT a.order_id, a.customer_id
FROM orders a
LEFT JOIN customers b ON a.customer_id = b.customer_id
WHERE b.customer_id IS NULL
```

---

### インクリメンタルエラー

#### "Duplicate records in incremental model"

```
原因: unique_keyの設定ミス、または条件の不備
```

**解決方法**:
```sql
-- unique_keyを確認
{{ config(
    materialized='incremental',
    unique_key='order_id'  -- 正しく設定
) }}

-- または条件を見直し
{% if is_incremental() %}
where updated_at > (select max(updated_at) from {{ this }})
{% endif %}

-- 必要ならフルリフレッシュ
dbt run --select my_model --full-refresh
```

#### "Data not updating in incremental model"

```
原因: is_incremental()の条件が正しくない
```

**解決方法**:
```sql
-- updated_atが更新されているか確認
-- 初回は全件、2回目以降は増分
{% if is_incremental() %}
where updated_at > (select coalesce(max(updated_at), '1900-01-01') from {{ this }})
{% endif %}
```

---

### パッケージエラー

#### "Package not found"

```
原因: パッケージ名またはバージョンが間違っている
```

**解決方法**:
```yaml
# packages.yml の構文を確認
packages:
  - package: dbt-labs/dbt_utils
    version: [">=1.0.0", "<2.0.0"]  # 正しいバージョン指定

# 再インストール
rm -rf dbt_packages
dbt deps
```

#### "Macro not found"

```
原因: パッケージがインストールされていない、または名前が間違っている
```

**解決方法**:
```bash
# パッケージをインストール
dbt deps

# マクロ名を確認
ls dbt_packages/dbt_utils/macros/
```

---

### パフォーマンス問題

#### "Query is too slow"

```
原因: 複雑なクエリ、インデックスなし、大量データ
```

**解決方法**:
```sql
-- BigQuery: パーティションとクラスタリング
{{ config(
    materialized='table',
    partition_by={"field": "date", "granularity": "day"},
    cluster_by=["customer_id"]
) }}

-- インクリメンタル化を検討
{{ config(materialized='incremental') }}

-- 中間モデルを追加して分割
```

#### "dbt run takes too long"

```
原因: モデル数が多い、不要なモデルを再実行
```

**解決方法**:
```bash
# 変更されたモデルのみ実行
dbt run --select state:modified+

# 特定のディレクトリのみ
dbt run --select marts.*

# スレッド数を調整
dbt run --threads 8
```

---

### Git/CI/CD問題

#### "Merge conflict in schema.yml"

```
原因: 複数のPRでschema.ymlを変更
```

**解決方法**:
```bash
# 手動でマージコンフリクトを解決
git checkout --theirs models/marts/schema.yml
# または
git checkout --ours models/marts/schema.yml

# 変更を再適用してコミット
```

#### "CI fails but local passes"

```
原因: 環境差異（プロファイル、変数、データ）
```

**解決方法**:
```bash
# CI環境の設定を確認
# - シークレットの設定
# - 環境変数の設定
# - ターゲットの指定

# デバッグログを出力
dbt --debug run
```

---

## デバッグテクニック

### 1. dbt debug

```bash
dbt debug
```
接続設定、プロジェクト設定を確認

### 2. コンパイル結果の確認

```bash
dbt compile --select my_model
cat target/compiled/my_project/models/path/to/my_model.sql
```
Jinjaが展開された実際のSQLを確認

### 3. 詳細ログ

```bash
dbt --debug run --select my_model
```
詳細な実行ログを出力

### 4. run_query マクロ

```sql
{% set result = run_query('SELECT COUNT(*) FROM ' ~ ref('my_model')) %}
{% do log(result, info=true) %}
```

### 5. assert文でデバッグ

```sql
{% set count = run_query('SELECT COUNT(*) FROM my_table')[0][0] %}
{% if count == 0 %}
    {{ exceptions.raise_error('No data found!') }}
{% endif %}
```

---

## サポートリソース

- [dbt公式ドキュメント](https://docs.getdbt.com/)
- [dbtコミュニティSlack](https://community.getdbt.com/)
- [GitHub Issues](https://github.com/dbt-labs/dbt-core/issues)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/dbt)
