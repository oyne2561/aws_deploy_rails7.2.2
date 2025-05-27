Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :todos do
        member do
          patch :toggle
        end
      end
    end
  end

  # ヘルスチェック用エンドポイント
  get "/health", to: "health#check"
end
