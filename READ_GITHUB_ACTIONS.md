## Github Actions CI/CDについて
`.github/workflows/ci.yml`ファイル

```yml
# ワークフローの名前を設定
name: CI/CD Pipeline

# このワークフローがいつ実行されるかを定義
on:
  push:
    branches: [ main, develop ]  # mainまたはdevelopブランチにプッシュされた時

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
        bundler-cache: true    # Bundlerのキャッシュを有効化

    # Step 3: コード品質チェック（RuboCop）
    - name: Run RuboCop (Lint)
      run: bundle exec rubocop

    # Step 4: テスト実行（RSpec）
    - name: Run RSpec tests
      env:
        RAILS_ENV: test
      run: bundle exec rspec spec/requests/api/v1/todos_spec.rb

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


# GitHub Actions CI/CDパイプライン詳細解説

## 概要

このドキュメントでは、RubyアプリケーションをAWSのECS（Elastic Container Service）にデプロイするGitHub Actions CI/CDパイプラインの詳細な流れを解説します。

## パイプラインの構成

### 1. トリガー設定

```yaml
on:
  push:
    branches: [ main, develop ]
```

**動作内容:**
- `main`または`develop`ブランチにコードがプッシュされた際にワークフローが自動実行されます
- プルリクエストやその他のイベントでは実行されません

### 2. 環境変数の定義

```yaml
env:
  AWS_REGION: ap-northeast-1
  ECR_REPOSITORY: todo-app-api
  ECS_SERVICE: todo-app-api-service
  ECS_CLUSTER: todo-app-api-cluster
  ECS_TASK_DEFINITION: todo-app-api-task
```

**役割:**
- 全てのジョブで共通して使用される設定値を定義
- AWSリソースの名前や地域を一元管理
- 設定変更時の修正箇所を最小限に抑制

## ジョブの詳細解説

### Job 1: Test（テスト実行）

#### 目的
コードの品質チェックとテスト実行により、問題のあるコードがデプロイされることを防ぎます。

#### 実行環境
- **OS**: Ubuntu最新版
- **Ruby**: 3.2.0

#### ステップ詳細

**Step 1: コードのチェックアウト**
```yaml
- name: Checkout code
  uses: actions/checkout@v4
```
- GitHubリポジトリからソースコードを仮想マシンにダウンロード
- 後続のステップでコードにアクセス可能になります

**Step 2: Ruby環境のセットアップ**
```yaml
- name: Set up Ruby
  uses: ruby/setup-ruby@v1
  with:
    ruby-version: 3.2.0
    bundler-cache: true
```
- Ruby 3.2.0をインストール
- Bundlerのキャッシュを有効化してgemのインストール時間を短縮
- `bundle install`が自動実行されます

**Step 3: コード品質チェック（RuboCop）**
```yaml
- name: Run RuboCop (Lint)
  run: bundle exec rubocop
```
- RuboCopを使用してコードスタイルと品質をチェック
- 設定ファイル（`.rubocop.yml`）に基づいて検証
- 違反があるとワークフローが失敗します

**Step 4: テスト実行（RSpec）**
```yaml
- name: Run RSpec tests
  env:
    RAILS_ENV: test
  run: bundle exec rspec spec/requests/api/v1/todos_spec.rb
```
- RSpecを使用してAPIのリクエストテストを実行
- テスト環境（`RAILS_ENV: test`）で実行
- 特定のテストファイル（`todos_spec.rb`）のみを対象

### Job 2: Deploy（デプロイ実行）

#### 実行条件
```yaml
needs: test
if: github.ref == 'refs/heads/main' && github.event_name == 'push'
```
- **依存関係**: `test`ジョブの成功が前提
- **ブランチ制限**: `main`ブランチへのプッシュのみ
- **イベント制限**: プッシュイベントのみ（プルリクエストは除外）

#### ステップ詳細

**Step 1: コードのチェックアウト**
```yaml
- name: Checkout code
  uses: actions/checkout@v4
```
- デプロイに必要なファイル（Dockerfileなど）にアクセスするため

**Step 2: AWS認証情報の設定**
```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: ${{ env.AWS_REGION }}
```
- AWSサービスにアクセスするための認証情報を設定
- GitHub Secretsから認証情報を安全に取得
- 東京リージョン（`ap-northeast-1`）を指定

**Step 3: Amazon ECRへのログイン**
```yaml
- name: Login to Amazon ECR
  id: login-ecr
  uses: aws-actions/amazon-ecr-login@v2
```
- ECR（Elastic Container Registry）にDockerイメージをプッシュするためのログイン
- レジストリURLが後続ステップで利用可能になります

**Step 4: Docker Imageのビルドとプッシュ**
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

**処理の詳細:**
1. **イメージビルド**: `Dockerfile.prod`を使用してDockerイメージを構築
2. **タグ付け**: GitコミットのSHA値をタグとして使用（一意性確保）
3. **ECRプッシュ**: 特定バージョンのイメージをプッシュ
4. **latestタグ**: 最新版として`latest`タグも付与してプッシュ
5. **出力設定**: 次のステップで使用するイメージURIを出力

**Step 5: ECSタスク定義のダウンロード**
```yaml
- name: Download task definition
  run: |
    aws ecs describe-task-definition --task-definition $ECS_TASK_DEFINITION \
      --query taskDefinition > task-definition.json
```
- 現在のECSタスク定義をJSONファイルとしてダウンロード
- 既存の設定を維持しながらイメージのみを更新するため

**Step 6: タスク定義の更新**
```yaml
- name: Fill in the new image ID in the Amazon ECS task definition
  id: task-def
  uses: aws-actions/amazon-ecs-render-task-definition@v1
  with:
    task-definition: task-definition.json
    container-name: todo-app-api
    image: ${{ steps.build-image.outputs.image }}
```
- タスク定義内の指定されたコンテナ（`oolab-api-api`）のイメージを新しいものに更新
- 他の設定（メモリ、CPU、環境変数など）は変更されません

**Step 7: ECSサービスへのデプロイ**
```yaml
- name: Deploy Amazon ECS task definition
  uses: aws-actions/amazon-ecs-deploy-task-definition@v1
  with:
    task-definition: ${{ steps.task-def.outputs.task-definition }}
    service: ${{ env.ECS_SERVICE }}
    cluster: ${{ env.ECS_CLUSTER }}
    wait-for-service-stability: true
```
- 更新されたタスク定義をECSサービスにデプロイ
- `wait-for-service-stability: true`により、デプロイが完了するまで待機
- ローリングアップデートが実行され、新しいコンテナが起動後、古いコンテナが停止

## パイプラインの流れ図

```
1. コードプッシュ (main/develop)
   ↓
2. Test Job 開始
   ├── コードチェックアウト
   ├── Ruby環境セットアップ
   ├── RuboCop実行
   └── RSpecテスト実行
   ↓
3. Test成功 && mainブランチ
   ↓
4. Deploy Job 開始
   ├── コードチェックアウト
   ├── AWS認証設定
   ├── ECRログイン
   ├── Dockerビルド&プッシュ
   ├── ECSタスク定義取得
   ├── タスク定義更新
   └── ECSデプロイ実行
   ↓
5. デプロイ完了
```

## セキュリティ考慮事項

### GitHub Secrets
以下の機密情報はGitHub Secretsで管理されています：
- `AWS_ACCESS_KEY_ID`: AWSアクセスキーID
- `AWS_SECRET_ACCESS_KEY`: AWSシークレットアクセスキー

### 権限管理
AWS IAMユーザーには以下の最小権限が必要です：
- ECR: イメージのプッシュ・プル権限
- ECS: タスク定義の読み取り・更新、サービスの更新権限

## トラブルシューティング

### よくある問題と対処法

**RuboCop違反でテストが失敗する場合:**
```bash
# ローカルでRuboCopを実行して修正
bundle exec rubocop --auto-correct
```

**RSpecテストが失敗する場合:**
```bash
# ローカルでテストを実行して確認
RAILS_ENV=test bundle exec rspec spec/requests/api/v1/todos_spec.rb
```

**AWS認証エラーの場合:**
- GitHub SecretsのAWS認証情報を確認
- IAMユーザーの権限設定を確認

**ECRプッシュエラーの場合:**
- ECRリポジトリが存在することを確認
- IAMユーザーにECR権限があることを確認

**ECSデプロイエラーの場合:**
- ECSクラスターとサービスが存在することを確認
- タスク定義内のコンテナ名が正しいことを確認

## まとめ

このCI/CDパイプラインにより、以下が自動化されます：

1. **品質保証**: コード品質チェックとテスト実行
2. **継続的デプロイ**: mainブランチへの安全な自動デプロイ
3. **インフラ管理**: Dockerイメージの管理とECSへのデプロイ
4. **ロールバック対応**: イメージタグによるバージョン管理

-----

# ピックアップ解説

# `$GITHUB_OUTPUT`の役割

## 基本的な仕組み

* GitHub Actionsが提供する**環境変数**
* ファイルパスを指している（実際のファイルに書き込む）
* このファイルに書き込んだ内容を、後続のステップで`outputs`として参照可能

## コード例での意味

```yaml
echo "image=$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG" >> $GITHUB_OUTPUT
```

この行は：
1. `image=レジストリURL/リポジトリ名:タグ`という形式の文字列を作成
2. `$GITHUB_OUTPUT`ファイルに追記
3. このステップの`outputs.image`として後続ステップから参照可能になる

## 実際の使用例

### Step 4（書き込み側）

```yaml
- name: Build, tag, and push image to Amazon ECR
  id: build-image  # ←このIDが重要！
  run: |
    # ... Docker処理 ...
    echo "image=$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG" >> $GITHUB_OUTPUT
```

### Step 6（参照側）

```yaml
- name: Fill in the new image ID in the Amazon ECS task definition
  uses: aws-actions/amazon-ecs-render-task-definition@v1
  with:
    image: ${{ steps.build-image.outputs.image }}  # ←ここで参照
```

## 具体的な値の例

**実際の処理内容：**

```bash
# 環境変数の値例
ECR_REGISTRY="123456789012.dkr.ecr.ap-northeast-1.amazonaws.com"
ECR_REPOSITORY="todo-app-api"
IMAGE_TAG="abc1234567890"  # GitコミットのSHA

# 実際に書き込まれる内容
echo "image=123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/todo-app-api:abc1234567890" >> $GITHUB_OUTPUT
```

**後続ステップでの参照：**

```yaml
image: "123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/todo-app-api:abc1234567890"
```

## なぜ必要なのか？

### 1. **動的な値の受け渡し**
* DockerイメージのURIはビルド時に動的に決まる
* GitコミットSHAは毎回異なる
* この動的な値を次のステップで使う必要がある

### 2. **処理の分離**
* イメージビルド処理とECSデプロイ処理を分離
* 各ステップが独立して動作しながら、必要な情報を共有

### 3. **再利用性**
* 同じイメージURIを複数の場所で使用可能
* コードの重複を避けられる

