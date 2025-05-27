class HealthController < ApplicationController
  def check
    render json: {
      status: "ok",
      message: "Health check endpoint accessed successfully"
    }, status: :ok
  end
end
