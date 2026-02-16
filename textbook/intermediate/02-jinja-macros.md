---
title: "2. Jinjaとマクロ"
---

# 2. Jinjaとマクロ

この章では、Jinjaテンプレートエンジンとdbtマクロを使って、より柔軟なモデルを作成する方法を学びます。

## 2-1. Jinjaとは

JinjaはPython製のテンプレートエンジンです。dbtはJinjaを使用して、SQLに動的な要素を追加できます。

### 基本的な構文

```jinja
{{ ... }}    # 変数や式の出力
{% ... %}    # 制御構造（if, for等）
{# ... #}    # コメント
```

### dbtでの使用例

```sql
-- 変数の出力
SELECT * FROM {{ ref('stg_orders') }}

-- 条件分岐
{% if is_incremental() %}
WHERE updated_at > (SELECT MAX(updated_at) FROM {{ this }})
{% endif %}
```

## 2-2. 変数

### プロジェクト変数

```yaml
# dbt_project.yml
vars:
  start_date: '2024-01-01'
  end_date: '2024-12-31'
  exclude_test_users: true
```

```sql
-- モデルでの使用
SELECT *
FROM {{ ref('stg_orders') }}
WHERE order_date >= '{{ var("start_date") }}'
  AND order_date <= '{{ var("end_date") }}'

{% if var("exclude_test_users") %}
  AND customer_id NOT IN (SELECT customer_id FROM test_users)
{% endif %}
```

### コマンドライン変数

```bash
dbt run --vars '{"start_date": "2024-06-01", "end_date": "2024-06-30"}'
```

### デフォルト値

```sql
SELECT *
FROM {{ ref('stg_orders') }}
WHERE order_date >= '{{ var("start_date", "2024-01-01") }}'
```

## 2-3. 制御構造

### if文

```sql
{% if var("environment") == "production" %}
    -- 本番環境用の処理
    SELECT * FROM {{ source('prod', 'orders') }}
{% else %}
    -- 開発環境用の処理
    SELECT * FROM {{ source('dev', 'orders') }}
{% endif %}
```

### if-elif-else

```sql
{% set payment_method = var("payment_method", "all") %}

SELECT *
FROM {{ ref('stg_orders') }}
{% if payment_method == "credit_card" %}
    WHERE payment_method = 'credit_card'
{% elif payment_method == "bank_transfer" %}
    WHERE payment_method = 'bank_transfer'
{% else %}
    -- 全て
{% endif %}
```

### for文

```sql
SELECT
    {% for column in ['order_id', 'customer_id', 'total_amount'] %}
        {{ column }}{{ "," if not loop.last }}
    {% endfor %}
FROM {{ ref('stg_orders') }}
```

**生成されるSQL**:
```sql
SELECT
    order_id,
    customer_id,
    total_amount
FROM ...
```

### for文でテーブル操作

```sql
SELECT
    {% for column in adapter.get_columns_in_relation(ref('stg_orders')) %}
        {{ column.name }}{{ "," if not loop.last }}
    {% endfor %}
FROM {{ ref('stg_orders') }}
```

## 2-4. マクロとは

マクロは、再利用可能なSQLコードの断片です。関数のようなものです。

### 基本的なマクロ

```sql
-- macros/format_date.sql
{% macro format_date(date_column) %}
    DATE_FORMAT({{ date_column }}, '%Y-%m-%d')
{% endmacro %}
```

```sql
-- モデルでの使用
SELECT
    order_id,
    {{ format_date('order_date') }} as formatted_date
FROM {{ ref('stg_orders') }}
```

### 引数付きマクロ

```sql
-- macros/calculate_profit.sql
{% macro calculate_profit(revenue, cost) %}
    ({{ revenue }} - {{ cost }}) as profit,
    ({{ revenue }} - {{ cost }}) * 1.0 / NULLIF({{ revenue }}, 0) as profit_margin
{% endmacro %}
```

```sql
SELECT
    order_id,
    {{ calculate_profit('total_amount', 'total_cost') }}
FROM {{ ref('int_orders_with_details') }}
```

## 2-5. 実践的なマクロ例

### サロゲートキー生成

```sql
-- macros/generate_surrogate_key.sql
{% macro generate_surrogate_key(columns) %}
    {{ dbt_utils.generate_surrogate_key(columns) }}
{% endmacro %}
```

```sql
SELECT
    {{ generate_surrogate_key(['customer_id', 'order_date']) }} as customer_order_key,
    customer_id,
    order_date
FROM {{ ref('fct_orders') }}
```

### 日付範囲フィルタ

```sql
-- macros/date_range_filter.sql
{% macro date_range_filter(date_column, start_var='start_date', end_var='end_date') %}
    {% if var(start_var, none) %}
        AND {{ date_column }} >= '{{ var(start_var) }}'
    {% endif %}
    {% if var(end_var, none) %}
        AND {{ date_column }} <= '{{ var(end_var) }}'
    {% endif %}
{% endmacro %}
```

```sql
SELECT *
FROM {{ ref('stg_orders') }}
WHERE 1=1
    {{ date_range_filter('order_date') }}
```

### 安全な結合

```sql
-- macros/safe_join.sql
{% macro safe_join(left_table, right_table, join_keys, join_type='left') %}
    {{ join_type | upper }} JOIN {{ right_table }}
    ON {% for key in join_keys %}
        {{ left_table }}.{{ key }} = {{ right_table }}.{{ key }}
        {{ "AND" if not loop.last }}
    {% endfor %}
{% endmacro %}
```

```sql
SELECT *
FROM orders o
{{ safe_join('o', ref('customers'), ['customer_id']) }}
```

## 2-6. 組み込み関数とオブジェクト

### ref()とsource()

```sql
-- モデル参照
{{ ref('stg_orders') }}
{{ ref('package_name', 'model_name') }}  -- パッケージ内のモデル

-- ソース参照
{{ source('raw', 'orders') }}
```

### this

```sql
-- 現在のモデルの参照
{{ this }}  -- プロジェクト名.スキーマ.モデル名
{{ this.schema }}  -- スキーマ名
{{ this.table }}  -- テーブル名
```

### config()

```sql
-- 設定値の取得
{% set mat = config.get('materialized') %}
{% if mat == 'incremental' %}
    -- インクリメンタル固有の処理
{% endif %}
```

### adapter

```sql
-- データベースタイプの確認
{% if adapter.type == 'bigquery' %}
    -- BigQuery固有の処理
{% elif adapter.type == 'duckdb' %}
    -- DuckDB固有の処理
{% endif %}
```

## 2-7. マクロのベストプラクティス

### ドキュメントの追加

```sql
-- macros/calculate_profit.sql
{% macro calculate_profit(revenue, cost, as_percentage=false) %}
{#
    売上と原価から利益を計算するマクロ

    引数:
        revenue: 売上カラム
        cost: 原価カラム
        as_percentage: 利益率として返すか（デフォルト: false）

    使用例:
        {{ calculate_profit('total_amount', 'total_cost') }}
        {{ calculate_profit('total_amount', 'total_cost', as_percentage=true) }}
#}
    {% if as_percentage %}
        ({{ revenue }} - {{ cost }}) * 1.0 / NULLIF({{ revenue }}, 0)
    {% else %}
        {{ revenue }} - {{ cost }}
    {% endif %}
{% endmacro %}
```

### 汎用性を持たせる

```sql
-- ❌ 硬い実装
{% macro get_current_date() %}
    CURRENT_DATE()
{% endmacro %}

-- ✅ 柔軟な実装
{% macro get_current_date(timezone='Asia/Tokyo') %}
    {% if adapter.type == 'bigquery' %}
        CURRENT_DATE('{{ timezone }}')
    {% elif adapter.type == 'duckdb' %}
        CURRENT_DATE
    {% else %}
        CURRENT_DATE
    {% endif %}
{% endmacro %}
```

### テスト可能にする

```sql
-- マクロ単体でテスト可能な設計
{% macro is_valid_email(email_column) %}
    {{ email_column }} LIKE '%@%.%'
{% endmacro %}
```

## 2-8. マクロのデバッグ

### log関数

```sql
{% macro debug_columns(model_name) %}
    {% set columns = adapter.get_columns_in_relation(ref(model_name)) %}
    {% for column in columns %}
        {{ log("Column: " ~ column.name ~ ", Type: " ~ column.data_type, info=true) }}
    {% endfor %}
{% endmacro %}
```

### compiled.sqlの確認

```bash
# コンパイル結果を確認
dbt compile --select my_model
cat target/compiled/sample_project/models/my_model.sql
```

### dbt debug

```bash
dbt debug
```

## 2-9. サンプルプロジェクトのマクロ

サンプルプロジェクトに便利なマクロを追加しましょう：

```sql
-- macros/generate_surrogate_key.sql
{% macro generate_surrogate_key(columns) %}
    {%- set column_list = [] -%}
    {%- for column in columns -%}
        {%- set _ = column_list.append("COALESCE(CAST(" ~ column ~ " AS VARCHAR), '')") -%}
    {%- endfor -%}
    MD5({{ column_list | join(" || '-' || ") }})
{% endmacro %}
```

```sql
-- macros/date_spine.sql
{% macro date_spine(datepart, start_date, end_date) %}
    {{ dbt_utils.date_spine(datepart, start_date, end_date) }}
{% endmacro %}
```

## 2-10. Jinjaのよくあるパターン

### NULL安全な比較

```sql
{% macro safe_equals(column, value) %}
    ({{ column }} = '{{ value }}' OR ({{ column }} IS NULL AND '{{ value }}' IS NULL))
{% endmacro %}
```

### 条件付きカラム

```sql
SELECT
    customer_id,
    {% if var('include_email', true) %}
        email,
    {% endif %}
    full_name
FROM {{ ref('stg_customers') }}
```

### バッチ処理

```sql
{% set batch_size = var('batch_size', 10000) %}
{% set max_id = dbt_utils.get_column_values(ref('stg_orders'), 'order_id', order_by='order_id desc', max_records=1)[0] %}

{% for batch in range(0, max_id, batch_size) %}
    INSERT INTO {{ this }} (...)
    SELECT ... WHERE order_id BETWEEN {{ batch }} AND {{ batch + batch_size - 1 }};
{% endfor %}
```

## まとめ

- JinjaでSQLに動的な要素を追加
- 変数は `var()` でアクセス
- 制御構造で条件分岐・ループ
- マクロで再利用可能なコードを作成
- `ref()`, `source()`, `this` でモデルを参照
- ドキュメントとテストを忘れずに

次の章では、パッケージの活用について学びます。
