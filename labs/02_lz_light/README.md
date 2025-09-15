# Lab: 最小ランディングゾーン（Light）

このラボでは、サンドボックス環境で安全にハンズオンを進めるための、最小限のガードレールを CLI で構築します。具体的には、ログ集約基盤と、リソースへのタグ付けを強制するポリシーを設定します。

## 1. ゴール

- すべてのアクティビティログと診断ログを集約するための **Log Analytics Workspace** が存在する。
- サブスクリプション内のすべてのリソースに `owner` タグを必須にする **Azure Policy** が適用されている。

## 2. 前提

- 第1章「準備」が完了していること。
- サブスクリプションレベルでポリシーを割り当てる権限（例: `Resource Policy Contributor`）があること。

## 3. 変数定義

```bash
# 第1章で作成した共通リソースグループ名
export RG_COMMON="rg-hdbk-common"
export LOCATION="japaneast"
export PREFIX="hdbk"

# Log Analytics Workspace 名
export LAW_NAME="law-${PREFIX}"

# Policy 名
export POLICY_ASSIGNMENT_NAME="require-owner-tag"
```

## 4. 手順

### 4.1. Log Analytics Workspace の作成

各種ログの集約先となる Log Analytics Workspace を作成します。

```bash
az monitor log-analytics workspace create \
  --resource-group $RG_COMMON \
  --workspace-name $LAW_NAME \
  --location $LOCATION
```

後続の章でリソースの診断設定を行う際に必要となるため、作成したワークスペースの **Resource ID** を取得して変数に格納しておきます。

```bash
export LAW_ID=$(az monitor log-analytics workspace show --resource-group $RG_COMMON --workspace-name $LAW_NAME --query id -o tsv)
echo "Log Analytics Workspace ID: $LAW_ID"
```

### 4.2. "タグ必須" ポリシーの割り当て

リソース管理の基本として、`owner` タグの付与を強制するポリシーをサブスクリプション全体に適用します。

まず、組み込みポリシーの中から「Require a tag on resources」の定義 ID を検索します。

```bash
az policy definition list --query "[?displayName=='Require a tag on resources'].id" -o tsv
```

次に、取得したポリシー定義 ID を使って、サブスクリプションにポリシーを割り当てます。

```bash
# 組み込みポリシーの定義ID
export POLICY_DEF_ID=$(az policy definition list --query "[?displayName=='Require a tag on resources'].id" -o tsv)

# 現在のサブスクリプションID
export SUB_ID=$(az account show --query id -o tsv)

# ポリシーの割り当て
az policy assignment create \
  --name $POLICY_ASSIGNMENT_NAME \
  --display-name "Require 'owner' tag on all resources" \
  --policy $POLICY_DEF_ID \
  --scope "/subscriptions/$SUB_ID" \
  --params '{ "tagName": { "value": "owner" } }'
```

`--scope` にサブスクリプションの ID を指定することで、このサブスクリプション配下に作成されるすべてのリソースがポリシーの対象となります。

## 5. 検証

### 5.1. ポリシー割り当ての確認

サブスクリプションにポリシーが割り当てられたことを確認します。

```bash
az policy assignment list --query "[?name=='$POLICY_ASSIGNMENT_NAME'].{Name:displayName, Scope:scope}" -o table
```

**成功判定**:
`require-owner-tag` の割り当てが表示され、`Scope` が `/subscriptions/...` となっていれば成功です。

### 5.2. ポリシー効果の確認

実際に `owner` タグなしでリソースを作成しようとして、失敗することを確認します。

```bash
# owner タグなしでリソースグループを作成しようとすると...
az group create --name rg-test-policy --location $LOCATION
```

**成功判定**:
`RequestDisallowedByPolicy` というエラーメッセージが表示され、リソースの作成がブロックされれば成功です。エラーメッセージには、どのポリシーによって拒否されたかが示されます。

## 6. 後片付け

この章で作成したリソースを削除します。

```bash
# ポリシー割り当ての削除
az policy assignment delete --name $POLICY_ASSIGNMENT_NAME --scope "/subscriptions/$SUB_ID"

# Log Analytics Workspace は共通リソースグループ内にあるため、
# 最終章でリソースグループごと削除します。
echo "Policy assignment '$POLICY_ASSIGNMENT_NAME' has been deleted."
```

