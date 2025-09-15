# 第2章: 最小ランディングゾーン（Light）

Azure の世界へようこそ。第1章で準備運動は完了しました。この章からは、実際に Azure 上にリソースを構築していきます。

しかし、いきなり仮想マシンやデータベースを作成する前に、私たちはまず「安全に実験できる砂場」を用意する必要があります。これを Azure の世界では **「ランディングゾーン」** と呼びます。ランディングゾーンとは、セキュリティ、ガバナンス、ネットワークといった基本的な設定が予め施された、アプリケーションを「着陸（デプロイ）」させるための環境のことです。

この章で構築するのは、その最もシンプルな「Light版」です。目的は、今後のハンズオンを安全かつ管理された形で行うための、最低限のガードレールを設定すること。具体的には、以下の2つを CLI で構築します。

1.  **ログ集約基盤**: すべての操作ログやリソースの診断ログを一元的に収集・分析するための「Log Analytics ワークスペース」。これは、何か問題が起きたときの調査や、セキュリティ監視の基本となります。
2.  **ガバナンスの第一歩**: リソースの責任者を明確にするため、「`owner`タグが必須である」というルール（Azure Policy）をサブスクリプション全体に適用します。これにより、誰が作ったかわからない「野良リソース」が生まれるのを防ぎます。

この章を終えれば、あなたは単にリソースを作るだけでなく、ログとガバナンスを意識した、より実践的なクラウド管理の第一歩を踏み出すことができます。

---

## ハンズオン：ログ基盤とポリシーの設定

### 1. ゴール

- すべてのログの集約先となる **Log Analytics ワークスペース** が存在する。
- サブスクリプション内のすべてのリソースに `owner` タグを必須にする **Azure Policy** が適用され、機能していることを確認する。

### 2. 前提

- 第1章「準備」が完了していること。
- サブスクリプションレベルでポリシーを割り当てる権限（例: `Resource Policy Contributor` ロール）があること。

### 3. 手順1: 変数定義

まず、このハンズオンで利用する変数を定義します。第1章で作成した共通リソースグループ名を再利用します。

```bash
# 第1章で定義した変数を再利用
export PREFIX="hdbk"
export RG_COMMON="rg-${PREFIX}-common"
export LOCATION="japaneast"

# この章で作成するリソースの変数を定義
export LAW_NAME="law-${PREFIX}"
export POLICY_ASSIGNMENT_NAME="require-owner-tag"
```

### 4. 手順2: Log Analytics ワークスペースの作成

Azure Monitor の一部である Log Analytics は、Azure 内のあらゆる場所からログやメトリックを収集、分析、可視化するための中心的なサービスです。AWS の CloudWatch Logs や GCP の Cloud Logging に相当します。

そのデータの保管場所となるのが **Log Analytics ワークスペース** です。以下のコマンドで作成しましょう。

```bash
az monitor log-analytics workspace create \
  --resource-group $RG_COMMON \
  --workspace-name $LAW_NAME \
  --location $LOCATION
```

後続の章で、各リソースのログをこのワークスペースに送信する設定を行います。その際にワークスペースのIDが必要になるため、ここで取得して変数に格納しておきましょう。

```bash
export LAW_ID=$(az monitor log-analytics workspace show --resource-group $RG_COMMON --workspace-name $LAW_NAME --query id --output tsv)

echo "Log Analytics Workspace ID: $LAW_ID"
```

### 5. 手順3: Azure Policy によるタグ強制

次に、ガバナンスを効かせるための **Azure Policy** を設定します。Azure Policy は、リソースの構成ルールを定義し、それを強制するサービスです。AWS の SCP (Service Control Policies) や Config Rules に似た役割を果たします。

今回は、「リソースには `owner` タグが必須」というルールを適用します。Azure では、リソースグループとその他のリソースで別々のポリシー定義が必要なため、両方を設定します。

**ステップ 3-1: ポリシー定義の検索**

Azure には、一般的なユースケースに対応した数百の「組み込みポリシー」が用意されています。「タグを必須にする」という組み込みポリシーの「名前（GUID）」を検索して取得します。

リソースグループとその他のリソースでは別のポリシー定義が必要です：

```bash
# リソース用のポリシー定義名を取得
export POLICY_DEF_RESOURCES=$(az policy definition list --query "[?displayName=='Require a tag on resources'].name" --output tsv)

# リソースグループ用のポリシー定義名を取得
export POLICY_DEF_RG=$(az policy definition list --query "[?displayName=='Require a tag on resource groups'].name" --output tsv)

echo "Policy for Resources: $POLICY_DEF_RESOURCES"
echo "Policy for Resource Groups: $POLICY_DEF_RG"
```

**ステップ 3-2: ポリシーの割り当て**

ポリシー定義が見つかったら、それを特定の範囲（スコープ）に「割り当て（Assignment）」ます。今回は、サブスクリプション全体に適用してみましょう。これにより、このサブスクリプション内に作成されるすべてのリソースとリソースグループがルールの対象となります。

パラメータはJSONファイル経由で渡すことで、エスケープの問題を回避できます。

```bash
# 現在のサブスクリプションIDを取得
export SUB_ID=$(az account show --query id --output tsv)

# パラメータファイルを作成
cat > params.json << EOF
{
  "tagName": {
    "value": "owner"
  }
}
EOF

# リソース用のポリシーを割り当て
az policy assignment create \
  --name "${POLICY_ASSIGNMENT_NAME}-resources" \
  --display-name "Require 'owner' tag on all resources" \
  --policy $POLICY_DEF_RESOURCES \
  --scope "/subscriptions/$SUB_ID" \
  --params @params.json

# リソースグループ用のポリシーを割り当て
az policy assignment create \
  --name "${POLICY_ASSIGNMENT_NAME}-rg" \
  --display-name "Require 'owner' tag on resource groups" \
  --policy $POLICY_DEF_RG \
  --scope "/subscriptions/$SUB_ID" \
  --params @params.json

# パラメータファイルを削除
rm params.json
```

### 6. 検証：ガードレールは機能しているか？

設定したガードレールが正しく機能しているか、必ず確認しましょう。

**検証1: ポリシー割り当ての確認**

まず、意図した通りにポリシーがサブスクリプションに割り当てられているかを確認します。

```bash
az policy assignment list --query "[?contains(name, '$POLICY_ASSIGNMENT_NAME')].{Name:displayName, Scope:scope}" --output table
```

**【成功の確認】**
以下のように、両方のポリシーが表示され、`Scope` にサブスクリプションのパスが表示されれば成功です。

```
Name                                    Scope
--------------------------------------  ---------------------------------------------------
Require 'owner' tag on all resources   /subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Require 'owner' tag on resource groups /subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

**検証2: ポリシー効果の確認（重要）**

次に、このポリシーが実際にリソース作成をブロックするかを試します。**`owner` タグを付けずに** 新しいリソースグループを作成してみましょう。

```bash
# わざと owner タグを付けずに作成を試みる
az group create --name rg-test-policy --location $LOCATION
```

**【成功の確認】**
コマンドが失敗し、`RequestDisallowedByPolicy` というエラーメッセージが表示されれば、ポリシーが正しく機能している証拠です。エラーメッセージには、どのポリシーによって拒否されたかが明記されており、トラブルシューティングに役立ちます。

（補足: ポリシーが有効になるまで数分かかる場合があります。すぐにエラーにならない場合は、少し待ってから再試行してください。）

### 7. 後片付け

検証が終わったので、作成したポリシー割り当てを削除して、サブスクリプションを元の状態に戻します。

```bash
# 両方のポリシー割り当てを削除
az policy assignment delete --name "${POLICY_ASSIGNMENT_NAME}-resources" --scope "/subscriptions/$SUB_ID"
az policy assignment delete --name "${POLICY_ASSIGNMENT_NAME}-rg" --scope "/subscriptions/$SUB_ID"

echo "Policy assignments have been deleted."
```

Log Analytics ワークスペースは共通リソースグループ `rg-hdbk-common` 内にあり、後続の章で利用するため、まだ削除しません。

---

お疲れ様でした。これで、ログの集約基盤と、ガバナンスの基本となるポリシーを設定し、その効果を実際に確認することができました。ランディングゾーンの準備は万全です。

次の章では、いよいよネットワーク基盤の構築に進みます。
