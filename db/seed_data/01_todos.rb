todo_data = [
  { title: "買い物に行く", completed: false },
  { title: "メールを返信する", completed: true },
  { title: "プレゼンテーションを準備する", completed: false },
  { title: "ジムに行く", completed: true },
  { title: "本を読む", completed: false },
  { title: "友達と会う", completed: false },
  { title: "部屋を掃除する", completed: true },
  { title: "料理を作る", completed: false },
  { title: "映画を見る", completed: false },
  { title: "散歩する", completed: true }
]

puts "TODOデータを作成中..."
for data in todo_data
  todo = Todo.create!(data)
end

puts "#{Todo.count}件のTODOデータを作成しました"
