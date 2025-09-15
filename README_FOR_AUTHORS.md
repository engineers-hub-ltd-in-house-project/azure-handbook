以下は、**「（他クラウド経験者向け）Azure CLI 実践ハンドブック」構築指示書**です。
AWS/GCP の深い経験を Azure に最短距離で“移植”できるよう、**CLI 中心（`az`/Bicep/Terraform）**で、**環境構築～保守運用（Day 0/1/2）**を一気通貫に学べるハンズオン教材を作る前提でまとめています。将来的な**電子書籍化**も想定しています。

---

## 1) 目的と読者像

* **読者**:

  * AWS ~15年 / GCP ~8年クラスの中上級者。クラウドの基本概念は理解済み。
  * Azure は初～中級。Portal より CLI を好む／IaC ベースで進めたい人。
* **ハンドブックの目的**:

  * “**他クラウドの感覚で Azure を正しく使う**”ための写経＋理由がセットのハンズオン。
  * **最小のランディングゾーン**から、ネットワーク、ID、セキュリティ、監視、運用自動化までを CLI で実装・検証・運用できるスキルを獲得。
* **完了時にできること（到達スキル）**:

  * 企業テナント上の**サブスクリプション／管理グループ／ポリシー**の最低限のガバナンスを CLI で定義・適用。
  * **VNet/Private Endpoint/NSG/UDR** 等のネットワーク基盤を再現可能に構築。
  * **Key Vault / Storage / Container Apps / AKS** など主要 PaaS のセキュアな初期化。
  * **Azure Monitor + Log Analytics** への診断設定、メトリック／ログ収集、アラート・自動修復。
  * **Bicep/Terraform** による IaC、**GitHub Actions / Azure DevOps** によるデプロイ。
  * **バックアップ／DR／パッチ／インシデント対応**の運用 Runbook を CLI で実行。

---

## 2) 全体構成（目次・章立て案）

> 章ごとに「**ハンズオン（コマンド）**」「**設計の意図**」「**検証と成功判定**」「**後片付け**」を必ずセットで持たせます。

1. **準備**: 用語整理（Microsoft Entra ID/旧Azure AD、サブスクリプション/管理グループ、Resource Group、リージョン）、CLI 環境、命名・タグ規約
2. **最小ランディングゾーン（Light）**: 管理グループ、RBAC、基本ポリシー、課金ビュー、タグ戦略
3. **ネットワーク基盤**: VNet/サブネット、NSG、Private DNS、Private Endpoint、ハブ＆スポーク
4. **ID/セキュリティ基盤**: Entra ID、RBAC/PIM、Key Vault、Secrets/Keys、Defender ベースライン
5. **コンピュート & コンテナ**: Linux VM 最小、Container Apps、AKS（クイック）、イメージの供給とプル権限
6. **データサービス**: Azure Storage、PostgreSQL Flexible Server（VNet 統合）、接続性と暗号化
7. **監視・ログ・アラート**: Log Analytics、診断設定、メトリック/ログクエリ、アラートと自動化
8. **IaC & CI/CD**: Bicep/Terraform モジュール設計、GitHub Actions/Azure DevOps で OIDC/Federation、差分適用とドリフト検出
9. **運用（Day2）Runbook**: パッチ、スケール、バックアップ、災害対策、コスト最適化、変更管理
10. **トラブルシュート**: よくある落とし穴（権限／ポリシー／PE 接続／診断設定）、`az` での診断パターン
    付録A. **クロスクラウド対比表（AWS/GCP → Azure）**
    付録B. **命名規約・タグ・リージョン方針**
    付録C. **セキュリティ/コンプラ要件チェックリスト**
    付録D. **電子書籍ビルドパイプライン（md → EPUB/PDF）**

---

## 3) 執筆スタイル・原則（CLIファースト）

* **原則**:

  * 「**Portal スクショ禁止**。必要なら ‘CLIで同等操作’ を脚注で言及」。
  * **1コマンド＝1意図**。長コマンドは変数で分解。
  * **冪等性**を最優先（存在チェック→作成／更新、`--only-show-errors` の活用）。
  * **検証ファースト**：操作直後に `az ... show` / `list` / `monitor` で**機械的な成功判定**。
  * **後片付け（コスト抑制）**：`az group delete` などの**クリーンアップ手順を必須**。
* **表記**:

  * 変数 `<...>` は**必ず `export`** で定義してから使用。
  * 出力は `-o tsv` / `-o jsonc` と `jq` を併用して**短く確認**。
  * エラー時の**よくある原因と対処**を各手順末尾に短く記載。

---

## 4) 実行環境・前提

* **ローカル or Cloud Shell** いずれも可。ローカル例:

  ```bash
  # Azure CLI / Bicep / Terraform を準備
  az version
  az bicep version
  terraform -version

  # サブスクリプション確認 & 既定値
  az account show --query "{name:name, id:id}" -o table
  az account set --subscription "<SUBSCRIPTION_ID>"
  az config set defaults.location=japaneast
  ```
* **権限**: テナント/サブスクリプションの RBAC（例：Owner/Contributor）とポリシー適用権限。
* **命名/タグ**（例）:

  * 命名: `<sys>-<env>-<region>-<resourcetype>-<seq>`（例: `acct-prod-jpe-sa-001`）
  * タグ: `env`, `owner`, `costCenter`, `dataClass`, `expiryDate`

---

## 5) リポジトリ雛形（教材＆コード共用）

```
azure-handbook/
├─ docs/                    # 文章（Markdown）
│  ├─ 01_prep.md
│  ├─ 02_landing_zone_light.md
│  └─ ...
├─ labs/                    # 章ごとのハンズオン（README + スクリプト）
│  ├─ 02_lz_light/
│  ├─ 03_network/
│  └─ 07_monitoring/
├─ infra/
│  ├─ bicep/               # Bicep Modules（idempotent設計）
│  ├─ tf/                  # Terraform Modules
│  └─ env/                 # dev/stg/prd の構成差分
├─ scripts/
│  ├─ az/                  # コマンド群（bash）
│  └─ verify/              # 成功判定スクリプト
├─ .devcontainer/          # VS Code Dev Container（az/terraform入り）
├─ .github/workflows/      # eBook ビルド & IaC 検証
└─ mkdocs.yml / book.toml  # 文書サイト or mdBook 設定
```

---

## 6) 章別ハンズオン設計テンプレート

各章は以下のテンプレを厳守:

1. **ゴール**（何がデプロイされ、何が観測できるか）
2. **前提**（権限、コスト注意、時間目安）
3. **変数定義**（全コマンドで再利用）

   ```bash
   export LOCATION=japaneast
   export RG=rg-handbook-lz
   export LAW=law-handbook
   ```
4. **手順（CLI）**：**最小→拡張**の順で段階的
5. **検証**：`az ... show/list` + `jq` で**Yes/No**が出るコマンドを提供
6. **トラブルシュート**：典型的な権限・ポリシー・名前制約
7. **後片付け**：`az group delete -n $RG --yes --no-wait` など

---

## 7) 最小ランディングゾーン（Light）ハンズオン（例）

> 目的: サンドボックスで**安全に**章を進行できる最小ガードレールを CLI で構築。

* **Resource Group/タグ/課金視点**

  ```bash
  export RG=rg-handbook-foundation
  az group create -n $RG -l japaneast --tags env=handbook owner="<YOUR_NAME>"
  ```

* **Log Analytics + 診断送信の受け皿**

  ```bash
  export LAW=law-handbook
  az monitor log-analytics workspace create -g $RG -n $LAW
  export LAW_ID=$(az monitor log-analytics workspace show -g $RG -n $LAW --query id -o tsv)
  ```

* **代表的な**診断設定（テンプレ）

  ```bash
  # 例: Resource Group 配下の Storage へ一括適用するスクリプトを後章で提供
  # az monitor diagnostic-settings create --name send-to-law \
  #   --resource <RESOURCE_ID> --workspace $LAW_ID \
  #   --logs '[{"category":"StorageRead","enabled":true}]' \
  #   --metrics '[{"category":"AllMetrics","enabled":true}]'
  ```

* **ポリシーの最小適用（例: 必須タグ）**

  ```bash
  export POLICY_DEF="/subscriptions/<SUB_ID>/providers/Microsoft.Authorization/policyDefinitions/<BUILTIN_OR_CUSTOM_ID>"
  az policy assignment create --name require-tags \
    --policy $POLICY_DEF \
    --scope /subscriptions/<SUB_ID> \
    --params '{"tagName":{"value":"owner"}}'
  ```

* **成功判定**

  ```bash
  az group list -o table
  az policy assignment list --query "[].{name:name, scope:scope}" -o table
  ```

---

## 8) ネットワーク基盤ハンズオン（抜粋）

* **VNet/サブネット/NSG**

  ```bash
  export RG=rg-handbook-net
  export VNET=vnet-handbook
  export SNET_APP=snet-app
  export NSG_APP=nsg-app

  az group create -n $RG -l japaneast
  az network vnet create -g $RG -n $VNET \
    --address-prefixes 10.20.0.0/16 \
    --subnet-name $SNET_APP --subnet-prefixes 10.20.1.0/24
  az network nsg create -g $RG -n $NSG_APP
  az network vnet subnet update -g $RG --vnet-name $VNET -n $SNET_APP --network-security-group $NSG_APP
  az network nsg rule create -g $RG --nsg-name $NSG_APP -n allow-health --priority 1000 \
    --direction Inbound --access Allow --protocol Tcp --destination-port-ranges 80 443
  ```

* **Private DNS + Private Endpoint（Storage例）**

  ```bash
  export SA=st$(openssl rand -hex 3)
  az storage account create -g $RG -n $SA --sku Standard_LRS --kind StorageV2
  export SA_ID=$(az storage account show -g $RG -n $SA --query id -o tsv)

  # Private DNS ゾーン（blob）
  az network private-dns zone create -g $RG -n privatelink.blob.core.windows.net
  az network private-dns link vnet create -g $RG -n link-$VNET \
     -z privatelink.blob.core.windows.net -v $VNET -e true

  # Private Endpoint
  az network private-endpoint create -g $RG -n pe-$SA --vnet-name $VNET --subnet $SNET_APP \
     --private-connection-resource-id $SA_ID --group-ids blob \
     --connection-name peconn-$SA
  ```

* **成功判定**

  ```bash
  az network private-endpoint list -g $RG -o table
  az storage account show -g $RG -n $SA --query "privateEndpointConnections[].privateLinkServiceConnectionState.status"
  ```

---

## 9) コンピュート/コンテナ（抜粋：Container Apps）

```bash
export RG=rg-handbook-app
export ACA_ENV=acaenv-handbook
export ACA_APP=helloaca

az group create -n $RG -l japaneast
az extension add --name containerapp --upgrade
az provider register --namespace Microsoft.App

# 環境
az containerapp env create -g $RG -n $ACA_ENV --location japaneast

# アプリ
az containerapp create -g $RG -n $ACA_APP \
  --environment $ACA_ENV \
  --image mcr.microsoft.com/azuredocs/containerapps-helloworld:latest \
  --ingress external --target-port 80 \
  --query properties.configuration.ingress.fqdn -o tsv
```

**成功判定**: 返ってきた FQDN に `curl`。`az containerapp show` で `ingress.fqdn` を確認。

---

## 10) 監視・ログ・アラート（抜粋）

```bash
export RG=rg-handbook-monitor
export LAW=law-handbook
export SA=sthandbooklogs$RANDOM

az group create -n $RG -l japaneast
az monitor log-analytics workspace create -g $RG -n $LAW
export LAW_ID=$(az monitor log-analytics workspace show -g $RG -n $LAW --query id -o tsv)

# 監視対象例: Storage の診断設定
az storage account create -g $RG -n $SA --sku Standard_LRS --kind StorageV2
az monitor diagnostic-settings create --name to-law \
  --resource $(az storage account show -g $RG -n $SA --query id -o tsv) \
  --workspace $LAW_ID \
  --metrics '[{"category":"AllMetrics","enabled":true}]' \
  --logs '[{"category":"StorageRead","enabled":true},{"category":"StorageWrite","enabled":true},{"category":"StorageDelete","enabled":true}]'

# メトリックアラート例: 5xx が一定回数以上（リソースに合わせて）
# az monitor metrics alert create ...
```

---

## 11) IaC & CI/CD（骨子）

* **Bicep モジュール設計**

  * `infra/bicep/modules/<resource>` 単位。出力に**Resource ID**を返す。
  * `infra/bicep/env/<env>.bicep` で構成を合成。
* **Bicep デプロイ（例：RGスコープ）**

  ```bash
  az deployment group create -g $RG -f infra/bicep/env/dev.bicep -p @infra/bicep/env/dev.parameters.json
  ```
* **Terraform（任意）**

  * `azurerm` プロバイダ、`remote_state`（Blob Backend）を紹介。
* **CI/CD（GitHub Actions 例：OIDC 連携）**

  ```yaml
  name: deploy-bicep
  on: [push]
  jobs:
    deploy:
      permissions:
        id-token: write
        contents: read
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout @v4
        - uses: azure/login @v1
          with:
            client-id: ${{ secrets.AZURE_CLIENT_ID }}
            tenant-id: ${{ secrets.AZURE_TENANT_ID }}
            subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
            enable-AzPSSession: false
        - name: Deploy
          run: |
            az deployment group create -g rg-handbook-app \
              -f infra/bicep/env/dev.bicep \
              -p @infra/bicep/env/dev.parameters.json
  ```

---

## 12) 運用（Day2）Runbook（抜粋：CLI 例）

* **バックアップ（Recovery Services Vault）**

  ```bash
  export RG=rg-handbook-bkp
  export RSV=vault-handbook
  az group create -n $RG -l japaneast
  az backup vault create -g $RG -n $RSV -l japaneast
  # VM/データベースごとに保護ポリシー適用手順を章内で分けて記載
  ```

* **Key Vault ローテーション**

  ```bash
  az keyvault key rotate --vault-name <KV_NAME> --name <KEY_NAME>
  ```

* **スケール（Container Apps）**

  ```bash
  az containerapp revision set-mode -g $RG -n $ACA_APP --mode single
  az containerapp update -g $RG -n $ACA_APP --min-replicas 1 --max-replicas 5
  ```

* **コスト可視化（タグ×リソース）**

  ```bash
  az resource list --tag env=handbook --query "[].{name:name,type:type,rg:resourceGroup}" -o table
  # コスト API は REST/CostManagement を付録に記載
  ```

---

## 13) トラブルシュート章の観点（見出しだけ）

* **RBAC/ポリシーで作成失敗**（`AuthorizationFailed`）
* **Private Endpoint/DNS 解決不可**（FQDN が PIP を引く）
* **診断設定の未適用**（カテゴリ不足）
* **リージョン間の SKU 差異**
* **API プロバイダ未登録**（`az provider register`）

---

## 14) 付録A：クロスクラウド対比（ショート版）

| AWS                 | GCP                      | Azure                                                      | 
| ------------------- | ------------------------ | ---------------------------------------------------------- | 
| IAM（ロール）            | IAM                      | **RBAC**（スコープ: MG/Subscription/RG/Resource）                | 
| Organizations       | Resource Hierarchy       | **Management Groups**                                      | 
| VPC                 | VPC                      | **VNet**                                                   | 
| Subnet              | Subnet                   | **Subnet**                                                 | 
| SG/NACL             | Firewall                 | **NSG**（NACL 相当は無し／UDR 併用）                                 | 
| Route Table         | Routes                   | **UDR（ルートテーブル）**                                           | 
| S3                  | GCS                      | **Blob Storage**                                           | 
| EC2                 | GCE                      | **Virtual Machines**                                       | 
| ELB/ALB/NLB         | Load Balancer            | **Azure Load Balancer / Application Gateway / Front Door** | 
| KMS/Secrets Manager | KMS/Secret Manager       | **Key Vault**                                              | 
| CloudWatch          | Cloud Monitoring/Logging | **Azure Monitor / Log Analytics**                          | 
| CloudTrail          | Audit Logs               | **Activity Log（＋診断ログ）**                                    | 
| CloudFormation      | Deployment Manager       | **ARM/Bicep**                                              | 
| EKS                 | GKE                      | **AKS**                                                    | 
| Lambda              | Cloud Functions          | **Azure Functions**                                        | 
| Cloud Run           | Cloud Run                | **Container Apps**                                         | 

---

## 15) 電子書籍化ワークフロー（提案）

* **原稿**: Markdown（`docs/`）、コードは `labs/` や `infra/` から参照。
* **ビルド**: mdBook or MkDocs → HTML / PDF / EPUB。
* **CI**: `push` で Lint（markdownlint）、リンクチェック、ビルド、**Release に EPUB/PDF 添付**。
* **ライセンス**: 文章は CC BY-NC、コードは Apache-2.0 などを章頭で明記。
* **版管理**: “Azure CLI バージョン” と “最終検証日” を各章のフッタに自動挿入。

---

## 16) 品質バー（レビュー観点）

* **再実行可能**：同じ環境で**ゼロから 3 回連続成功**。
* **検証の自動化**：`scripts/verify/` のスクリプトで**合否**の判定が出る。
* **コスト抑制**：章末の**必須クリーンアップ**でリソース残なし。
* **セキュリティ**：RBAC 最小権限、秘密情報は **Key Vault or OIDC**。
* **可読性**：1 コマンド 1 行、注・背景は別見出しで簡潔。

---

## 17) 最初の 2 章の“叩き台”サンプル（抜粋）

**章1：準備**

```bash
# 1. ログイン & 既定設定
az login
az account set --subscription "<SUBSCRIPTION_ID>"
az config set defaults.location=japaneast

# 2. 変数
export PREFIX=handbook
export RG=$PREFIX-common

# 3. 共通RG
az group create -n $RG -l japaneast --tags env=handbook owner="<YOU>"

# 4. 成功判定
az group show -n $RG --query "{name:name,location:location,tags:tags}" -o jsonc
```

**章2：LZ Light（タグ必須ポリシー & ログ基盤）**

```bash
# 1) Log Analytics
export LAW=$PREFIX-monitor
az monitor log-analytics workspace create -g $RG -n $LAW
export LAW_ID=$(az monitor log-analytics workspace show -g $RG -n $LAW --query id -o tsv)

# 2) ポリシー（例: owner タグ必須）
export SUB_ID=$(az account show --query id -o tsv)
export POLICY_DEF="/subscriptions/$SUB_ID/providers/Microsoft.Authorization/policyDefinitions/<REQUIRE-TAG-POLICY-ID>"
az policy assignment create --name require-owner-tag \
  --policy $POLICY_DEF \
  --scope /subscriptions/$SUB_ID \
  --params '{"tagName":{"value":"owner"}}'

# 3) 成功判定
az policy assignment list --query "[?name=='require-owner-tag'].{scope:scope}" -o table
```

---

## 18) 執筆・開発の進め方（スプリント計画例）

* **Sprint 1（2週間）**: 章1～3（準備／LZ Light／ネットワーク）叩き台＋検証スクリプト
* **Sprint 2（2週間）**: 章4～6（ID/セキュリティ／コンテナ／データ）
* **Sprint 3（2週間）**: 章7～9（監視／IaC & CI/CD／運用）＋付録
* **Sprint 4（1週間）**: 電子書籍 CI、校正、用語統一、ライセンス表記

---

## 19) 次の一手（すぐ着手できるタスク）

1. 本指示書を `README_FOR_AUTHORS.md` としてリポジトリに配置。
2. `docs/01_prep.md` と `labs/02_lz_light/README.md` をこのまま流用して初稿作成。
3. `scripts/verify/` に「ポリシー適用／診断設定／PE 正常性」の**合否スクリプト**を置く。
4. 章末クリーンアップを**全章で必須化**。
5. CI に **lint + 章末コマンドの Dry-run** を追加。

---

必要であれば、この構成をベースに**各章の全文草案（Markdown）**、**Bicep/Terraform モジュール雛形**、**検証スクリプト**まで一式を生成してお渡しできます。どの章から“深掘り”しますか？
