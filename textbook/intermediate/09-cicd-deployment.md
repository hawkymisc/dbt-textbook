---
title: "9. CI/CDとデプロイ"
---

# 9. CI/CDとデプロイ

この章では、dbtプロジェクトのCI/CDパイプライン構築と本番デプロイについて学びます。

## 9-1. CI/CDの重要性

dbtプロジェクトもアプリケーションと同様にCI/CDが重要です：

- **品質保証**: 自動テストでデータ品質を担保
- **一貫性**: 同じプロセスでデプロイ
- **トレーサビリティ**: 変更履歴が追える
- **信頼性**: 人的ミスを削減

## 9-2. 環境戦略

### 推奨環境構成

```
Dev（開発環境）
    ↓ PR作成
CI（継続的インテグレーション）
    ↓ マージ
Staging（検証環境）
    ↓ 承認
Prod（本番環境）
```

### 環境ごとの目的

| 環境 | 目的 | 更新タイミング |
|-----|------|--------------|
| Dev | 開発・テスト | 手動 |
| Staging | 統合テスト | マージ時 |
| Prod | 本番運用 | 承認後 |

## 9-3. GitHub ActionsでのCI

### 基本的なCIパイプライン

```yaml
# .github/workflows/ci.yml
name: dbt CI

on:
  pull_request:
    branches: [main]

jobs:
  ci:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.10'

      - name: Install dbt
        run: |
          pip install dbt-bigquery
          dbt deps

      - name: Compile
        run: dbt compile

      - name: Test
        run: dbt test

      - name: Build (Staging)
        run: dbt build --target staging
        env:
          DBT_PROFILES_DIR: ./
          GCP_PROJECT: ${{ secrets.GCP_PROJECT_STAGING }}
```

### CIでチェックする内容

```yaml
jobs:
  ci:
    steps:
      # 1. コンパイル確認
      - name: Compile
        run: dbt compile

      # 2. リント（sqlfluff等）
      - name: Lint
        run: |
          pip install sqlfluff
          sqlfluff lint models/

      # 3. テスト
      - name: Test
        run: dbt test

      # 4. ドキュメント生成
      - name: Generate docs
        run: dbt docs generate
```

## 9-4. プルリクエスト時の自動チェック

### slim-ciパターン

変更されたモデルとその依存先のみをテスト。推奨は state-based selection：

```yaml
- name: Build changed models
  run: |
    # 前回の実行結果（artifacts）と比較して変更されたモデルのみ実行
    dbt build --select state:modified+ --target ci
```

:::message
**slim-ciの注意点**: ファイル差分抽出（`git diff`）は `.sql` ファイルしか検出できず、`.yml` ファイルや `macros/` の変更を見落とす可能性があります。公式の `state:modified+` セレクションの使用を推奨します。
:::

### ファイル差分での選択（参考）

```yaml
- name: Get changed models
  id: changed
  run: |
    # 変更されたファイルからモデル名を抽出（参考実装）
    CHANGED=$(git diff --name-only origin/main...HEAD | grep 'models/.*\.sql$' | sed 's/models\///g' | sed 's/\.sql//g' | tr '\n' ' ')
    echo "models=$CHANGED" >> $GITHUB_OUTPUT

- name: Test changed models
  run: |
    if [ -n "${{ steps.changed.outputs.models }}" ]; then
      dbt build --select ${{ steps.changed.outputs.models }}+ --target ci
    else
      echo "No model changes detected"
    fi
```

### PRコメントへの結果表示

```yaml
- name: Comment PR
  uses: actions/github-script@v7
  with:
    script: |
      github.rest.issues.createComment({
        issue_number: context.issue.number,
        owner: context.repo.owner,
        repo: context.repo.repo,
        body: `## dbt CI Results
        ✅ All tests passed
        - Models built: 5
        - Tests passed: 12`
      })
```

## 9-5. デプロイパイプライン

### 基本的なCDパイプライン

```yaml
# .github/workflows/deploy.yml
name: dbt Deploy

on:
  push:
    branches: [main]
  workflow_dispatch:  # 手動実行

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production  # 環境保護ルールを適用

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.10'

      - name: Install dbt
        run: |
          pip install dbt-bigquery
          dbt deps

      - name: Deploy to Production
        run: dbt run --target prod
        env:
          DBT_PROFILES_DIR: ./
          GCP_PROJECT: ${{ secrets.GCP_PROJECT_PROD }}

      - name: Run Tests
        run: dbt test --target prod
        env:
          DBT_PROFILES_DIR: ./
          GCP_PROJECT: ${{ secrets.GCP_PROJECT_PROD }}

      - name: Generate Docs
        run: dbt docs generate --target prod
        env:
          DBT_PROFILES_DIR: ./
          GCP_PROJECT: ${{ secrets.GCP_PROJECT_PROD }}
```

### スケジュール実行

```yaml
# .github/workflows/scheduled.yml
name: Scheduled dbt Run

on:
  schedule:
    - cron: '0 6 * * *'  # 毎日6時（UTC）

jobs:
  daily-run:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run dbt
        run: |
          pip install dbt-bigquery
          dbt deps
          dbt run --target prod
          dbt test --target prod
```

## 9-6. dbt CloudでのCI/CD

### dbt Cloudのメリット

- 組み込みのCI/CD
- スケジューリング
- Web UI
- 通知機能
- メタデータAPI

### CI/CD設定

1. **Continuous Integration Job**:
   - PR作成時に自動実行
   - `dbt build` を実行

2. **Deploy Job**:
   - マージ時に自動実行
   - 本番環境へデプロイ

### dbt Cloudの設定例

```yaml
# Production Job
commands:
  - dbt deps
  - dbt run --target prod
  - dbt test --target prod
  - dbt docs generate

triggers:
  schedule: "0 6 * * *"  # 毎日6時
  github_webhook: true    # マージ時自動実行
```

## 9-7. 環境ごとの設定管理

### profiles.ymlの環境分け

```yaml
# profiles.yml
sample_ec_project:
  target: "{{ env_var('DBT_TARGET', 'dev') }}"
  outputs:
    dev:
      type: bigquery
      method: oauth
      project: "{{ env_var('GCP_PROJECT_DEV') }}"
      dataset: dbt_dev
      threads: 4

    staging:
      type: bigquery
      method: service_account
      project: "{{ env_var('GCP_PROJECT_STAGING') }}"
      dataset: dbt_staging
      keyfile: /path/to/staging-keyfile.json
      threads: 4

    prod:
      type: bigquery
      method: service_account
      project: "{{ env_var('GCP_PROJECT_PROD') }}"
      dataset: dbt_prod
      keyfile: /path/to/prod-keyfile.json
      threads: 8
```

### GitHub Secrets

```
GCP_PROJECT_DEV=my-project-dev
GCP_PROJECT_STAGING=my-project-staging
GCP_PROJECT_PROD=my-project-prod
GCP_SA_KEY_STAGING=-----BEGIN PRIVATE KEY-----...
GCP_SA_KEY_PROD=-----BEGIN PRIVATE KEY-----...
```

## 9-8. デプロイ戦略

### Blue-Greenデプロイ

```yaml
# 2つの環境を用意して切り替え
- name: Deploy to Green
  run: dbt run --target prod_green

- name: Validate
  run: dbt test --target prod_green

- name: Switch traffic
  run: |
    # BIツールやアプリケーションの参照先をprod_greenに変更
    # 具体的な方法は環境に依存（ビューの再作成、DNS切り替え等）
    echo "Switch traffic from prod_blue to prod_green"
```

:::message
**Blue-Greenデプロイの注意**: BigQueryの `bq update --dataset` コマンドはデータセットの設定を変更するだけで、トラフィックの切り替えは自動的に行われません。BIツールやアプリケーションの参照先を明示的に変更する必要があります。
:::

### カナリアデプロイ

```yaml
# 一部のモデルのみ先行デプロイ
- name: Deploy critical models
  run: dbt run --select tag:critical --target prod

- name: Validate
  run: dbt test --select tag:critical --target prod

- name: Deploy remaining models
  run: dbt run --exclude tag:critical --target prod
```

## 9-9. ロールバック

### Git-basedロールバック

```bash
# 前のバージョンに戻す
git revert HEAD
git push

# または特定のコミットへ
git checkout <commit-hash>
dbt run --target prod
```

### モデルレベルのロールバック

```bash
# 特定のモデルのみ再実行
dbt run --select fct_orders --target prod --full-refresh
```

## 9-10. 通知とアラート

### Slack通知

```yaml
- name: Notify Success
  if: success()
  uses: slackapi/slack-github-action@v1
  with:
    payload: |
      {
        "text": "✅ dbt deploy succeeded",
        "blocks": [
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": "*dbt Deploy Succeeded*\nEnvironment: Production\nModels: 25 built"
            }
          }
        ]
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}

- name: Notify Failure
  if: failure()
  uses: slackapi/slack-github-action@v1
  with:
    payload: |
      {
        "text": "❌ dbt deploy failed",
        "blocks": [
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": "*dbt Deploy Failed*\nCheck: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"
            }
          }
        ]
      }
```

## 9-11. CI/CDのベストプラクティス

### チェックリスト

- [ ] PR時に自動テスト
- [ ] マージ時に自動デプロイ
- [ ] 環境ごとに適切な権限設定
- [ ] 失敗時の通知
- [ ] ロールバック手順の確立
- [ ] ドキュメントの自動更新

### セキュリティ

```yaml
# シークレットの適切な管理
env:
  GCP_SA_KEY: ${{ secrets.GCP_SA_KEY }}  # GitHub Secretsから

# 権限の最小化
- name: Deploy
  run: dbt run --target prod
  # 読み取り専用サービスアカウントは使用しない
```

## 9-12. サンプルプロジェクトのCI/CD

```yaml
# .github/workflows/dbt.yml
name: dbt Pipeline

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
  schedule:
    - cron: '0 6 * * *'

jobs:
  ci:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.10'
      - run: pip install dbt-duckdb
      - run: dbt deps
      - run: dbt compile
      - run: dbt test

  deploy:
    if: github.event_name == 'push'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.10'
      - run: pip install dbt-duckdb
      - run: dbt deps
      - run: dbt run
      - run: dbt test

  scheduled:
    if: github.event_name == 'schedule'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.10'
      - run: pip install dbt-duckdb
      - run: dbt deps
      - run: dbt run
      - run: dbt test
```

## まとめ

- CIでPR時の自動テスト
- CDでマージ時の自動デプロイ
- 環境ごとに適切に設定を分離
- 失敗時の通知とロールバック
- dbt Cloudを使うと設定が簡単
- スケジュール実行で定期更新

---

**中級編はこれで終了です！**

これでdbtの主要な機能を習得しました。実務での活用に向けて、以下の次のステップをお勧めします：

1. **実務プロジェクトへの適用**: 実際のデータで練習
2. **dbtコミュニティへの参加**: Slack, GitHub Discussions
3. **高度なトピック**: dbt Mesh, Semantic Layer

 Happy dbt-ing! 🚀
