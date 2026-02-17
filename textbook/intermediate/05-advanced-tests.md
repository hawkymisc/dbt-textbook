---
title: "5. 高度なテスト"
---

# 5. 高度なテスト

この章では、カスタムテストと高度なテスト戦略について学びます。

## 5-1. カスタムテストの基礎

組み込みテストでは不十分な場合、独自のテストを作成できます。

### テストの仕組み

dbtのテストは、失敗したレコードを返すSQLクエリです：
- 0件返せば → テスト合格
- 1件以上返せば → テスト失敗

### テストファイルの配置

```
tests/
├── assert_positive_amount.sql
├── assert_valid_dates.sql
└── assert_consistent_totals.sql
```

## 5-2. カスタムテストの作成

### シンプルなカスタムテスト

```sql
-- tests/assert_positive_amount.sql

-- total_amountが負の値でないことを確認
SELECT
    order_id,
    total_amount
FROM {{ ref('fct_orders') }}
WHERE total_amount < 0
```

### テストの使用

```bash
dbt test --select assert_positive_amount
```

### パラメータ化されたテスト

```yaml
# models/marts/schema.yml
tests:
  - name: assert_positive_amount
    description: "金額が正の値であることを確認"
```

## 5-3. 汎用的なカスタムテスト（マクロ）

### マクロとしてのテスト

```sql
-- macros/test_is_positive.sql

{% test is_positive(model, column_name) %}

SELECT *
FROM {{ model }}
WHERE {{ column_name }} < 0

{% endtest %}
```

### 使用方法

```yaml
# models/marts/schema.yml
columns:
  - name: total_amount
    tests:
      - is_positive

  - name: profit_margin
    tests:
      - is_positive
```

### 複数引数のテスト

```sql
-- macros/test_within_range.sql

{% test within_range(model, column_name, min_value=0, max_value=1) %}

SELECT *
FROM {{ model }}
WHERE {{ column_name }} < {{ min_value }}
   OR {{ column_name }} > {{ max_value }}

{% endtest %}
```

```yaml
columns:
  - name: profit_margin
    tests:
      - within_range:
          min_value: 0
          max_value: 1

  - name: discount_rate
    tests:
      - within_range:
          min_value: 0
          max_value: 0.5
```

## 5-4. dbt_utilsのテスト活用

### expression_is_true

```yaml
- name: total_amount
  tests:
    - dbt_utils.expression_is_true:
        expression: ">= 0"
```

### unique_combination_of_columns

```yaml
tests:
  - dbt_utils.unique_combination_of_columns:
      combination_of_columns:
        - customer_id
        - order_date
```

### equality

```yaml
tests:
  - dbt_utils.equality:
      compare_model: ref('expected_output')
      compare_columns:
        - order_id
        - total_amount
```

### recency

```yaml
tests:
  - dbt_utils.recency:
      datepart: day
      field: order_date
      interval: 1
```

### at_least_one

```yaml
tests:
  - dbt_utils.at_least_one:
      group_by_columns:
        - order_date
```

## 5-5. dbt_expectationsの活用

### 数値の期待値

```yaml
- name: total_amount
  tests:
    - dbt_expectations.expect_column_values_to_be_between:
        min_value: 0
        max_value: 10000000
        row_condition: "order_status = 'completed'"

    - dbt_expectations.expect_column_values_to_be_in_type_list:
        column_type_list: [INTEGER, NUMERIC, FLOAT]
```

### 文字列の期待値

```yaml
- name: email
  tests:
    - dbt_expectations.expect_column_values_to_match_regex:
        regex: "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"

    - dbt_expectations.expect_column_values_to_not_match_regex:
        regex: "test|sample|dummy"
```

### 分布の期待値

```yaml
tests:
  - dbt_expectations.expect_table_row_count_to_be_between:
      min_value: 100
      max_value: 100000

  - dbt_expectations.expect_table_row_count_to_equal_other_table:
      other_table_name: "{{ ref('source_orders') }}"
```

### ユニークネス

```yaml
- name: customer_id
  tests:
    - dbt_expectations.expect_column_values_to_be_unique:
        ignore_row_if: "this_value.is_null"
```

## 5-6. 複雑なテストシナリオ

### 参照整合性の高度なチェック

```sql
-- tests/assert_valid_customer_orders.sql

-- すべての注文が有効な顧客に紐づいていることを確認
SELECT
    o.order_id,
    o.customer_id
FROM {{ ref('fct_orders') }} o
LEFT JOIN {{ ref('dim_customers') }} c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL
```

### 集計値の整合性チェック

```sql
-- tests/assert_order_totals_match.sql

-- 注文ヘッダの合計と明細の合計が一致することを確認
SELECT
    h.order_id,
    h.total_amount as header_total,
    d.detail_total,
    ABS(h.total_amount - d.detail_total) as difference
FROM {{ ref('fct_orders') }} h
JOIN (
    SELECT
        order_id,
        SUM(line_total) as detail_total
    FROM {{ ref('int_order_items_with_product') }}
    GROUP BY order_id
) d ON h.order_id = d.order_id
WHERE ABS(h.total_amount - d.detail_total) > 0.01
```

### 時系列の連続性チェック

```sql
-- tests/assert_no_date_gaps.sql

-- 日次売上に日付のギャップがないことを確認
WITH expected_dates AS (
    SELECT date_day
    FROM {{ ref('date_spine') }}
    WHERE date_day BETWEEN '2024-01-01' AND CURRENT_DATE()
),
actual_dates AS (
    SELECT DISTINCT order_date
    FROM {{ ref('fct_daily_sales') }}
)
SELECT
    e.date_day as missing_date
FROM expected_dates e
LEFT JOIN actual_dates a ON e.date_day = a.order_date
WHERE a.order_date IS NULL
```

## 5-7. テスト戦略

### レイヤー別のテスト

| レイヤー | テストの種類 |
|---------|-------------|
| Staging | 主キー、NULL、データ型 |
| Intermediate | 参照整合性、計算ロジック |
| Marts | ビジネスルール、集計整合性 |

### テストの優先度

```yaml
# クリティカルなテスト
- name: order_id
  tests:
    - unique:
        config:
          severity: error
          error_if: ">1000"
          warn_if: ">0"

# 重要だが即時対応不要
- name: middle_name
  tests:
    - not_null:
        config:
          severity: warn

# 参考情報
- name: notes
  tests:
    - dbt_utils.expression_is_true:
        expression: "length(notes) <= 1000"
        config:
          severity: warn
```

### テストのタグ付け

```yaml
# models/marts/schema.yml
models:
  - name: fct_orders
    columns:
      - name: order_id
        tests:
          - unique:
              config:
                tags: ['daily', 'critical']

      - name: customer_segment
        tests:
          - accepted_values:
              values: ['VIP', 'Regular', 'New', 'No Purchase']
              config:
                tags: ['weekly']
```

## 5-8. テストの失敗を調査

### 失敗レコードの保存

```yaml
- name: order_id
  tests:
    - unique:
        store_failures: true
        config:
          schema: dbt_test__audit
```

### 失敗レコードの確認

```sql
-- 失敗したレコードを確認
SELECT *
FROM dbt_test__audit.unique_fct_orders_order_id
LIMIT 100
```

## 5-9. サンプルプロジェクトへの適用

```yaml
# models/marts/schema.yml（拡張版）
models:
  - name: fct_orders
    tests:
      # テーブルレベルのテスト
      - dbt_utils.expression_is_true:
          expression: "total_amount >= 0"
          config:
            severity: error

    columns:
      - name: order_id
        tests:
          - unique
          - not_null

      - name: total_amount
        tests:
          - not_null
          - dbt_expectations.expect_column_values_to_be_between:
              min_value: 0
              max_value: 10000000

      - name: profit_margin
        tests:
          - dbt_utils.expression_is_true:
              expression: "profit_margin >= 0 AND profit_margin <= 1"
              config:
                severity: warn

      - name: order_date
        tests:
          - dbt_expectations.expect_column_values_to_be_between:
              min_value: "'2020-01-01'"
              max_value: "CURRENT_DATE()"
```

## 5-10. テストのベストプラクティス

### チェックリスト

- [ ] すべての主キーに `unique` と `not_null`
- [ ] すべての外部キーに `relationships`
- [ ] ステータス項目に `accepted_values`
- [ ] 数値の範囲チェック
- [ ] 日付の妥当性チェック
- [ ] ビジネスルールのテスト
- [ ] 集計の整合性チェック

### テストカバレッジの目標

```
テスト数 / モデル数 >= 2
```

## まとめ

- カスタムテストは失敗レコードを返すSQL
- マクロで汎用的なテストを作成
- dbt_utils、dbt_expectationsを活用
- テストにタグとseverityを設定
- 失敗レコードを保存して調査

次の章では、Snapshotsについて学びます。
