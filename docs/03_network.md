# 第3章: ネットワーク基盤

ランディングゾーンという「安全な砂場」が用意できたので、次はその中に家（アプリケーション）を建てるための土地（ネットワーク）を整備します。Azure におけるネットワークの基礎は **VNet (Virtual Network)** です。これは、AWS の VPC や GCP の VPC ネットワークに相当する、ユーザー専用のプライベートなネットワーク空間です。

この章では、アプリケーションを配置するための基本的なネットワーク構成を CLI で構築します。具体的には、以下のコンポーネントを作成し、それらがどのように連携するのかを学びます。

1.  **VNet とサブネット**: アプリケーションが動作する基本的なネットワーク空間と、その中でのIPアドレス範囲の分割。
2.  **ネットワークセキュリティグループ (NSG)**: サブネットに出入りするトラフィックを制御する、ステートフルなファイアウォール。AWS のセキュリティグループに相当します。
3.  **Private Endpoint と Private DNS Zone**: Azure の PaaS サービス（この章ではストレージアカウント）に対して、パブリックインターネットを経由せず、VNet 内からプライベートIPアドレスでセキュアに接続するための仕組みです。これにより、セキュリティを大幅に向上させることができます。

この章を終えれば、あなたはセキュアで独立したネットワーク空間を定義し、その中でリソースを安全に動かすためのネットワークの基礎を固めることができます。

---

## ハンズオン：VNet, NSG, Private Endpoint の構築

### 1. ゴール

- アプリケーション用のサブネットを持つ VNet が存在する。
- サブネットが NSG によって保護されている。
- VNet 内から Azure Storage アカウントに、Private Endpoint を経由してプライベートに接続できる状態になっている。

### 2. 手順1: 変数定義

この章で閉じたリソースグループを作成し、その中で作業を行います。これにより、章の最後にリソースグループごと削除することで、クリーンアップが容易になります。

```bash
export PREFIX="hdbk-net"
export RG="rg-${PREFIX}"
export LOCATION="japaneast"

export VNET_NAME="vnet-${PREFIX}"
export SNET_NAME="snet-app-01"
export NSG_NAME="nsg-app-01"
```

### 3. 手順2: VNet と NSG の作成

まず、ネットワークの骨格となる VNet、サブネット、そしてそれを保護する NSG を作成します。

**ステップ 2-1: リソースグループの作成**

```bash
az group create --name $RG --location $LOCATION
```

**ステップ 2-2: VNet とサブネットの作成**

`az network vnet create` コマンドで VNet を作成します。`--address-prefixes` で VNet 全体のIPアドレス範囲を、`--subnet-name` と `--subnet-prefixes` で最初のサブネットの情報を同時に定義します。

```bash
az network vnet create \
  --resource-group $RG \
  --name $VNET_NAME \
  --address-prefixes 10.20.0.0/16 \
  --subnet-name $SNET_NAME \
  --subnet-prefixes 10.20.1.0/24
```

**ステップ 2-3: NSG の作成とサブネットへの関連付け**

次に、空の NSG を作成し、`az network vnet subnet update` コマンドを使って先ほど作成したサブネットに関連付けます。

```bash
# NSGの作成
az network nsg create --resource-group $RG --name $NSG_NAME

# サブネットとNSGの関連付け
az network vnet subnet update \
  --resource-group $RG \
  --vnet-name $VNET_NAME \
  --name $SNET_NAME \
  --network-security-group $NSG_NAME
```

**ステップ 2-4: NSG ルールの追加**

デフォルトでは、NSG は同一 VNet 内からの通信を許可しますが、ここでは例として、外部からのHTTP/HTTPSアクセスを許可するルールを追加してみましょう。`--priority` の数値が小さいルールから評価されます。

```bash
az network nsg rule create \
  --resource-group $RG \
  --nsg-name $NSG_NAME \
  --name Allow-HTTP-HTTPS-Inbound \
  --priority 1000 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --destination-port-ranges 80 443
```

### 4. 手順3: Private Endpoint の設定

次に、この VNet 内から Azure Storage にプライベート接続するための設定を行います。

**ステップ 3-1: 接続先のストレージアカウント作成**

まず、プライベート接続の対象となるストレージアカウントを作成します。名前がグローバルで一意である必要があるため、ランダムな文字列を付加しています。

```bash
# ストレージアカウント名を変数に設定 (末尾にランダム文字列を追加)
export SA_NAME="st${PREFIX//-/}$RANDOM"

# ストレージアカウントの作成
az storage account create \
  --resource-group $RG \
  --name $SA_NAME \
  --sku Standard_LRS \
  --kind StorageV2
```

**ステップ 3-2: Private DNS ゾーンの作成とリンク**

Private Endpoint の名前解決の鍵となるのが **Private DNS ゾーン** です。`privatelink.blob.core.windows.net` のような、PaaSサービスのプライベートリンク用ドメインに対するDNSゾーンを作成し、VNetにリンクします。これにより、VNet内からのDNSクエリだけが、パブリックIPではなくプライベートIPを返すようになります。

```bash
# Private DNSゾーンの作成 (ストレージのBLOBサービス用)
az network private-dns zone create \
  --resource-group $RG \
  --name "privatelink.blob.core.windows.net"

# 作成したDNSゾーンとVNetをリンク
az network private-dns link vnet create \
  --resource-group $RG \
  --zone-name "privatelink.blob.core.windows.net" \
  --name "link-to-${VNET_NAME}" \
  --virtual-network $VNET_NAME \
  --registration-enabled false
```

**ステップ 3-3: Private Endpoint の作成**

いよいよ Private Endpoint を作成します。どのサブネットに配置し (`--subnet`)、どのリソースに (`--private-connection-resource-id`)、どのサブサービス (`--group-ids`、今回は`blob`) に接続するかを指定します。

```bash
# ストレージアカウントのリソースIDを取得
export SA_ID=$(az storage account show --resource-group $RG --name $SA_NAME --query id --output tsv)

# Private Endpointの作成
az network private-endpoint create \
  --resource-group $RG \
  --name "pe-${SA_NAME}" \
  --vnet-name $VNET_NAME \
  --subnet $SNET_NAME \
  --private-connection-resource-id $SA_ID \
  --group-ids blob \
  --connection-name "peconn-${SA_NAME}"
```

### 5. 検証

作成したリソースが意図通りに設定されているかを確認します。

**検証1: Private Endpoint の確認**

作成された Private Endpoint の一覧と、その接続状態を確認します。

```bash
az network private-endpoint list --resource-group $RG --output table
```

**検証2: ストレージアカウント側の接続状態確認**

ストレージアカウント側から見ても、Private Endpoint との接続が `Approved` (承認済み) になっていることを確認します。

```bash
az storage account show --name $SA_NAME --resource-group $RG --query "privateEndpointConnections[].privateLinkServiceConnectionState.status" --output tsv
```

**【成功の確認】**
`Approved` という文字列が表示されれば、VNet とストレージアカウントがプライベートに接続されたことを意味します。

### 6. 後片付け

この章で作成したリソースは、すべてリソースグループ `$RG` の中にあります。リソースグループごと削除するのが、最も簡単で確実なクリーンアップ方法です。

`--no-wait` オプションを付けると、削除の完了を待たずにコマンドが終了します。バックグラウンドで削除が進行します。

```bash
az group delete --name $RG --yes --no-wait

echo "Resource group '$RG' is being deleted."
```

---

お疲れ様でした。これで、VNet を作成し、NSG で保護し、さらに Private Endpoint を使って PaaS サービスへセキュアに接続するという、Azure ネットワークの基本的な構成をマスターしました。

次の章では、ID とセキュリティの基盤について学びます。
