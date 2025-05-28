FROM ruby:3.2.0

# 作業ディレクトリを設定
WORKDIR /app

# 必要なパッケージをインストール
RUN apt-get update -qq && \
    apt-get install -y \
    build-essential \
    libpq-dev \
    postgresql-client \
    nodejs \
    && rm -rf /var/lib/apt/lists/*

# Bundlerをインストール
RUN gem install bundler:2.4.22

# GemfileとGemfile.lockをコピー
COPY Gemfile ./

# Gemfile.lockがある場合はコピー（なくても大丈夫）
COPY Gemfile.lock* ./

# Gemをインストール
RUN bundle install

# アプリケーション全体をコピー
COPY . .

# ポート3000を公開
EXPOSE 3000

# Railsサーバーを起動
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
