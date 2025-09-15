# 付録D: 電子書籍ビルドパイプライン

本書のようにMarkdownで執筆されたコンテンツは、CI/CDパイプラインを使って自動的にHTMLサイトやPDF、EPUBといった電子書籍フォーマットに変換することができます。これにより、常に最新の原稿が整形されたフォーマットで閲覧可能になります。

この付録では、Rust製の静的サイトジェネレーターである **`mdBook`** とGitHub Actionsを使って、HTML版の書籍を自動ビルドし、GitHub Pagesで公開するパイプラインの例を紹介します。

## 1. `mdBook` のセットアップ

本書のリポジトリは、既に `mdBook` で利用可能な構成になっています。

-   **`book.toml`**: `mdBook` の設定ファイル。書籍のタイトル、著者、ソースディレクトリなどを定義します。
-   **`docs/`**: `mdBook` が参照する原稿のソースディレクトリです。
-   **`docs/SUMMARY.md`**: 書籍の目次を定義するファイルです。

ローカルでビルドを試すには、`mdBook` をインストールした後、リポジトリのルートで以下のコマンドを実行します。

```bash
# mdBookのインストール (Rustのcargoを利用)
cargo install mdbook

# ローカルでビルドしてプレビュー
mdbook serve --open
```

これにより、`http://localhost:3000` でビルドされた書籍をブラウザで確認できます。

## 2. GitHub Actions ワークフローの作成

`main` ブランチにプッシュされるたびに `mdBook` を実行し、生成されたHTMLをGitHub Pagesとして公開するワークフローを作成します。

以下の内容で、`.github/workflows/build-and-deploy-book.yml` というファイルを作成します。

```yaml
name: Build and Deploy mdBook

on:
  push:
    branches:
      - main

jobs:
  build_and_deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install mdBook
        run: |
          mkdir mdbook
          curl -sSL https://github.com/rust-lang/mdBook/releases/download/v0.4.21/mdbook-v0.4.21-x86_64-unknown-linux-gnu.tar.gz | tar -xz --directory=./mdbook
          echo "$PWD/mdbook" >> $GITHUB_PATH

      - name: Build the book
        run: mdbook build

      - name: Setup Pages
        uses: actions/configure-pages@v4

      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: ./book

      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

## 3. GitHub Pages の設定

このワークフローを有効にするには、GitHubリポジトリ側で一度だけ設定が必要です。

1.  リポジトリの **Settings > Pages** を開きます。
2.  **Build and deployment** の **Source** で、`GitHub Actions` を選択します。

## 4. パイプラインの動作

上記の設定が完了した後、`main` ブランチに何か変更をプッシュすると、`Build and Deploy mdBook` ワークフローが自動的に実行されます。

1.  `mdBook` がインストールされます。
2.  `mdbook build` が実行され、`book/` ディレクトリにHTMLファイル群が生成されます。
3.  `upload-pages-artifact` アクションが `book/` ディレクトリをアーティファクトとしてアップロードします。
4.  `deploy-pages` アクションが、そのアーティファクトをGitHub Pagesとしてデプロイします。

これにより、`https://<YOUR_GITHUB_USER>.github.io/azure-handbook/` のようなURLで、常に最新版のハンドブックが公開されるようになります。
