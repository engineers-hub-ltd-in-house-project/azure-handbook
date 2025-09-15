# 第7章: 監視・ログ・アラート

システムを構築して動かすだけでは、プロの仕事とは言えません。そのシステムが「正常に動作しているか」を常に把握し、「問題が発生した際に即座に検知」し、「パフォーマンスのボトルネックを特定」する能力、すなわち **オブザーバビリティ（可観測性）** を確保することが不可欠です。

この章では、Azure における監視の統合プラットフォームである **Azure Monitor** を使い、システムのオブザーバビリティを確保するための基本的なサイクルを学びます。

1.  **データ収集 (Collect)**: Azure リソースからログやメトリックを収集します。この「配管工事」の役割を担うのが **診断設定 (Diagnostic Settings)** です。
2.  **分析 (Analyze)**: 収集したデータを一元的に蓄積し、**Kusto Query Language (KQL)** という強力なクエリ言語で分析します。このデータレイク兼分析エンジンが **Log Analytics ワークスペース** です。
3.  **対応 (Respond)**: 分析結果に基づき、特定の条件を満たした場合に通知を送信したり、自動修復アクションを実行したりします。これが **アラート** の役割です。

この一連の流れは、AWS の CloudWatch (Logs, Metrics, Alarms) や、Google Cloud の Operations Suite (Logging, Monitoring, Alerting) と同じ考え方に基づいています。この章のハンズオンを通じて、Azure での基本的な監視パイプラインを構築するスキルを習得しましょう。

---

## ハンズオン：ストレージアカウントの操作を監視し、アラートを設定する

### 1. ゴール

- ストレージアカウントを作成し、その操作ログが Log Analytics ワークスペースに送信されるように設定する。
- ストレージアカウントにファイルをアップロードし、その操作ログを KQL を使って確認する。
- ストレージアカウントのトランザクション数に基づいてメトリックアラートを作成する。

### 2. 手順1: 変数定義

```bash
export PREFIX="hdbk-mon"
export RG="rg-${PREFIX}"
export LOCATION="japaneast"

# Log Analytics ワークスペース名
export LAW_NAME="law-${PREFIX}"

# 監視対象のストレージアカウント名
export SA_NAME="st${PREFIX//-/}$RANDOM"
```

### 3. 手順2: 監視基盤と監視対象の準備

**ステップ 2-1: リソースグループと Log Analytics ワークスペースの作成**

まず、ログの集約先となるリソースグループと Log Analytics ワークスペースを作成します。

```bash
az group create --name $RG --location $LOCATION

az monitor log-analytics workspace create \
  --resource-group $RG \
  --workspace-name $LAW_NAME
```

**ステップ 2-2: 監視対象のストレージアカウント作成**

次に、監視対象となるストレージアカウントを作成します。

```bash
az storage account create \
  --resource-group $RG \
  --name $SA_NAME \
  --sku Standard_LRS
```

### 4. 手順3: 診断設定によるログ収集

ここが監視の第一歩です。ストレージアカウントの「診断設定」を構成し、操作ログ (`StorageWrite`) とすべてのメトリックを Log Analytics ワークスペースに送信するように設定します。

```bash
# リソースIDを変数に格納
export LAW_ID=$(az monitor log-analytics workspace show --resource-group $RG --name $LAW_NAME --query id --output tsv)
export SA_ID=$(az storage account show --resource-group $RG --name $SA_NAME --query id --output tsv)

# 診断設定を作成
az monitor diagnostic-settings create \
  --name "send-to-log-analytics" \
  --resource $SA_ID \
  --workspace $LAW_ID \
  --logs '[{"category": "StorageWrite", "enabled": true}]' \
  --metrics '[{"category": "Transaction", "enabled": true}]'
```

### 5. 手順4: ログの生成とクエリ

**ステップ 4-1: ログの生成**

診断設定が有効になったので、実際にストレージアカウントを操作してログを生成してみましょう。テスト用のファイルをアップロードします。

```bash
# テスト用のファイルを作成
echo "Hello, Monitor!" > test.txt

# ストレージコンテナを作成し、ファイルをアップロード
# ※事前にaz loginしたアカウントで--auth-mode loginが利用できる権限(例:Storage Blob Data Contributor)が必要
az storage container create --name "test-container" --account-name $SA_NAME --auth-mode login
az storage blob upload --container-name "test-container" --name "test.txt" --file "test.txt" --account-name $SA_NAME --auth-mode login
```

**ステップ 4-2: KQLによるログのクエリ**

ログが Log Analytics に到着するまで数分かかることがあります。少し待ってから、`az monitor log-analytics query` コマンドを使って、先ほどのアップロード操作 (`PutBlob`) のログを検索してみましょう。

```bash
# KQLクエリを実行
az monitor log-analytics query \
  --workspace $LAW_ID \
  --analytics-query "StorageBlobLogs | where OperationName == 'PutBlob' | project TimeGenerated, OperationName, Uri"
```

**【成功の確認】**
`TimeGenerated`、`OperationName`、`Uri` を含む結果がJSON形式で返ってくれば、ログが正しく収集・検索できている証拠です。

### 6. 手順5: メトリックアラートの作成

最後に、ストレージアカウントのトランザクション数が一定値を超えたらアラートを発報するルールを作成します。ここでは簡単のため、通知先（アクショングループ）は設定せず、アラートルールのみを作成します。

```bash
# アラートルールを作成
az monitor metrics alert create \
  --resource-group $RG \
  --name "alert-sa-transactions" \
  --scopes $SA_ID \
  --condition "total transactions > 5" \
  --description "Storage account transactions exceeded 5 in the last 5 minutes."
```

- `--scopes`: アラートの監視対象リソース。
- `--condition`: アラートの発報条件。「メトリック名」「集計方法」「演算子」「しきい値」を記述します。

### 7. 検証

作成したアラートルールが正しく存在するかを確認します。

```bash
az monitor metrics alert show --resource-group $RG --name "alert-sa-transactions"
```

**【成功の確認】**
`name` が `alert-sa-transactions` となっているアラートルールの詳細情報がJSONで表示されれば成功です。

### 8. 後片付け

この章で作成したリソースを、リソースグループごと削除します。

```bash
az group delete --name $RG --yes --no-wait

echo "Resource group '$RG' is being deleted."
```

---

お疲れ様でした。これで、リソースからデータを収集し、分析し、異常を検知するという、Azure Monitor を使った基本的な監視サイクルを体験できました。実際の運用では、KQLクエリを駆使した高度な分析や、メールやTeams、PagerDutyなどに通知するためのアクショングループの設定が次のステップとなります。

次の章では、これまでの手作業によるCLI操作をコード化し、再利用可能かつ自動化された形に昇華させる「IaC & CI/CD」について学びます。
