## 起動
```
docker compose up
```

```
docker compose exec api bash
```

## 環境構築
```
docker run --rm -v $(pwd):/app -w /app ruby:3.2.0 bash -c "
  apt-get update -qq &&
  apt-get install -y nodejs postgresql-client &&
  gem install rails -v 7.2.2 &&
  rails _7.2.2_ new . --api --database=postgresql --skip-git --force
"
```

```
touch docker-compose.yml
```
以下を記載。
```
services:
  db:
    image: postgres:15
    container_name: rails_postgres
    environment:
      POSTGRES_DB: myapp_development
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    networks:
      - app-network

  api:
    build: .
    container_name: rails_api
    command: bash -c "rm -f tmp/pids/server.pid && bundle exec rails server -b 0.0.0.0"
    volumes:
      - .:/app
      - bundle_cache:/usr/local/bundle
    ports:
      - "3000:3000"
    depends_on:
      - db
    environment:
      - DATABASE_URL=postgresql://postgres:password@db:5432/myapp_development
      - RAILS_ENV=development
    networks:
      - app-network
    stdin_open: true
    tty: true

volumes:
  postgres_data:
  bundle_cache:

networks:
  app-network:
    driver: bridge
```

```
docker compose up
```

```
docker compose exec api bash
```

```
bundle exec rails db:create
```

RSpecの初期化
```
bundle exec rails generate rspec:install
```

## コンテナ内で打つコマンド集
`bundle exec` をつけること

```ruby
bundle exec rails generate migration CreateTodos
# 編集後に以下を実行
bundle exec  rails db:migrate
```

bundle exec　rails generate controller api/v1/todos
bundle exec　rails generate serializer todo

コード検査
```
bundle exec　rubocop -A
```

シードデータ作成
```
bundle exec rails db:seed
```

## todoのエンドポイントをcurlで叩くためのコマンド集

```
# 1. 全TODOを取得 (GET /api/v1/todos)
curl -X GET http://localhost:3000/api/v1/todos

# 2. 完了済みTODOのみ取得
curl -X GET "http://localhost:3000/api/v1/todos?status=completed"

# 3. 未完了TODOのみ取得
curl -X GET "http://localhost:3000/api/v1/todos?status=pending"

# 4. 特定のTODOを取得 (GET /api/v1/todos/:id)
curl -X GET http://localhost:3000/api/v1/todos/1

# 5. 新しいTODOを作成 (POST /api/v1/todos)
curl -X POST http://localhost:3000/api/v1/todos \
  -H "Content-Type: application/json" \
  -d '{"todo": {"title": "新しいタスク", "completed": false}}'

# 6. TODOを更新 (PATCH /api/v1/todos/:id)
curl -X PATCH http://localhost:3000/api/v1/todos/1 \
  -H "Content-Type: application/json" \
  -d '{"todo": {"title": "更新されたタスク", "completed": true}}'

# 7. TODOの完了状態を切り替え (PATCH /api/v1/todos/:id/toggle)
curl -X PATCH http://localhost:3000/api/v1/todos/1/toggle

# 8. TODOを削除 (DELETE /api/v1/todos/:id)
curl -X DELETE http://localhost:3000/api/v1/todos/1

# レスポンスを見やすくするオプション
# -s: サイレントモード, -S: エラー時は表示, | jq: JSONを整形
curl -sSL http://localhost:3000/api/v1/todos | jq

# ヘルスチェックエンドポイントもテスト
curl -X GET http://localhost:3000/health
```

## テスト(RSpec)を叩くコマンド

### 警告を消すためのコマンド
```
bundle exec rails db:environment:set RAILS_ENV=test
```

### 特定のファイルを実行する場合

```
# 基本的なコマンド
bundle exec rspec spec/requests/api/v1/todos_spec.rb

# より詳細な出力で実行
bundle exec rspec spec/requests/api/v1/todos_spec.rb --format documentation

# 失敗時に詳細を表示
bundle exec rspec spec/requests/api/v1/todos_spec.rb --format documentation --backtrace
```

### 特定のテストケースのみ実行する場合

```
# 特定のdescribeブロックのみ実行
bundle exec rspec spec/requests/api/v1/todos_spec.rb -e "GET /api/v1/todos"

# 特定のcontextのみ実行
bundle exec rspec spec/requests/api/v1/todos_spec.rb -e "全てのTODOを取得する場合"

# 行番号を指定して実行（例：50行目のテスト）
bundle exec rspec spec/requests/api/v1/todos_spec.rb:55
```

## ECRに本番のDocker Imageを上げる手順

事前準備: マスターキーとシークレットキーベースを取得して、ssmに入力する
```
# 既存の暗号化ファイルを削除
rm config/credentials.yml.enc

# 新しい認証情報ファイルを作成（新しいmaster.keyも自動生成される）
EDITOR="vi" bundle exec rails credentials:edit

# シークレットキーベースを生成
bundle exec rails secret
```

```
aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin 0649363938393316.dkr.ecr.ap-northeast-1.amazonaws.com
```

```
docker build -f Dockerfile.prod -t todo-app-api .
```

```
docker tag todo-app-api:latest 0649363938393316.dkr.ecr.ap-northeast-1.amazonaws.com/todo-app-api:latest
docker push 0649363938393316.dkr.ecr.ap-northeast-1.amazonaws.com/todo-app-api:latest
```


## AWS Fargate時にはまったこと

### タスクのログでRailsコマンドが落ちる。
パラメーターストアの`RAILS_MASTER_KEY`と`SECRET_KEY_BASE`がダミーデータのままになっている。
変えたらうまく行く。

### マイグレーションまでできたがすぐにタスクが落ちる。
`docker-entrypoint.sh`
```
exec "$@"
```
exec "$@" により、CMD で指定されたコマンド（Rails サーバー）が実行されます。
この記述がないと、初期化は成功するが Rails サーバーが起動せず、ヘルスチェックが失敗し続けます。

### ヘルスチェックが落ちる。
ターゲットヘルス状態の確認

```
aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:ap-northeast-1:0325085075316:targetgroup/todo-app-api-tg/f0e3a0e95672a8ed
```

```
"TargetHealth": {
    "State": "unhealthy",
    "Reason": "Target.ResponseCodeMismatch",
    "Description": "Health checks failed with these codes: [301]"
},
```
HTTPステータス 301 = Permanent Redirect
Rails が /health への HTTP リクエストを HTTPS にリダイレクトしている可能性があります。

**解決の方法**
`production.rb`
以下二つを設定する。
```
# HTTPSを強制しない
config.force_ssl = false

# ALBがHTTPS終端を処理するため
config.assume_ssl = false
```