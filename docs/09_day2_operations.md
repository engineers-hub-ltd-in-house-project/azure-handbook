# 第9章: 運用（Day2）Runbook

おめでとうございます！あなたはこれまでの章で、Azure上にネットワーク、セキュリティ、コンピュート、データ、監視、そしてCI/CDパイプラインといった一連の環境を構築するスキルを習得しました。これは「Day 0 (設計)」と「Day 1 (デプロイ)」のフェーズにあたります。

しかし、システムのライフサイクルはデプロイして終わりではありません。むしろ、そこからが本番です。デプロイ後の日々の運用・保守・改善活動は **「Day 2 オペレーション」** と呼ばれ、システムの安定稼働と価値の最大化に不可欠です。

この章では、Day 2 オペレーションで頻繁に発生するであろう典型的なタスクを、CLIベースの **「Runbook（手順書）」** 形式で紹介します。これまでのように新しいものを構築するのではなく、既存のリソースを「どう管理していくか」に焦点を当てます。

---

## Runbook 1: コンテナアプリのスケーリングルールの調整

**シナリオ**: アプリケーションの利用者が増え、より多くのトラフィックを処理する必要が出てきました。コンテナアプリの最大レプリカ数を増やして、負荷に対応できるようにします。

### 1. 準備

まず、スケール対象のコンテナアプリを準備します。（第5章の復習です）

```bash
export PREFIX="hdbk-day2-app"
export RG="rg-${PREFIX}"
export LOCATION="japaneast"
export ACA_ENV="acaenv-${PREFIX}"
export ACA_APP="app-day2-scale"

az group create --name $RG --location $LOCATION
az provider register --namespace Microsoft.App
az containerapp env create --resource-group $RG --name $ACA_ENV --location $LOCATION
az containerapp create \
  --resource-group $RG \
  --name $ACA_APP \
  --environment $ACA_ENV \
  --image mcr.microsoft.com/azuredocs/containerapps-helloworld:latest \
  --ingress external \
  --min-replicas 1 --max-replicas 2 # 初期設定
```

### 2. 実行: スケールルールの更新

`az containerapp update` コマンドを使い、最小レプリカを`1`、最大レプリカを`5`に更新します。これにより、負荷に応じてコンテナが最大5つまで自動的にスケールアウトするようになります。

```bash
az containerapp update \
  --resource-group $RG \
  --name $ACA_APP \
  --min-replicas 1 \
  --max-replicas 5
```

### 3. 検証

`az containerapp show` で設定が変更されたことを確認します。

```bash
az containerapp show --resource-group $RG --name $ACA_APP --query "properties.configuration.scale"
```

**【成功の確認】**: `maxReplicas` が `5` になっていれば成功です。

### 4. 後片付け

```bash
az group delete --name $RG --yes --no-wait
```

---

## Runbook 2: データベースのポイントインタイムリストア

**シナリオ**: 誤ってアプリケーションがデータベースの重要なテーブルを更新してしまいました。幸い、Azure Database for PostgreSQLは自動的にバックアップを取得しています。問題が発生する直前の状態にデータベースを復元します。

### 1. 準備

リストア対象のデータベースを準備します。（第6章の復習です）

```bash
export PREFIX="hdbk-day2-db"
export RG="rg-${PREFIX}"
export LOCATION="japaneast"
export PG_SERVER_NAME="pgs-${PREFIX}-${RANDOM}"
export PG_ADMIN_USER="hdbkadmin"
export PG_ADMIN_PASS=$(openssl rand -base64 24 | tr -d "+/=)!aA0")

az group create --name $RG --location $LOCATION
az postgres flexible-server create \
  --resource-group $RG --name $PG_SERVER_NAME --location $LOCATION \
  --admin-user $PG_ADMIN_USER --admin-password "$PG_ADMIN_PASS" \
  --tier Burstable --sku-name Standard_B1ms --storage-size 32 --yes
```

> **Note:** サーバー作成後、リストアが可能になるまで少し時間がかかる場合があります。

### 2. 実行: ポイントインタイムリストア

`az postgres flexible-server restore` コマンドを実行します。`--restore-time` で復元したい時刻（UTC）を指定し、`--source-server` で元のサーバー名を指定します。**リストアは常に新しいサーバーとして作成される**ため、`--name` には新しいサーバー名を指定します。これにより、元のサーバーを上書きする事故を防ぎます。

```bash
# 現在時刻の5分前をリストアポイントとして指定 (例)
export RESTORE_TIME=$(date -u -d '5 minutes ago' +'%Y-%m-%dT%H:%M:%SZ')
export PG_RESTORED_NAME="${PG_SERVER_NAME}-restored"

echo "Restoring to time: $RESTORE_TIME"

az postgres flexible-server restore \
  --resource-group $RG \
  --name $PG_RESTORED_NAME \
  --source-server $PG_SERVER_NAME \
  --restore-time "$RESTORE_TIME"
```

### 3. 検証

新しいサーバーが `Succeeded` 状態で作成されていることを確認します。

```bash
az postgres flexible-server show --resource-group $RG --name $PG_RESTORED_NAME --query "state"
```

### 4. 後片付け

```bash
az group delete --name $RG --yes --no-wait
```

---

## Runbook 3: 変更履歴の追跡

**シナリオ**: 「昨日の夕方から、急にアプリケーションの挙動がおかしくなった。誰かが何か変更したかもしれない。」リソースへの変更履歴を調査します。

### 1. 準備

調査対象のリソースグループを作成し、何か操作（例: タグの更新）を行なってログを生成します。

```bash
export PREFIX="hdbk-day2-log"
export RG="rg-${PREFIX}"
export LOCATION="japaneast"

az group create --name $RG --location $LOCATION
az group update --name $RG --tags status=testing # 変更操作
```

### 2. 実行: アクティビティログの確認

`az monitor activity-log list` を使って、指定したリソースグループの操作履歴を一覧表示します。`--query` を使って、必要な情報（いつ、誰が、何をしたか）を整形して表示します。

```bash
az monitor activity-log list \
  --resource-group $RG \
  --query "[].{time:eventTimestamp, caller:caller, operation:operationName.value}" \
  --output table
```

### 3. 検証

**【成功の確認】**: 出力されたテーブルに、先ほど実行した `Microsoft.Resources/tags/write` (タグ更新) の操作が、あなたの `caller` (メールアドレスなど) と共に記録されていれば成功です。これにより、いつ誰が何をしたかを正確に追跡できます。

### 4. 後片付け

```bash
az group delete --name $RG --yes --no-wait
```

---

お疲れ様でした。この章で紹介したRunbookは、日々の運用業務のほんの一例です。しかし、どのような複雑なタスクであっても、このようにCLIコマンドとして手順をコード化しておくことで、誰でも迅速かつ正確に作業を遂行できるようになります。

次の最終章では、トラブルシューティングの典型的なパターンについて学びます。
