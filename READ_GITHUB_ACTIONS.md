## Github Actions CI/CDについて
`.github/workflows/ci.yml`ファイル

```yml
# ワークフローの名前を設定
name: CI/CD Pipeline

# このワークフローがいつ実行されるかを定義
on:
  push:
    # 絶対に実行されないトリガーを設定し、Github Actionsが走らないようにしている。また走らせたいときはは切り替える。
    branches: [ "non-existent-branch-never-created" ]
  #   branches: [ main, develop ]  # mainまたはdevelopブランチにプッシュされた時

# 環境変数の定義（全てのジョブで使用可能）
env:
  AWS_REGION: ap-northeast-1                 # AWSリージョン（東京）
  ECR_REPOSITORY: todo-app-api               # ECR（Docker画像保存場所）のリポジトリ名
  ECS_SERVICE: todo-app-api-service          # ECS（コンテナ実行環境）のサービス名
  ECS_CLUSTER: todo-app-api-cluster          # ECSクラスター名
  ECS_TASK_DEFINITION: todo-app-api-task     # ECSタスク定義名

# ジョブの定義（並列または順次実行される処理の単位）
jobs:
  # 1つ目のジョブ：テスト実行
  test:
    runs-on: ubuntu-latest  # Ubuntu最新版の仮想マシンで実行

    # ステップの定義（順次実行される処理）
    steps:
    # Step 1: ソースコードをチェックアウト（取得）
    - name: Checkout code
      uses: actions/checkout@v4

    # Step 2: Ruby環境のセットアップ
    - name: Set up Ruby
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: 3.2.0    # Ruby 3.2.0を使用
        bundler-cache: true   # キャッシュを無効化して手動でbundle install

    # Step 3: コード品質チェック（RuboCop）
    - name: Run RuboCop (Lint)
      run: bundle exec rubocop

  # 2つ目のジョブ：デプロイ実行
  deploy:
    needs: test  # testジョブが成功した場合のみ実行
    runs-on: ubuntu-latest
    # mainブランチへのプッシュの場合のみ実行
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'

    steps:
    # Step 1: ソースコードをチェックアウト
    - name: Checkout code
      uses: actions/checkout@v4

    # Step 2: AWS認証情報の設定
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}     
        aws-region: ${{ env.AWS_REGION }}

    # Step 3: Amazon ECRにログイン
    - name: Login to Amazon ECR
      id: login-ecr
      uses: aws-actions/amazon-ecr-login@v2

    # Step 4: Docker ImageをビルドしてECRにプッシュ
    - name: Build, tag, and push image to Amazon ECR
      id: build-image
      env:
        ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
        IMAGE_TAG: ${{ github.sha }}  # GitコミットのSHAをタグとして使用
      run: |
        # Docker画像をビルドしてECRにプッシュ
        docker build -f Dockerfile.prod -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
        docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
        # latestタグも付けてプッシュ
        docker tag $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY:latest
        docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest
        # 次のステップで使用するため、画像URIを出力
        echo "image=$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG" >> $GITHUB_OUTPUT

    # Step 5: 現在のECSタスク定義をダウンロード
    - name: Download task definition
      run: |
        aws ecs describe-task-definition --task-definition $ECS_TASK_DEFINITION \
          --query taskDefinition > task-definition.json
    
    # Step 5.5: タスク定義のアーキテクチャをX86_64に修正
    - name: Fix task definition architecture
      run: |
        # JSONファイルでcpuArchitectureをX86_64に変更
        jq '.runtimePlatform.cpuArchitecture = "X86_64"' task-definition.json > task-definition-fixed.json
        # 修正されたファイルに置き換え
        mv task-definition-fixed.json task-definition.json
        
        # 確認のため修正内容を表示
        echo "=== 修正されたruntimePlatform ==="
        jq '.runtimePlatform' task-definition.json

    # Step 6: タスク定義に新しいDocker Imageを設定
    - name: Fill in the new image ID in the Amazon ECS task definition
      id: task-def
      uses: aws-actions/amazon-ecs-render-task-definition@v1
      with:
        task-definition: task-definition.json
        container-name: todo-app-api
        image: ${{ steps.build-image.outputs.image }}

    # Step 7: ECSサービスに新しいタスク定義をデプロイ
    - name: Deploy Amazon ECS task definition
      uses: aws-actions/amazon-ecs-deploy-task-definition@v1
      with:
        task-definition: ${{ steps.task-def.outputs.task-definition }}
        service: ${{ env.ECS_SERVICE }}
        cluster: ${{ env.ECS_CLUSTER }}
        wait-for-service-stability: true  # サービスが安定するまで待機
```


# GitHub Actions CI/CDパイプライン解説

## 概要

このGitHub Actionsワークフローは、RubyアプリケーションのCI/CD（継続的インテグレーション・継続的デプロイメント）パイプラインを定義しています。コードのテストからAWS ECSへのデプロイまでを自動化します。

## ワークフローの基本設定

### ワークフロー名
```yaml
name: CI/CD Pipeline
```
GitHub Actionsのダッシュボードで表示される名前を定義します。

### トリガー設定
```yaml
on:
  push:
    branches: [ "non-existent-branch-never-created" ]
```

**現在の状態**: 存在しないブランチ名が設定されているため、**このワークフローは実行されません**。

**実際に使用する場合**:
```yaml
on:
  push:
    branches: [ main, develop ]
```
mainまたはdevelopブランチにプッシュされた時に実行されます。

## 環境変数

```yaml
env:
  AWS_REGION: ap-northeast-1
  ECR_REPOSITORY: todo-app-api
  ECS_SERVICE: todo-app-api-service
  ECS_CLUSTER: todo-app-api-cluster
  ECS_TASK_DEFINITION: todo-app-api-task
```

全てのジョブで共通して使用される設定値を定義:
- **AWS_REGION**: 東京リージョン（ap-northeast-1）
- **ECR_REPOSITORY**: Dockerイメージを保存するリポジトリ名
- **ECS_SERVICE**: コンテナサービス名
- **ECS_CLUSTER**: ECSクラスター名
- **ECS_TASK_DEFINITION**: タスク定義名

## ジョブ1: テスト実行（test）

### 実行環境
```yaml
runs-on: ubuntu-latest
```
Ubuntu最新版の仮想マシンで実行されます。

### テストの流れ

#### Step 1: ソースコード取得
```yaml
- name: Checkout code
  uses: actions/checkout@v4
```
GitHubリポジトリからソースコードをダウンロードします。

#### Step 2: Ruby環境セットアップ
```yaml
- name: Set up Ruby
  uses: ruby/setup-ruby@v1
  with:
    ruby-version: 3.2.0
    bundler-cache: true
```
- Ruby 3.2.0をインストール
- `bundler-cache: true`でGemの依存関係をキャッシュし、高速化

#### Step 3: コード品質チェック
```yaml
- name: Run RuboCop (Lint)
  run: bundle exec rubocop
```
RuboCopを使用してRubyコードの品質をチェックします。コーディング規約違反があるとここで失敗します。

## ジョブ2: デプロイ実行（deploy）

### 実行条件
```yaml
needs: test
if: github.ref == 'refs/heads/main' && github.event_name == 'push'
```
- testジョブが成功した場合のみ実行
- mainブランチへのプッシュの場合のみ実行

### デプロイの流れ

#### Step 1: ソースコード取得
testジョブと同様にソースコードを取得します。

#### Step 2: AWS認証設定
```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: ${{ env.AWS_REGION }}
```
GitHubのSecretsに保存されたAWS認証情報を使用してAWSにアクセスできるように設定します。

#### Step 3: ECRログイン
```yaml
- name: Login to Amazon ECR
  id: login-ecr
  uses: aws-actions/amazon-ecr-login@v2
```
Amazon ECR（Elastic Container Registry）にログインし、Dockerイメージをプッシュできるようにします。

#### Step 4: Dockerイメージのビルドとプッシュ
```yaml
- name: Build, tag, and push image to Amazon ECR
  id: build-image
  env:
    ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
    IMAGE_TAG: ${{ github.sha }}
  run: |
    docker build -f Dockerfile.prod -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
    docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
    docker tag $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY:latest
    docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest
    echo "image=$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG" >> $GITHUB_OUTPUT
```

**処理内容**:
1. `Dockerfile.prod`を使用してDockerイメージをビルド
2. GitコミットのSHA値をタグとして使用
3. ECRにイメージをプッシュ
4. `latest`タグも同時に作成・プッシュ
5. 次のステップで使用するため、イメージURIを出力

#### Step 5: 現在のECSタスク定義取得
```yaml
- name: Download task definition
  run: |
    aws ecs describe-task-definition --task-definition $ECS_TASK_DEFINITION \
      --query taskDefinition > task-definition.json
```
現在デプロイされているECSタスク定義をJSONファイルとしてダウンロードします。

#### Step 5.5: アーキテクチャ修正
```yaml
- name: Fix task definition architecture
  run: |
    jq '.runtimePlatform.cpuArchitecture = "X86_64"' task-definition.json > task-definition-fixed.json
    mv task-definition-fixed.json task-definition.json
    echo "=== 修正されたruntimePlatform ==="
    jq '.runtimePlatform' task-definition.json
```
タスク定義のCPUアーキテクチャをX86_64に明示的に設定します。これはプラットフォーム互換性を確保するためです。

#### Step 6: 新しいイメージでタスク定義更新
```yaml
- name: Fill in the new image ID in the Amazon ECS task definition
  id: task-def
  uses: aws-actions/amazon-ecs-render-task-definition@v1
  with:
    task-definition: task-definition.json
    container-name: todo-app-api
    image: ${{ steps.build-image.outputs.image }}
```
ダウンロードしたタスク定義の`todo-app-api`コンテナのイメージを新しくビルドしたイメージに置き換えます。

#### Step 7: ECSサービスへのデプロイ
```yaml
- name: Deploy Amazon ECS task definition
  uses: aws-actions/amazon-ecs-deploy-task-definition@v1
  with:
    task-definition: ${{ steps.task-def.outputs.task-definition }}
    service: ${{ env.ECS_SERVICE }}
    cluster: ${{ env.ECS_CLUSTER }}
    wait-for-service-stability: true
```
更新されたタスク定義をECSサービスにデプロイし、サービスが安定するまで待機します。

## 必要な事前設定

### GitHubリポジトリのSecrets設定
以下の値をGitHubリポジトリの Settings > Secrets and variables > Actions で設定する必要があります：

- `AWS_ACCESS_KEY_ID`: AWSアクセスキーID
- `AWS_SECRET_ACCESS_KEY`: AWSシークレットアクセスキー

### AWSリソースの準備
- ECRリポジトリ: `todo-app-api`
- ECSクラスター: `todo-app-api-cluster`
- ECSサービス: `todo-app-api-service`
- ECSタスク定義: `todo-app-api-task`（コンテナ名: `todo-app-api`）

### プロジェクトファイル
- `Dockerfile.prod`: 本番用のDockerfile
- `Gemfile`: Ruby依存関係の定義
- `.rubocop.yml`: RuboCopの設定ファイル（推奨）

## ワークフローを有効にする方法

現在のワークフローは無効化されています。有効にするには：

```yaml
on:
  push:
    branches: [ main, develop ]  # コメントアウトを解除
    # branches: [ "non-existent-branch-never-created" ]  # この行をコメントアウト
```

## セキュリティのベストプラクティス

1. **IAMロールの最小権限**: AWSアクセスキーには必要最小限の権限のみを付与
2. **Secrets管理**: 機密情報は必ずGitHub Secretsを使用
3. **イメージスキャン**: ECRでイメージの脆弱性スキャンを有効化
4. **ブランチ保護**: mainブランチに直接プッシュを制限し、プルリクエスト経由でのマージを必須化

## トラブルシューティング

### よくある問題

1. **AWS認証エラー**: Secretsの設定を確認
2. **RuboCop失敗**: コードスタイルの修正が必要
3. **Docker ビルド失敗**: `Dockerfile.prod`の存在と内容を確認
4. **ECSデプロイ失敗**: AWSリソースの存在とIAM権限を確認

### ログの確認方法
GitHub ActionsのJobsタブで各ステップの詳細ログを確認できます。エラーが発生した場合は、該当ステップの詳細ログを確認してください。