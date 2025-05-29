#!/bin/bash
set -e

echo ""
echo "=== 環境変数確認 ==="
echo "RAILS_ENV: $RAILS_ENV"
echo "DB_HOST: $DB_HOST"
echo "DB_PORT: $DB_PORT"
echo "DB_NAME: $DB_NAME"
echo "DB_USERNAME: $DB_USERNAME"
echo "DB_PASSWORD: $([ -n "$DB_PASSWORD" ] && echo '[設定済み]' || echo '[未設定]')"

echo ""
echo "=== 環境変数がRailsで利用可能か確認 ==="
bundle exec rails runner "
puts 'Environment variables in Rails:'
puts 'RAILS_ENV: ' + Rails.env
puts 'DB_HOST: ' + ENV['DB_HOST'].to_s
puts 'DB_PORT: ' + ENV['DB_PORT'].to_s
puts 'DB_NAME: ' + ENV['DB_NAME'].to_s
puts 'DB_USERNAME: ' + ENV['DB_USERNAME'].to_s
puts 'DB_PASSWORD: ' + (ENV['DB_PASSWORD'] ? '[SET]' : '[NOT SET]')
"

echo ""
echo "=== データベースマイグレーション実行 ==="
echo "マイグレーションを実行しています..."
bundle exec rails db:migrate

echo ""
echo "=== シードデータ投入 ==="
echo "シードデータを投入しています..."
bundle exec rails db:seed

echo "docker-entrypoint.shが読み込まれました。"

# exec "$@" により、CMD で指定されたコマンド（Rails サーバー）が実行されます。
# この記述がないと、初期化は成功するが Rails サーバーが起動せず、ヘルスチェックが失敗し続けます。
exec "$@"
