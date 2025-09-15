# 第1章: 準備

この章では、本書のハンズオンを進めるための準備作業を行います。Azure との対話の基本となる用語の整理、CLI 環境のセットアップ、そして今後のリソース管理の基準となる命名・タグ規約について定義します。

## 1. 用語整理

まず、AWS/GCP 経験者が混同しやすい Azure の基本用語を確認します。

| Azure                               | AWS                               | GCP                        | 説明                                                                                             |
| ----------------------------------- | --------------------------------- | -------------------------- | ------------------------------------------------------------------------------------------------ |
| **Microsoft Entra ID** (旧 Azure AD) | IAM (Identity Center)             | Cloud Identity / IAM       | テナント全体の ID とアクセス管理の基盤。ユーザ、グループ、サービスプリンシパルを管理。         |
| **管理グループ** (Management Group)   | AWS Organizations (OUs)           | Resource Hierarchy (Folders) | 複数のサブスクリプションを束ねてポリシーや RBAC を一括適用するための階層構造。             |
| **サブスクリプション** (Subscription) | AWS Account                       | Project                    | 課金と管理の単位。リソースをデプロイする境界。                                             |
| **リソースグループ** (Resource Group) | (リソース単位 or CloudFormation Stack) | (リソース単位)             | リソースのライフサイクルを管理するコンテナ。**Azure の最も基本的な管理単位**。             |
| **リージョン** (Region)               | Region                            | Region                     | データセンターの物理的な場所。`japaneast` (東日本), `westus3` (米国西部3) など。 |

## 2. CLI 環境のセットアップ

ローカルマシンまたは Azure Cloud Shell で作業します。以下のツールがインストールされ、パスが通っていることを確認してください。

- [Azure CLI](https://learn.microsoft.com/ja-jp/cli/azure/install-azure-cli)
- [Bicep](https://learn.microsoft.com/ja-jp/azure/bicep/install) (Azure CLI に統合)
- [Terraform](https://developer.hashicorp.com/terraform/install) (任意)

### 2.1. バージョン確認

```bash
# 各ツールのバージョンを確認
az version
az bicep version
terraform -version
```

### 2.2. Azure へのログインとサブスクリプション設定

ハンズオンで使用する Azure アカウントにログインします。

```bash
# ブラウザが開き、認証を求められます
az login

# 利用可能なサブスクリプション一覧を確認
az account list -o table

# ハンズオンで使用するサブスクリプションを設定
az account set --subscription "<YOUR_SUBSCRIPTION_ID>"

# 設定されたか確認
az account show --query "{name:name, id:id, isDefault:isDefault}" -o table
```

### 2.3. 既定値の設定

コマンド入力の手間を省くため、既定のリソースグループ名やリージョンを設定できます。本書では、各章で変数を使い明示的に指定しますが、個人の開発環境では設定しておくと便利です。

```bash
# 既定のリージョンを東日本に設定
az config set defaults.location=japaneast
```

## 3. 命名・タグ規約

リソースの識別と管理を容易にするため、一貫した命名規則とタグ戦略を定めます。

- **命名規則**: `<sys>-<env>-<region>-<resourcetype>-<seq>`
  - 例: `hdbk-dev-jpe-rg-001` (handbook, development, Japan East, Resource Group, 001)
- **タグ**:
  - `env`: 環境 (e.g., `handbook`, `dev`, `stg`, `prod`)
  - `owner`: 作成者・責任者
  - `costCenter`: コストセンター
  - `createdDate`: 作成日 (e.g., `2025-09-15`)

## 4. ハンズオン: 共通リソースグループの作成

本書全体で利用する可能性のある、共通のリソースグループを作成してみましょう。

### 手順

```bash
# 1. 変数定義
export PREFIX="hdbk"
export RG_COMMON="rg-${PREFIX}-common"
export LOCATION="japaneast"
export OWNER_NAME="<YOUR_NAME>" # ご自身の名前に変更してください

# 2. リソースグループの作成
az group create \
  --name $RG_COMMON \
  --location $LOCATION \
  --tags env=handbook owner=$OWNER_NAME createdDate=$(date +%Y-%m-%d)
```

### 検証

作成したリソースグループの情報を JSON 形式で確認します。

```bash
az group show --name $RG_COMMON --query "{Name:name, Location:location, Tags:tags}" -o jsonc
```

**成功判定**:
`name` や `tags` が正しく表示されれば成功です。

### 後片付け

このリソースグループは後続の章でも利用する可能性があるため、ここでは削除しません。
最終章で全てのリソースをクリーンアップします。

```