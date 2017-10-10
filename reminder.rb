require 'telegram/bot'
require 'date'
require 'ap'
token = '137469619:AAF6IlU6hHJEXNy6IcJDtK9lEqy1AwXDkrM'

require 'sqlite3'

@db = SQLite3::Database.new '/home/softs/appserver/cwrc/database.db'

critical_date = (Date.today - 4).strftime("%Y-%m-%d")

def get_users_ids (date)
	res = @db.execute "select cw_id, updated_at from users where updated_at = ? ", date
end


@users = get_users_ids critical_date



Telegram::Bot::Client.run(token) do |bot|
	@users.each do |user|
		bot.api.send_message(chat_id: user[0], text: "Обнови профиль сейчас, а не то опять случится бида, когда в последний момент начнешь прятать ресы =(")
	end
end

