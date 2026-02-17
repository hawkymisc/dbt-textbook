---
title: "8. Hooks"
---

# 8. Hooks

この章では、dbt Hooksを使って、特定のタイミングでSQLを実行する方法を学びます。

## 8-1. Hooksとは

Hooksは、dbtの実行ライフサイクルの特定のタイミングでSQLを実行する機能です。

### 使用場面

- テーブル作成前の準備
- テーブル作成後の後処理
- 権限の付与
- ログの記録
- データのクリーンアップ

### Hooksの種類

| Hook | タイミング |
|------|----------|
| `on-run-start` | dbtコマンド開始時 |
| `on-run-end` | dbtコマンド終了時 |
| `pre-hook` | モデル実行前 |
| `post-hook` | モデル実行後 |

## 8-2. on-run-start / on-run-end

### dbt_project.ymlでの設定

```yaml
# dbt_project.yml

on-run-start:
  - "{{ log('dbt run started at ' ~ run_started_at, info=true) }}"
  - "CREATE TABLE IF NOT EXISTS audit.log (event_time TIMESTAMP, event_type VARCHAR, message VARCHAR)"

on-run-end:
  - "{{ log('dbt run completed', info=true) }}"
  - "INSERT INTO audit.log VALUES (CURRENT_TIMESTAMP(), 'run_end', 'Completed successfully')"
```

### 使用例：実行ログの記録

```yaml
on-run-start:
  - |
    CREATE TABLE IF NOT EXISTS {{ target.schema }}.run_history (
      run_id STRING,
      command STRING,
      started_at TIMESTAMP,
      completed_at TIMESTAMP,
      status STRING
    );
    INSERT INTO {{ target.schema }}.run_history (run_id, command, started_at, status)
    VALUES ('{{ invocation_id }}', '{{ flags.which }}', CURRENT_TIMESTAMP(), 'running')

on-run-end:
  - "UPDATE {{ target.schema }}.run_history SET completed_at = CURRENT_TIMESTAMP(), status = 'completed' WHERE run_id = '{{ invocation_id }}'"
```

## 8-3. pre-hook / post-hook

### モデルレベルでの設定

```sql
-- models/marts/fct_orders.sql
{{ config(
    materialized='table',
    pre_hook="""
        -- 実行前に一時テーブルをクリーンアップ
        DROP TABLE IF EXISTS {{ target.schema }}.temp_orders;
    """,
    post_hook="""
        -- 実行後にインデックスを作成
        CREATE INDEX IF NOT EXISTS idx_orders_date ON {{ this }} (order_date);

        -- 権限を付与
        GRANT SELECT ON {{ this }} TO ROLE analyst;
    """
) }}

SELECT * FROM {{ ref('stg_orders') }}
```

### dbt_project.ymlでの設定

```yaml
models:
  sample_ec_project:
    +post-hook:
      - "GRANT SELECT ON {{ this }} TO ROLE analyst"
      - "GRANT SELECT ON {{ this }} TO ROLE reader"

    marts:
      +post-hook:
        - "GRANT SELECT ON {{ this }} TO ROLE bi_tool"
```

## 8-4. 実践例

### 権限の付与（BigQuery）

```yaml
# dbt_project.yml
models:
  sample_ec_project:
    marts:
      +post-hook:
        - >
          {% if target.name == 'prod' %}
            GRANT `roles/bigquery.dataViewer` ON TABLE {{ this }} TO "group:analysts@example.com"
          {% endif %}
```

### データ品質チェック（post-hook）

```sql
{{ config(
    materialized='table',
    post-hook="""
        -- データが存在することを確認
        {% set result = run_query('SELECT COUNT(*) FROM ' ~ this.render()) %}
        {% set count = result.columns[0].values[0] %}
        {% if count == 0 %}
            {{ exceptions.raise_error('No data in table!') }}
        {% endif %}
    """
) }}
```

:::message
`run_query` は `agate.Table` オブジェクトを返すため、`result.columns[0].values[0]` で値を取り出す必要があります。また、`{{ this }}` の代わりに `{{ this.render() }}` を使うと完全なテーブル参照が取得できます。
:::

### 統計情報の更新（BigQuery）

```yaml
models:
  sample_ec_project:
    marts:
      +post-hook:
        - "ALTER TABLE {{ this }} SET OPTIONS (enable_statistics_extraction = true)"
```

### 一時テーブルの処理

```sql
{{ config(
    materialized='incremental',
    pre-hook="""
        -- 古い一時テーブルを削除
        DROP TABLE IF EXISTS {{ target.schema }}._temp_{{ this.name }};
    """,
    post-hook="""
        -- 処理完了後のクリーンアップ
        DROP TABLE IF EXISTS {{ target.schema }}._temp_{{ this.name }};
    """
) }}
```

## 8-5. マクロでのHooks

複雑なロジックはマクロに分離できます：

```sql
-- macros/grant_access.sql

{% macro grant_access(role='analyst') %}
    {% if target.name == 'prod' %}
        GRANT SELECT ON {{ this }} TO ROLE {{ role }};
    {% endif %}
{% endmacro %}
```

```sql
-- models/marts/fct_orders.sql
{{ config(
    materialized='table',
    post-hook="{{ grant_access('analyst') }}"
) }}

SELECT * FROM {{ ref('stg_orders') }}
```

## 8-6. hooks.ymlでの定義

Hooksを別ファイルに定義することもできます：

```yaml
# hooks.yml
version: 2

on-run-start:
  - "{{ log('Starting dbt run', info=true) }}"

on-run-end:
  - "{{ log('Completed dbt run', info=true) }}"
```

## 8-7. 実行順序

```
1. on-run-start（全体）
2. モデルごと:
   a. pre-hook
   b. モデルの実行
   c. post-hook
3. on-run-end（全体）
```

### 複数のhooksがある場合

```yaml
post-hook:
  - "GRANT SELECT ON {{ this }} TO ROLE a"  # 1番目に実行
  - "GRANT SELECT ON {{ this }} TO ROLE b"  # 2番目に実行
```

## 8-8. Hooksで使える変数

| 変数 | 説明 |
|-----|------|
| `{{ this }}` | 現在のモデルのテーブル名 |
| `{{ target }}` | ターゲット環境情報 |
| `{{ target.name }}` | ターゲット名（dev/prod等） |
| `{{ target.schema }}` | スキーマ名 |
| `{{ run_started_at }}` | 実行開始時刻 |
| `{{ invocation_id }}` | 実行ID |

## 8-9. 条件付きHooks

```yaml
# 本番環境のみ実行
+post-hook:
  - >
    {% if target.name == 'prod' %}
      GRANT SELECT ON {{ this }} TO ROLE analyst;
    {% endif %}

# 特定のマテリアライゼーションのみ
+post-hook:
  - >
    {% if config.get('materialized') == 'table' %}
      ANALYZE TABLE {{ this }};
    {% endif %}
```

## 8-10. トラブルシューティング

### Hooksが実行されない

```
原因: 構文エラー、または条件がfalse
解決: dbt run --debugでログを確認
```

### 権限エラー

```
原因: GRANT文の実行権限がない
解決: 適切な権限を持つサービスアカウントを使用
```

### Hooksの失敗がモデルに影響

```
原因: post-hookの失敗がモデル全体を失敗させる
解決: 必要に応じてエラーハンドリングを追加
```

## 8-11. Hooksのベストプラクティス

### DO（推奨）

```yaml
# ✅ マクロで複雑なロジックを分離
post-hook: "{{ grant_access('analyst') }}"

# ✅ 環境ごとに条件分岐
{% if target.name == 'prod' %}

# ✅ ログを残す
{{ log('Granting access to ' ~ role, info=true) }}
```

### DON'T（非推奨）

```yaml
# ❌ 長いSQLを直接記述
post-hook: "GRANT SELECT ...; GRANT INSERT ...; ANALYZE ..."

# ❌ 重要な処理をhooksに依存
# → 可能ならモデル自体に組み込む

# ❌ エラーハンドリングなし
```

## 8-12. サンプルプロジェクトへの適用

```yaml
# dbt_project.yml
on-run-start:
  - "{{ log('Starting dbt run for ' ~ target.name, info=true) }}"

models:
  sample_ec_project:
    marts:
      +post-hook:
        - >
          {% if target.name == 'prod' %}
            {{ log('Granting access to marts tables', info=true) }}
          {% endif %}
```

## まとめ

- Hooksで特定のタイミングにSQLを実行
- `on-run-start/end`: dbtコマンド全体の前後
- `pre-hook/post-hook`: 個別モデルの前後
- 権限付与、ログ記録、クリーンアップに活用
- 複雑なロジックはマクロに分離
- 環境ごとの条件分岐が可能

次の章では、CI/CDとデプロイについて学びます。
