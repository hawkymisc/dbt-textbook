# 目次

## 入門編

1. [dbtへの招待](introduction/01-invitation.md)
   - データパイプラインの課題
   - dbtが解決する問題
   - ELTアプローチの理解

2. [dbtの概要](introduction/02-overview.md)
   - dbt Core vs dbt Cloud
   - アーキテクチャと主要コンポーネント
   - 対応データウェアハウス

3. [環境構築](introduction/03-setup.md)
   - dbt Coreのインストール
   - BigQuery / DuckDB の設定
   - 接続テスト

4. [Hello dbt](introduction/04-hello-dbt.md)
   - 最初のモデルを作成
   - dbt run / dbt test の実行
   - 開発ワークフロー

---

## 初級編

1. [プロジェクト構造の理解](beginner/01-project-structure.md)
   - ディレクトリ構成
   - dbt_project.yml の設定
   - ソース（Sources）の定義

2. [モデルの作成](beginner/02-models.md)
   - モデルの基本構文
   - ref() / source() 関数
   - 選択実行（--select）

3. [マテリアライゼーション](beginner/03-materializations.md)
   - view / table / incremental / ephemeral
   - 適切な選択基準
   - BigQuery固有の設定

4. [レイヤー構造](beginner/04-layers.md)
   - Staging層
   - Intermediate層
   - Marts層
   - データリネージ（DAG）

5. [基本的なテスト](beginner/05-tests.md)
   - unique / not_null
   - accepted_values / relationships
   - テストの実行と管理

---

## 中級編

1. [高度なマテリアライゼーション](intermediate/01-advanced-materializations.md)
   - インクリメンタルの詳細
   - unique_key / is_incremental()
   - スキーマ変更の対応

2. [Jinjaとマクロ](intermediate/02-jinja-macros.md)
   - Jinjaテンプレーティング基礎
   - マクロの作成と使用
   - 組み込み関数

3. [パッケージの活用](intermediate/03-packages.md)
   - dbt Hubからパッケージをインストール
   - dbt_utils / dbt_expectations
   - パッケージのバージョン管理

4. [ドキュメントとリネージ](intermediate/04-documentation-lineage.md)
   - 自動ドキュメント生成
   - データリネージの可視化
   - メタデータの活用

5. [高度なテスト](intermediate/05-advanced-tests.md)
   - カスタムテストの作成
   - テスト戦略
   - 失敗レコードの調査

6. [Snapshots](intermediate/06-snapshots.md)
   - データの履歴管理
   - SCD Type 2
   - timestamp / check 戦略

7. [Seeds](intermediate/07-seeds.md)
   - CSVファイルからのデータロード
   - 静的データの管理
   - SeedsとSourcesの使い分け

8. [Hooks](intermediate/08-hooks.md)
   - pre-hook / post-hook
   - on-run-start / on-run-end
   - 権限付与などの自動化

9. [CI/CDとデプロイ](intermediate/09-cicd-deployment.md)
   - GitHub ActionsでのCI/CD
   - dbt Cloudでのデプロイ
   - 環境戦略

---

## 付録

- [用語集](appendix/glossary.md)
- [コマンドリファレンス](appendix/commands.md)
- [チートシート](appendix/cheatsheet.md)
- [トラブルシューティング](appendix/troubleshooting.md)
