# 第10章: トラブルシュート

クラウドジャーニーの最終章へようこそ。これまでの章で、あなたはAzure上に様々なリソースを構築し、管理し、自動化するスキルを身につけました。しかし、実際のプロジェクトでは、予期せぬエラーや問題が必ず発生します。重要なのは、問題に直面した際に、冷静に原因を切り分け、解決策を見つけ出す能力です。

この章は、これまでのハンズオンとは異なり、特定の問題解決に焦点を当てた「診断Runbook」の集まりです。Azure CLIを単なる構築ツールとしてだけでなく、強力な「診断ツール」として活用する方法を学びます。ここで紹介する体系的なアプローチを身につければ、未知の問題にも自信を持って対処できるようになるでしょう。

基本的なトラブルシューティングの心構えは以下の通りです。

1.  **エラーメッセージを正確に読む**: エラーメッセージには、原因を特定するための重要なヒントがほぼ必ず含まれています。
2.  **権限（RBAC）と制約（Policy）を疑う**: 特にリソースの作成・更新系エラーの多くは、権限かポリシーが原因です。
3.  **設定の確認**: 作成したリソースの設定（特にネットワーク関連）が意図通りか、CLIで一つ一つ確認します。
4.  **ログを確認する**: アクティビティログや診断ログには、エラーの直接的な原因が記録されていることがあります。

---

## パターン1: 権限・ポリシーによる失敗

**症状**: リソースを作成・更新しようとすると、`AuthorizationFailed` や `RequestDisallowedByPolicy` というエラーで失敗する。

### 診断Runbook

1.  **自分のIDとスコープを確認する**
    - `az account show`: まず、自分が意図したユーザー、またはサービスプリンシパルとしてログインしているかを確認します。

2.  **RBACの割り当てを確認する (`AuthorizationFailed` の場合)**
    - 必要なロール（例: `Contributor`）が、操作対象のスコープ（リソースグループなど）で自分に割り当てられているかを確認します。
    ```bash
    # 例: 特定のリソースグループに対する自分のロール割り当てを確認
    az role assignment list --resource-group <RG_NAME> --assignee <YOUR_USER_PRINCIPAL_NAME> --all
    ```

3.  **ポリシーの割り当てを確認する (`RequestDisallowedByPolicy` の場合)**
    - エラーメッセージに、どのポリシーが原因でブロックされたかが示されています。そのポリシーが、操作対象のスコープに割り当てられていないか確認します。
    ```bash
    # 例: 特定のリソースグループに適用されているポリシー割り当てを一覧表示
    az policy assignment list --resource-group <RG_NAME>
    ```

---

## パターン2: Private Endpoint の名前解決ができない

**症状**: VNet内のVMなどから、PaaSサービス（ストレージアカウント等）のFQDNに接続しようとしても、プライベートIPではなくパブリックIPが返ってきてしまう、または名前解決自体が失敗する。

### 診断Runbook

1.  **Private Endpoint の接続状態を確認する**
    - Private Endpoint自体のプロビジョニングと接続が `Approved` になっているか確認します。
    ```bash
    az network private-endpoint show -g <RG_NAME> -n <PE_NAME> --query "privateLinkServiceConnections[].privateLinkServiceConnectionState.status"
    ```

2.  **Private DNS Zone と VNet のリンクを確認する**
    - PaaSサービス用のPrivate DNS Zone（例: `privatelink.blob.core.windows.net`）が、VNetに正しくリンクされているか確認します。このリンクがないと、VNet内のDNSクエリがPrivate DNS Zoneに解決されません。
    ```bash
    az network private-dns link vnet list -g <RG_NAME> -z <PRIVATE_DNS_ZONE_NAME>
    ```

3.  **Private DNS Zone の A レコードを確認する**
    - Private DNS Zone内に、PaaSリソースのAレコードが自動的に作成され、Private EndpointのプライベートIPアドレスを指しているか確認します。
    ```bash
    az network private-dns record-set a list -g <RG_NAME> -z <PRIVATE_DNS_ZONE_NAME>
    ```

---

## パターン3: Log Analytics にログが表示されない

**症状**: 診断設定を構成したはずなのに、Log AnalyticsワークスペースでKQLクエリを実行しても、期待したログが表示されない。

### 診断Runbook

1.  **診断設定の内容を再確認する**
    - 対象リソースの診断設定で、`workspaceId` が正しいか、目的のログカテゴリ (`logs`) やメトリック (`metrics`) が `enabled: true` になっているかを正確に確認します。
    ```bash
    az monitor diagnostic-settings show --resource <RESOURCE_ID> --name <DIAGNOSTIC_SETTING_NAME>
    ```

2.  **ログの待ち時間**
    - ログが生成されてからLog Analyticsでクエリ可能になるまでには、数分のタイムラグが存在します。特に初回は時間がかかることがあります。少し待ってから再度クエリを実行してみてください。

3.  **KQLクエリとテーブル名を確認する**
    - クエリ対象のテーブル名が正しいか確認します。例えば、ストレージアカウントのBLOB操作ログは `StorageBlobLogs` テーブルに格納されます。`AzureDiagnostics` テーブルにしかない場合もあります。公式ドキュメントで、どのログがどのテーブルに格納されるかを確認しましょう。

---

## パターン4: リソースプロバイダーが未登録

**症状**: 新しい種類のリソース（例: `Microsoft.ContainerService` のAKSクラスタ）を作成しようとすると、`The subscription is not registered to use namespace 'Microsoft.SomeService'` のようなエラーで失敗する。

### 診断Runbook

1.  **プロバイダーの登録状態を確認する**
    - `az provider show` で、対象のプロバイダーの `registrationState` を確認します。
    ```bash
    az provider show -n Microsoft.ContainerService
    ```

2.  **プロバイダーを登録する**
    - `registrationState` が `NotRegistered` だった場合、`az provider register` で登録します。この登録処理は数分かかることがあります。
    ```bash
    az provider register --namespace Microsoft.ContainerService
    ```

---

## 最後のヒント: --debug と --verbose

`az` コマンドがなぜ失敗するのか、詳細な情報が必要な場合は、コマンドの末尾に `--debug` または `--verbose` フラグを付けて実行してみてください。これにより、Azure APIとの間の詳細なHTTPリクエスト/レスポンス情報が出力され、問題解決の強力な手がかりとなることがあります。

```bash
az vm create --name MyVM --resource-group MyRG ... --debug
```

これで、本書のすべての章が完了しました。お疲れ様でした！あなたはもう、Azure CLIを自在に操るクラウドエンジニアです。
