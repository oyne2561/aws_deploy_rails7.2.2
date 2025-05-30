Rails.application.routes.draw do
  # ヘルスチェック用エンドポイント
  get "/health", to: "health#check"

  root "health#check"

  namespace :api do
    namespace :v1 do
      resources :todos do
        member do
          patch :toggle
        end

        collection do
          get :new_action
        end
      end
    end
  end
end
