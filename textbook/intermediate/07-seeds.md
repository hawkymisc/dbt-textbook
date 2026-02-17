---
title: "7. Seeds"
---

# 7. Seeds

この章では、dbt Seedsを使ってCSVファイルからデータをロードする方法を学びます。

## 7-1. Seedsとは

Seedsは、CSVファイルからデータウェアハウスにデータをロードする機能です。

### 使用場面

- マスタデータ（国コード、カテゴリ等）
- 設定データ
- テストデータ
- 参照用の小さなデータセット

### Seedsの特徴

| 特徴 | 説明 |
|-----|------|
| ソース管理 | Gitでバージョン管理可能 |
| バージョニング | コードレビュー可能 |
| 小規模データ | 大量データには不向き |
| 静的データ | 頻繁に変わるデータには不向き |

## 7-2. 基本的な使い方

### CSVファイルの作成

```csv
-- seeds/categories.csv
category_id,category_name,category_name_ja,sort_order
1,electronics,電子機器,1
2,accessories,アクセサリー,2
3,furniture,家具,3
4,other,その他,99
```

### Seedの実行

```bash
dbt seed
```

### 生成されるテーブル

```
default_schema.categories
```

### モデルからの参照

```sql
SELECT
    p.product_id,
    p.product_name,
    c.category_name_ja
FROM {{ ref('stg_products') }} p
LEFT JOIN {{ ref('categories') }} c ON p.category = c.category_name
```

## 7-3. Seedsの設定

### dbt_project.ymlでの設定

```yaml
seeds:
  sample_ec_project:
    +schema: seed_data
    +quote_columns: true

    categories:
      +column_types:
        category_id: integer
        category_name: varchar(50)
        category_name_ja: varchar(100)
        sort_order: integer
```

### 設定オプション

| オプション | 説明 |
|-----------|------|
| `schema` | テーブルを作成するスキーマ |
| `quote_columns` | カラム名を引用符で囲む |
| `column_types` | カラムの型指定 |
| `enabled` | 有効/無効 |
| `tags` | タグ |

### 個別ファイルの設定

```yaml
seeds:
  sample_ec_project:
    my_seed:
      +column_types:
        id: bigint
        name: varchar(100)
        created_at: timestamp
```

## 7-4. 実践例

### カテゴリマスタ

```csv
-- seeds/categories.csv
category_id,category_name,category_name_ja,sort_order,is_active
1,electronics,電子機器,1,true
2,accessories,アクセサリー,2,true
3,furniture,家具,3,true
4,other,その他,99,true
```

### ステータスマスタ

```csv
-- seeds/order_statuses.csv
status_code,status_name,status_name_ja,is_final
pending,保留中,保留中,false
shipped,発送済み,発送済み,false
completed,完了,完了,true
cancelled,キャンセル,キャンセル,true
returned,返品,返品,true
```

### 国・地域マスタ

```csv
-- seeds/countries.csv
country_code,country_name,region
JP,日本,アジア
US,アメリカ,北米
GB,イギリス,ヨーロッパ
CN,中国,アジア
KR,韓国,アジア
```

## 7-5. Seedsのドキュメント

```yaml
# seeds/seeds.yml
version: 2

seeds:
  - name: categories
    description: "商品カテゴリマスタ"
    columns:
      - name: category_id
        description: "カテゴリID"
        tests:
          - unique
          - not_null
      - name: category_name
        description: "カテゴリ名（英語）"
      - name: category_name_ja
        description: "カテゴリ名（日本語）"
      - name: sort_order
        description: "表示順"

  - name: order_statuses
    description: "注文ステータスマスタ"
    columns:
      - name: status_code
        tests:
          - unique
          - not_null
```

## 7-6. Seedsのテスト

Seedsにもテストを設定できます：

```yaml
seeds:
  - name: categories
    columns:
      - name: category_id
        tests:
          - unique
          - not_null
      - name: category_name
        tests:
          - not_null
          - accepted_values:
              values: ['electronics', 'accessories', 'furniture', 'other']
```

## 7-7. 特定のSeedのみ実行

```bash
# 特定のSeedのみ
dbt seed --select categories

# 複数のSeed
dbt seed --select categories order_statuses

# 除外
dbt seed --exclude test_data
```

## 7-8. SeedsとSourcesの使い分け

| 場面 | Seeds | Sources |
|-----|-------|---------|
| データソース | CSVファイル | 外部システム |
| 更新頻度 | 低い | 高い |
| データ量 | 小さい | 大きくてもOK |
| バージョン管理 | Git | 外部 |

### Seedsを使うべき場合

- 数十〜数百行程度のマスタデータ
- 頻繁に変わらない
- Gitで管理したい

### Sourcesを使うべき場合

- 外部システムからロードされるデータ
- 大量のデータ
- 頻繁に更新される

## 7-9. サンプルプロジェクトへの適用

```csv
-- seeds/payment_methods.csv
payment_method_code,payment_method_name,payment_method_name_ja
credit_card,Credit Card,クレジットカード
bank_transfer,Bank Transfer,銀行振込
```

```sql
-- モデルでの使用
SELECT
    o.order_id,
    o.payment_method,
    pm.payment_method_name_ja
FROM {{ ref('stg_orders') }} o
LEFT JOIN {{ ref('payment_methods') }} pm
    ON o.payment_method = pm.payment_method_code
```

## 7-10. Seedsのベストプラクティス

### DO（推奨）

- ✅ 一貫したカラム名（snake_case）
- ✅ ヘッダー行を含める
- ✅ UTF-8エンコーディング

### DON'T（非推奨）

- ❌ 大量のデータ（10,000行以上）→ 代わりにソースを使用
- ❌ 頻繁に変わるデータ → 代わりに外部システムから
- ❌ 日本語カラム名 → 英語のカラム名を使用

### チェックリスト

- [ ] CSVファイルをUTF-8で保存
- [ ] 一貫したカラム名（snake_case）
- [ ] テストを設定
- [ ] ドキュメントを追加
- [ ] Gitでバージョン管理

## 7-11. トラブルシューティング

### 文字化け

```
問題: 日本語が文字化けする
原因: CSVのエンコーディング
解決: UTF-8で保存し直す
```

### 型変換エラー

```
問題: カラムの型が正しく推論されない
原因: CSVから型が判断できない
解決: dbt_project.ymlでcolumn_typesを指定
```

### ファイルが見つからない

```
問題: Seed file not found
原因: seed-pathsの設定ミス
解決: dbt_project.ymlのseed-pathsを確認
```

## まとめ

- SeedsでCSVファイルからデータをロード
- マスタデータや設定データに最適
- Gitでバージョン管理可能
- `dbt seed` で実行
- 大量データや頻繁に変わるデータには不向き
- `ref()` でモデルから参照

次の章では、Hooksについて学びます。
