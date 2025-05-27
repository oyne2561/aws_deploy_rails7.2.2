require 'rails_helper'

RSpec.describe "Api::V1::Todos", type: :request do
  # ヘッダーを共通で定義
  let(:headers) { { 'Accept' => 'application/json', 'Content-Type' => 'application/json' } }

  let(:valid_attributes) do
    { title: "テストタスク", completed: false }
  end

  let(:invalid_attributes) do
    { title: "", completed: false }
  end

  # サンプルデータ（実際のDBレコードではなくハッシュ）
  let(:sample_todo) do
    {
      id: 1,
      title: "テストタスク",
      completed: false,
      created_at: Time.current,
      updated_at: Time.current
    }
  end

  let(:sample_completed_todo) do
    {
      id: 2,
      title: "完了済みタスク",
      completed: true,
      created_at: Time.current,
      updated_at: Time.current
    }
  end

  let(:sample_todos) { [ sample_todo, sample_completed_todo ] }
  let(:completed_todos) { [ sample_completed_todo ] }
  let(:pending_todos) { [ sample_todo ] }

  describe "GET /api/v1/todos" do
    context "全てのTODOを取得する場合" do
      before do
        # 完全なチェーンモックを作成
        filtered_todos = double
        ordered_todos = sample_todos

        allow(Todo).to receive(:all).and_return(filtered_todos)
        allow(filtered_todos).to receive(:where).and_return(filtered_todos)
        allow(filtered_todos).to receive(:order).with(:created_at).and_return(ordered_todos)

        # as_jsonメソッドを各todoに追加
        allow(ordered_todos).to receive(:as_json).and_return(sample_todos)
      end

      it "成功レスポンスを返す" do
        get "/api/v1/todos", headers: headers
        expect(response).to have_http_status(:ok)
      end

      it "TODOの配列を返す" do
        get "/api/v1/todos", headers: headers
        json = JSON.parse(response.body)
        expect(json).to be_an(Array)
        expect(json.length).to eq(2)
      end
    end

    context "完了済みTODOでフィルタする場合" do
      before do
        todos_all = double
        filtered_todos = double
        ordered_todos = completed_todos

        allow(Todo).to receive(:all).and_return(todos_all)
        allow(todos_all).to receive(:where).with(completed: true).and_return(filtered_todos)
        allow(filtered_todos).to receive(:where).and_return(filtered_todos)
        allow(filtered_todos).to receive(:order).with(:created_at).and_return(ordered_todos)
        allow(ordered_todos).to receive(:as_json).and_return(completed_todos)
      end

      it "完了済みTODOのみ返す" do
        get "/api/v1/todos", params: { status: "completed" }, headers: headers
        json = JSON.parse(response.body)
        expect(json.length).to eq(1)
        expect(json.first["completed"]).to be_truthy
      end
    end

    context "未完了TODOでフィルタする場合" do
      before do
        todos_all = double
        filtered_todos = double
        ordered_todos = pending_todos

        allow(Todo).to receive(:all).and_return(todos_all)
        allow(todos_all).to receive(:where).with(completed: false).and_return(filtered_todos)
        allow(filtered_todos).to receive(:where).and_return(filtered_todos)
        allow(filtered_todos).to receive(:order).with(:created_at).and_return(ordered_todos)
        allow(ordered_todos).to receive(:as_json).and_return(pending_todos)
      end

      it "未完了TODOのみ返す" do
        get "/api/v1/todos", params: { status: "pending" }, headers: headers
        json = JSON.parse(response.body)
        expect(json.length).to eq(1)
        expect(json.first["completed"]).to be_falsy
      end
    end
  end

  describe "GET /api/v1/todos/:id" do
    context "存在するTODOの場合" do
      before do
        todo_mock = double(sample_todo)
        allow(Todo).to receive(:find).with("1").and_return(todo_mock)
        allow(todo_mock).to receive(:as_json).and_return(sample_todo)
      end

      it "成功レスポンスを返す" do
        get "/api/v1/todos/1", headers: headers
        expect(response).to have_http_status(:ok)
      end

      it "正しいTODOを返す" do
        get "/api/v1/todos/1", headers: headers
        json = JSON.parse(response.body)
        expect(json["id"]).to eq(1)
        expect(json["title"]).to eq("テストタスク")
      end
    end

    context "存在しないTODOの場合" do
      before do
        allow(Todo).to receive(:find).with("999999").and_raise(ActiveRecord::RecordNotFound)
      end

      it "404エラーを返す" do
        get "/api/v1/todos/999999", headers: headers
        expect(response).to have_http_status(:not_found)
      end

      it "エラーメッセージを返す" do
        get "/api/v1/todos/999999", headers: headers
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Todo not found")
      end
    end
  end

  describe "POST /api/v1/todos" do
    context "有効なパラメータの場合" do
      before do
        new_todo = double
        allow(Todo).to receive(:new).with(ActionController::Parameters.new(valid_attributes).permit(:title, :description, :priority, :completed, :due_date)).and_return(new_todo)
        allow(new_todo).to receive(:save).and_return(true)
        allow(new_todo).to receive(:as_json).and_return(sample_todo)
      end

      it "作成されたTODOを返す" do
        post "/api/v1/todos", params: { todo: valid_attributes }.to_json, headers: headers
        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["title"]).to eq("テストタスク")
      end
    end

    context "無効なパラメータの場合" do
      before do
        invalid_todo = double
        errors_mock = double
        allow(Todo).to receive(:new).and_return(invalid_todo)
        allow(invalid_todo).to receive(:save).and_return(false)
        allow(invalid_todo).to receive(:errors).and_return(errors_mock)
        allow(errors_mock).to receive(:as_json).and_return([ "タイトルを入力してください" ])
      end

      it "422エラーを返す" do
        post "/api/v1/todos", params: { todo: invalid_attributes }.to_json, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "エラーメッセージを返す" do
        post "/api/v1/todos", params: { todo: invalid_attributes }.to_json, headers: headers
        json = JSON.parse(response.body)
        expect(json["errors"]).to be_present
      end
    end
  end

  describe "PATCH /api/v1/todos/:id" do
    context "有効なパラメータの場合" do
      before do
        todo_mock = double
        updated_data = sample_todo.merge(title: "更新されたタスク", completed: true)
        allow(Todo).to receive(:find).with("1").and_return(todo_mock)
        allow(todo_mock).to receive(:update).and_return(true)
        allow(todo_mock).to receive(:as_json).and_return(updated_data)
      end

      it "更新されたTODOを返す" do
        update_params = { title: "更新されたタスク", completed: true }
        patch "/api/v1/todos/1", params: { todo: update_params }.to_json, headers: headers
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["title"]).to eq("更新されたタスク")
      end
    end

    context "無効なパラメータの場合" do
      before do
        todo_mock = double
        errors_mock = double
        allow(Todo).to receive(:find).with("1").and_return(todo_mock)
        allow(todo_mock).to receive(:update).and_return(false)
        allow(todo_mock).to receive(:errors).and_return(errors_mock)
        allow(errors_mock).to receive(:as_json).and_return([ "タイトルを入力してください" ])
      end

      it "422エラーを返す" do
        patch "/api/v1/todos/1", params: { todo: invalid_attributes }.to_json, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "存在しないTODOの場合" do
      before do
        allow(Todo).to receive(:find).with("999999").and_raise(ActiveRecord::RecordNotFound)
      end

      it "404エラーを返す" do
        patch "/api/v1/todos/999999", params: { todo: valid_attributes }.to_json, headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /api/v1/todos/:id" do
    context "存在するTODOの場合" do
      before do
        todo_mock = double
        allow(Todo).to receive(:find).with("1").and_return(todo_mock)
        allow(todo_mock).to receive(:destroy).and_return(true)
      end

      it "204ステータスを返す" do
        delete "/api/v1/todos/1", headers: headers
        expect(response).to have_http_status(:no_content)
      end
    end

    context "存在しないTODOの場合" do
      before do
        allow(Todo).to receive(:find).with("999999").and_raise(ActiveRecord::RecordNotFound)
      end

      it "404エラーを返す" do
        delete "/api/v1/todos/999999", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH /api/v1/todos/:id/toggle" do
    context "存在するTODOの場合" do
      before do
        todo_mock = double
        toggled_data = sample_todo.merge(completed: true)
        allow(Todo).to receive(:find).with("1").and_return(todo_mock)
        allow(todo_mock).to receive(:completed).and_return(false)
        allow(todo_mock).to receive(:update).with(completed: true).and_return(true)
        allow(todo_mock).to receive(:as_json).and_return(toggled_data)
      end

      it "更新されたTODOを返す" do
        patch "/api/v1/todos/1/toggle", headers: headers
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["completed"]).to be_truthy
      end
    end

    context "存在しないTODOの場合" do
      before do
        allow(Todo).to receive(:find).with("999999").and_raise(ActiveRecord::RecordNotFound)
      end

      it "404エラーを返す" do
        patch "/api/v1/todos/999999/toggle", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
