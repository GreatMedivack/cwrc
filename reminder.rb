require 'telegram/bot'
require 'date'
require 'ap'
token = ''

require 'sqlite3'

@db = SQLite3::Database.new 'database.db'

critical_date = (Date.today - 5).strftime("%Y-%m-%d")

def get_users_ids (date)
	res = @db.execute "select cw_id, updated_at from users where updated_at = ? ", date
end


@users = get_users_ids critical_date



Telegram::Bot::Client.run(token) do |bot|
	@users.each do |user|
		bot.api.send_message(chat_id: 98141300, text: "Обнови профиль сейчас, а не то опять случится бида, когда в последний момент начнешь прятать ресы =(")
	end
end

