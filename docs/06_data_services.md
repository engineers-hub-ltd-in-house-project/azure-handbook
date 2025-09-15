# 第6章: データサービス

アプリケーションは、その状態をどこかに保存する必要があります。ユーザーのプロフィール、商品の在庫、イベントのログなど、データはアプリケーションの生命線です。この章では、Azure が提供する数多くのデータサービスの中から、あらゆるアプリケーションの基礎となる2つの重要なサービスに焦点を当てます。

1.  **Azure Storage Account**: Azure のストレージサービスの基本となる、非常に汎用性の高いサービスです。AWS の S3、EFS、SQS、DynamoDB の一部の機能を一つの傘の下で提供するようなイメージです。内部的には以下の4つのサービスに分かれています。
    - **Blob Storage**: 画像、動画、バックアップファイルなどのオブジェクトストレージ。S3 や Cloud Storage に相当。
    - **File Storage**: SMB/NFS プロトコルでアクセスできるマネージドファイル共有。EFS や Filestore に相当。
    - **Queue Storage**: シンプルなメッセージキューイングサービス。SQS や Pub/Sub に相当。
    - **Table Storage**: スキーマレスな NoSQL キーバリューストア。DynamoDB や Bigtable に相当。

2.  **Azure Database for PostgreSQL - Flexible Server**: オープンソースのリレーショナルデータベースとして人気の PostgreSQL を、フルマネージドで提供するサービスです。特に「Flexible Server」というデプロイモデルは、**VNet 統合 (VNet Integration)** という強力なネットワーク分離機能を提供し、データベースをパブリックインターネットから完全に隔離されたプライベートネットワーク内に配置することができます。これは AWS の RDS や GCP の Cloud SQL に相当します。

この章のハンズオンでは、セキュリティの観点から極めて重要な、**VNet統合を利用して PostgreSQL サーバーをプライベートなサブネットにデプロイする**という、実践的なシナリオを体験します。

---

## ハンズオン：VNet統合された PostgreSQL サーバーの構築

### 1. ゴール

- PostgreSQL Flexible Server 専用のサブネットを持つ VNet を作成する。
- 作成した専用サブネットに PostgreSQL Flexible Server をデプロイする。
- デプロイされたサーバーがパブリックネットワークからアクセスできなくなっていることを確認する。

### 2. 手順1: 変数定義

この章用のリソースグループと、作成するネットワーク、PostgreSQLサーバーの情報を変数に定義します。特に、パスワードは複雑なものを設定することが重要です。

```bash
export PREFIX="hdbk-data"
export RG="rg-${PREFIX}"
export LOCATION="japaneast"

export VNET_NAME="vnet-${PREFIX}"
export SNET_APP="snet-app-01" # アプリケーション用
export SNET_DB="snet-db-01"  # データベース用

export PG_SERVER_NAME="pgs-${PREFIX}-${RANDOM}"
export PG_ADMIN_USER="hdbkadmin"

# パスワードを生成 (記号を含む32文字のランダムな文字列)
export PG_ADMIN_PASS=$(openssl rand -base64 24 | tr -d "+/=")!aA0"
echo "Generated PostgreSQL Password: $PG_ADMIN_PASS"
```

### 3. 手順2: ネットワークの準備

PostgreSQL を配置するための、専用のサブネットを持つ VNet を作成します。

**ステップ 2-1: リソースグループの作成**

```bash
az group create --name $RG --location $LOCATION
```

**ステップ 2-2: VNet と2つのサブネットの作成**

将来アプリケーションを配置するためのサブネット (`snet-app-01`) と、データベース専用のサブネット (`snet-db-01`) を持つ VNet を作成します。

```bash
az network vnet create \
  --resource-group $RG \
  --name $VNET_NAME \
  --address-prefixes 10.30.0.0/16 \
  --subnet-name $SNET_APP \
  --subnet-prefixes 10.30.1.0/24

az network vnet subnet create \
  --resource-group $RG \
  --vnet-name $VNET_NAME \
  --name $SNET_DB \
  --address-prefixes 10.30.2.0/24
```

**ステップ 2-3: サブネットの委任 (Subnet Delegation)**

ここが非常に重要なステップです。PostgreSQL Flexible Server を VNet 統合でデプロイするには、そのサブネットを `Microsoft.DBforPostgreSQL/flexibleServers` サービスに **「委任 (delegate)」** する必要があります。これにより、Azure はそのサブネット内で、サービスの正常な動作に必要なネットワークリソース（例えば、NICなど）を管理する権限を得ます。

```bash
az network vnet subnet update \
  --resource-group $RG \
  --vnet-name $VNET_NAME \
  --name $SNET_DB \
  --delegations "Microsoft.DBforPostgreSQL/flexibleServers"
```

### 4. 手順3: PostgreSQL Flexible Server の作成

ネットワークの準備が整ったので、いよいよ PostgreSQL サーバーを作成します。`--subnet` パラメータに、先ほど委任したサブネットのIDを指定することで、サーバーはそのサブネット内にデプロイされます。

```bash
# データベース用サブネットのリソースIDを取得
export SUBNET_ID=$(az network vnet subnet show --resource-group $RG --vnet-name $VNET_NAME --name $SNET_DB --query id --output tsv)

# PostgreSQL Flexible Server を作成
az postgres flexible-server create \
  --resource-group $RG \
  --name $PG_SERVER_NAME \
  --location $LOCATION \
  --admin-user $PG_ADMIN_USER \
  --admin-password "$PG_ADMIN_PASS" \
  --subnet $SUBNET_ID \
  --tier Burstable \
  --sku-name Standard_B1ms \
  --storage-size 32 \
  --version 14
```

> **Note:** サーバーの作成には5〜10分程度かかる場合があります。

### 5. 検証

サーバーが無事に作成され、意図通りプライベートネットワーク内に配置されたことを確認します。

```bash
az postgres flexible-server show --resource-group $RG --name $PG_SERVER_NAME
```

**【成功の確認】**

出力された JSON の中で、以下の2つの項目を確認してください。

1.  `"publicNetworkAccess": "Disabled"`
    - これにより、サーバーがパブリックIPを持たず、インターネットから直接アクセスできないことが保証されます。
2.  `"privateDnsZone": "..."
    - サーバーにプライベートなDNS名が割り当てられていることを示します。VNet内のリソース（例えば、アプリケーションサーバー）は、このDNS名を使ってデータベースに接続します。

これらの設定が確認できれば、セキュアなデータベースのデプロイは成功です。

### 6. 後片付け

この章で作成したリソースを、リソースグループごと削除します。

```bash
az group delete --name $RG --yes --no-wait

echo "Resource group '$RG' is being deleted."
```

---

お疲れ様でした。これで、アプリケーションのデータを安全に保管するための、VNet統合されたマネージドデータベースを構築することができました。PaaSサービスをプライベートネットワークに統合するスキルは、Azure でセキュアなシステムを構築する上で不可欠です。

次の章では、これまで構築してきたリソースが正常に動作しているかを監視し、問題が発生した際に即座に検知するための「監視・ログ・アラート」の仕組みについて学びます。
