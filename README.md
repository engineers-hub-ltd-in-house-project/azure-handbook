# （他クラウド経験者向け）Azure CLI 実践ハンドブック

[![Lint and Format Check](https://github.com/engineers-hub-ltd-in-house-project/azure-handbook/actions/workflows/deploy.yml/badge.svg)](https://github.com/engineers-hub-ltd-in-house-project/azure-handbook/actions/workflows/deploy.yml)

本書は、AWS（Amazon Web Services）や GCP（Google Cloud Platform）など、他のパブリッククラウドで豊富な経験を持つ中上級エンジニアが、Microsoft Azure の世界に迅速かつ効果的に適応するための実践的なハンドブックです。

クラウドの基本概念は既に理解していることを前提とし、Azure 特有の概念やリソース管理方法を、**CLI (`az` コマンド)** と **IaC (Bicep)** を中心に、対話形式で解説していきます。

**[完成したブックはこちらから閲覧できます（GitHub Pagesの設定後に有効になります）](https://engineers-hub-ltd-in-house-project.github.io/azure-handbook/)**

## 本書の哲学：CLI First, Portal Second

多くの入門書とは異なり、本書はあえて **「CLIファースト」** の原則を貫きます。すべての操作は、まず `az` コマンドで実行します。これにより、再現性、自動化、そして IaC へのスムーズなステップアップを可能にするスキルを最短距離で獲得することを目指します。

## 目次

- **第1章: 準備**: 用語整理、CLI環境、命名・タグ規約
- **第2章: 最小ランディングゾーン（Light）**: Log Analytics, Azure Policy
- **第3章: ネットワーク基盤**: VNet, NSG, Private Endpoint
- **第4章: ID/セキュリティ基盤**: RBAC, Key Vault
- **第5章: コンピュート & コンテナ**: Azure Container Apps
- **第6章: データサービス**: PostgreSQL Flexible Server (VNet統合)
- **第7章: 監視・ログ・アラート**: 診断設定, KQL, アラート
- **第8章: IaC & CI/CD**: Bicep, GitHub Actions, OIDC
- **第9章: 運用（Day2）Runbook**: スケール、リストア、コスト管理
- **第10章: トラブルシュート**: 典型的な問題と診断パターン
- **付録**: クロスクラウド対比表、命名規約、セキュリティチェックリストなど

## 開発

本プロジェクトでは、`lefthook` を利用して `git push` 時に自動で Markdown の lint と format チェックを実行します。

ローカルでプレビューするには `mdbook` が必要です。

```bash
# 依存関係のインストール
npm install

# mdBookのインストール (Rustが必要)
cargo install mdbook

# ローカルでプレビュー
mdbook serve --open
```
