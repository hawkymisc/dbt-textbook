---
title: "5. 基本的なテスト"
---

# 5. 基本的なテスト

この章では、dbtのテスト機能について学びます。テストを使うことで、データ品質を自動的に検証できます。

## 5-1. なぜテストが必要か

### データ品質の問題

データパイプラインでよく発生する問題：

- 重複データ（主キーが重複している）
- 欠損値（必須項目がNULL）
- 参照整合性エラー（存在しないIDを参照）
- 不正な値（負の売上、未来の日付など）

### テストのメリット

```bash
dbt run && dbt test
```

- **早期発見**: データ問題を本番環境に届く前に発見
- **自動化**: コードレビューで見落としがちな問題を検出
- **ドキュメント**: テスト自体が仕様の一部
- **信頼性**: テストが通ればデータは正しい

## 5-2. テストの種類

### 組み込みテスト

dbtには4つの組み込みテストがあります：

| テスト名 | 説明 | 使用場面 |
|---------|------|---------|
| `unique` | 値が一意である | 主キー |
| `not_null` | NULLでない | 必須項目 |
| `accepted_values` | 指定値のいずれか | ステータス等 |
| `relationships` | 他テーブルに存在する | 外部キー |

### カスタムテスト

独自のSQLでテストロジックを定義することも可能です（中級編で解説）。

## 5-3. テストの定義方法

### YAMLでの定義

```yaml
# models/marts/schema.yml
version: 2

models:
  - name: fct_orders
    description: "注文ファクトテーブル"
    columns:
      - name: order_id
        description: "注文ID（主キー）"
        tests:
          - unique
          - not_null

      - name: customer_id
        description: "顧客ID"
        tests:
          - not_null
          - relationships:
              to: ref('dim_customers')
              field: customer_id

      - name: order_status
        description: "注文ステータス"
        tests:
          - accepted_values:
              values: ['pending', 'shipped', 'completed', 'cancelled', 'returned']
```

### ソースへのテスト

```yaml
# models/staging/sources.yml
version: 2

sources:
  - name: raw
    tables:
      - name: customers
        columns:
          - name: customer_id
            tests:
              - unique
              - not_null
          - name: email
            tests:
              - unique
```

## 5-4. 各テストの詳細

### unique（一意性）

```yaml
- name: order_id
  tests:
    - unique
```

**検証内容**: このカラムに重複する値がないことを確認

**実行されるSQL**:
```sql
SELECT count(*) FROM (
    SELECT order_id, count(*) FROM fct_orders
    GROUP BY order_id HAVING count(*) > 1
)
```

### not_null（非NULL）

```yaml
- name: customer_id
  tests:
    - not_null
```

**検証内容**: このカラムにNULL値がないことを確認

**実行されるSQL**:
```sql
SELECT count(*) FROM fct_orders WHERE customer_id IS NULL
```

### accepted_values（許容値）

```yaml
- name: order_status
  tests:
    - accepted_values:
        values: ['pending', 'shipped', 'completed', 'cancelled', 'returned']
```

**検証内容**: カラム値が指定されたリストに含まれることを確認

**オプション**:
```yaml
- accepted_values:
    values: ['active', 'inactive']
    quote: true  # 文字列を引用符で囲む（デフォルト: true）
```

### relationships（参照整合性）

```yaml
- name: customer_id
  tests:
    - relationships:
        to: ref('dim_customers')
        field: customer_id
```

**検証内容**: 値が参照先テーブルに存在することを確認（外部キー制約相当）

**複合キーの例**:
```yaml
tests:
  - relationships:
      to: ref('dim_products')
      field: product_id
      config:
        where: "1=1"  # 条件付きテスト
```

**実行されるSQL**:
```sql
SELECT count(*) FROM fct_orders a
LEFT JOIN dim_customers b ON a.customer_id = b.customer_id
WHERE a.customer_id IS NOT NULL AND b.customer_id IS NULL
```

## 5-5. テストの実行

### 基本的な実行

```bash
# 全テストを実行
dbt test

# モデル実行後にテスト
dbt run && dbt test
```

### 特定のテストのみ実行

```bash
# 特定モデルのテスト
dbt test --select fct_orders

# 特定のテストタイプ
dbt test --select test_type:unique

# タグで選択
dbt test --select tag:critical
```

### 実行結果

成功時:
```
Running with dbt=1.8.0
Found 2 models, 5 tests

14:30:00  1 of 5 START test unique_fct_orders_order_id ................ [RUN]
14:30:01  1 of 5 PASS unique_fct_orders_order_id ...................... [PASS in 1.23s]
...
Completed successfully
Done. PASS=5 WARN=0 ERROR=0 SKIP=0 TOTAL=5
```

失敗時:
```
14:30:01  1 of 5 FAIL 1 unique_fct_orders_order_id .................... [FAIL 1 in 1.23s]
...
Completed with 1 test failure:
failures in unique_fct_orders_order_id (models/marts/schema.yml)

Done. PASS=4 WARN=0 ERROR=1 SKIP=0 TOTAL=5
```

## 5-6. テストの深刻度（Severity）

テストの失敗時の挙動を設定できます：

```yaml
- name: order_id
  tests:
    - unique:
        severity: error  # エラー（デフォルト）
```

### severityの値

| 値 | 動作 |
|---|------|
| `error` | テスト失敗でエラー終了（デフォルト） |
| `warn` | 警告のみ表示、処理は継続 |

```yaml
- name: middle_name
  tests:
    - not_null:
        severity: warn  # NULLがあっても警告のみ
```

### プロジェクト全体の設定

```yaml
# dbt_project.yml
tests:
  sample_ec_project:
    +severity: error
    +store_failures: true  # 失敗レコードを保存
```

## 5-7. 失敗レコードの確認

`store_failures: true` を設定すると、失敗したレコードがテーブルに保存されます：

```yaml
- name: order_id
  tests:
    - unique:
        store_failures: true
```

```bash
# 失敗レコードの確認
dbt show --select dbt_test__audit --limit 10
```

## 5-8. テストタグ

テストにタグを付けて、実行を制御できます：

```yaml
- name: order_id
  tests:
    - unique:
        config:
          tags: ['critical', 'daily']

- name: order_status
  tests:
    - accepted_values:
        values: ['pending', 'shipped', 'completed']
        config:
          tags: ['daily']
```

```bash
# タグでフィルタリング
dbt test --select tag:daily
dbt test --select tag:critical
```

## 5-9. ソーステストとモデルテストの使い分け

### ソーステスト

```yaml
# models/staging/sources.yml
sources:
  - name: raw
    tables:
      - name: customers
        columns:
          - name: customer_id
            tests:
              - unique
              - not_null
```

**目的**: ソースデータの品質監視
**タイミング**: データロード直後

### モデルテスト

```yaml
# models/marts/schema.yml
models:
  - name: fct_orders
    columns:
      - name: order_id
        tests:
          - unique
          - not_null
```

**目的**: 変換後のデータ品質確認
**タイミング**: dbt run後

### 推奨パターン

- ソーステスト: 主キー、必須項目の基本チェック
- モデルテスト: ビジネスロジックに関わるチェック

## 5-10. 実践：サンプルプロジェクトのテスト

サンプルプロジェクトのテスト定義を確認しましょう：

```yaml
# models/staging/sources.yml（抜粋）
sources:
  - name: raw
    tables:
      - name: customers
        columns:
          - name: customer_id
            tests:
              - unique
              - not_null
          - name: email
            tests:
              - unique

      - name: orders
        columns:
          - name: order_id
            tests:
              - unique
              - not_null
          - name: customer_id
            tests:
              - not_null
              - relationships:
                  to: source('raw', 'customers')
                  field: customer_id
          - name: order_status
            tests:
              - accepted_values:
                  values: ['pending', 'shipped', 'completed', 'cancelled', 'returned']
```

```yaml
# models/marts/schema.yml（抜粋）
models:
  - name: dim_customers
    columns:
      - name: customer_id
        tests:
          - unique
          - not_null
      - name: customer_segment
        tests:
          - accepted_values:
              values: ['VIP', 'Regular', 'New', 'No Purchase']
```

### テストの実行

```bash
# サンプルプロジェクトでテスト実行
cd sample-project
dbt test
```

## 5-11. テスト戦略のベストプラクティス

### 最低限のテスト

すべてのモデルに以下のテストを設定：

1. 主キー: `unique`, `not_null`
2. 外部キー: `relationships`
3. ステータス項目: `accepted_values`

### テストカバレッジ

```bash
# テスト数とモデル数を確認
dbt ls --resource-type test | wc -l
dbt ls --resource-type model | wc -l
```

目安: モデル数の2〜3倍以上のテスト

### テストの実行タイミング

| タイミング | 実行するテスト |
|-----------|--------------|
| 開発中 | 全テスト |
| CI/CD | 全テスト |
| 定期実行 | criticalタグ |

## 5-12. よくあるテストパターン

### dbt_utilsパッケージの活用

以下のテストを使用するには、`dbt_utils` パッケージのインストールが必要です：

```yaml
# packages.yml
packages:
  - package: dbt-labs/dbt_utils
    version: [">=1.0.0", "<2.0.0"]
```

```bash
dbt deps  # パッケージをインストール
```

:::message
パッケージの詳細は中級編第3章「パッケージの活用」で解説します。
:::

#### 日付の妥当性

```yaml
- name: order_date
  tests:
    - dbt_utils.expression_is_true:
        expression: "<= current_date()"
```

#### 正の値

```yaml
- name: total_amount
  tests:
    - dbt_utils.expression_is_true:
        expression: ">= 0"
```

#### 一致確認

```yaml
tests:
  - dbt_utils.equality:
      compare_model: ref('expected_results')
```

## まとめ

- 組み込みテスト: unique, not_null, accepted_values, relationships
- YAMLでテストを定義
- `dbt test` でテストを実行
- severityでエラー/警告を制御
- タグでテスト実行を制御
- 最低限、主キーと外部キーにはテストを設定

初級編はこれで終了です。おめでとうございます！

次は中級編で、より高度な機能を学びます。
