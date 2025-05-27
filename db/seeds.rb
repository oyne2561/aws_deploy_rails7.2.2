puts "シードデータの実行を開始します..."

# seed_dataフォルダ内のファイルを取得して実行
seed_files = Dir[Rails.root.join('db', 'seed_data', '*.rb')]

if seed_files.empty?
  puts "seed_dataフォルダにファイルが見つかりません"
else
  puts "#{seed_files.length}個のシードファイルを発見しました"

  for seed_file in seed_files
    file_name = File.basename(seed_file)
    puts "\n実行中: #{file_name}"

    begin
      load seed_file
      puts "✓ #{file_name} の実行が完了しました"
    rescue => e
      puts "✗ #{file_name} の実行中にエラーが発生しました: #{e.message}"
    end
  end
end

puts "\nシードデータの実行が完了しました"
