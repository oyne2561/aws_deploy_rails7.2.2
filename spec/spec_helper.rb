# spec/spec_helper.rb
RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  # CI環境でデータベースを使用しない設定
  if ENV['SKIP_DB_SETUP'] == 'true'
    config.before(:suite) do
      # ActiveRecordの接続を無効化
      allow(ActiveRecord::Base).to receive(:establish_connection)
      allow(ActiveRecord::Base).to receive(:connected?).and_return(false)

      # マイグレーション関連をスキップ
      allow(ActiveRecord::Migration).to receive(:maintain_test_schema!)
    end
  end
end
