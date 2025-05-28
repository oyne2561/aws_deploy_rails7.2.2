#!/bin/bash
set -e

# データベースの準備ができるまで待機
echo "Waiting for database to be ready..."
until bundle exec rails runner "ActiveRecord::Base.connection.execute('SELECT 1')" >/dev/null 2>&1; do
  echo "Database not ready, retrying in 2 seconds..."
  sleep 2
done

echo "Database is ready!"

# マイグレーションを実行
if [ "$RAILS_ENV" = "production" ]; then
  echo "Running database migrations..."
  bundle exec rails db:migrate

  echo "Running database seeds..."
  bundle exec rails db:seed
fi

echo "Starting application..."
# 渡されたコマンドを実行
exec "$@"