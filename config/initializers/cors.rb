Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    if Rails.env.development?
      origins "*"
    else
      # 本番環境では特定のオリジンのみ許可
      origins ENV["ALLOWED_ORIGINS"]&.split(",") || [ "https://your-frontend-domain.com" ]
    end

    resource "*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      credentials: false
  end
end
