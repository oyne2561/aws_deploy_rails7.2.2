class Api::V1::TodosController < ApplicationController
  before_action :set_todo, only: [ :show, :update, :destroy, :toggle ]

  # GET /api/v1/todos
  def index
    @todos = Todo.all
    @todos = @todos.where(completed: true) if params[:status] == "completed"
    @todos = @todos.where(completed: false) if params[:status] == "pending"
    @todos = @todos.where(priority: params[:priority]) if params[:priority].present?
    @todos = @todos.order(:created_at)

    render json: @todos
  end

  # GET /api/v1/todos/:id
  def show
    render json: @todo
  end

  # POST /api/v1/todos
  def create
    @todo = Todo.new(todo_params)

    if @todo.save
      render json: @todo, status: :created
    else
      render json: { errors: @todo.errors }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/todos/:id
  def update
    if @todo.update(todo_params)
      render json: @todo
    else
      render json: { errors: @todo.errors }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/todos/:id
  def destroy
    @todo.destroy
    head :no_content
  end

  # PATCH /api/v1/todos/:id/toggle
  def toggle
    @todo.update(completed: !@todo.completed)
    render json: @todo
  end

  def new_action
    render json: {
      status: "ok",
      message: "Github Actions New Action Version 2!!"
    }, status: :ok
  end

  private

  def set_todo
    @todo = Todo.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Todo not found" }, status: :not_found
  end

  def todo_params
    params.require(:todo).permit(:title, :description, :priority, :completed, :due_date)
  end
end
