# ワーカー数とスレッド数の設定
workers Integer(ENV.fetch("WEB_CONCURRENCY", 2))
max_threads_count = ENV.fetch("RAILS_MAX_THREADS", 5)
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

# ワーカータイムアウト
worker_timeout 3600 if ENV.fetch("RAILS_ENV", "development") == "development"

# アプリケーションのプリロード
preload_app!

# ポートとバインド
port ENV.fetch("PORT", 3000)
environment ENV.fetch("RAILS_ENV", "development")

# ワーカー起動時の処理
on_worker_boot do
  # ワーカー固有の設定（Rails 4.1+）
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
end

# フォーク前の処理
before_fork do
  ActiveRecord::Base.connection_pool.disconnect! if defined?(ActiveRecord)
end

# プロセス名を設定
tag 'oolab-api'

# PIDファイルの場所
pidfile ENV.fetch("PIDFILE", "tmp/pids/server.pid")

# プラグイン
plugin :tmp_restart

# SSL設定（本番環境用 - 必要に応じて）
# ssl_bind '0.0.0.0', '9292', {
#   key: path_to_key,
#   cert: path_to_cert
# }
