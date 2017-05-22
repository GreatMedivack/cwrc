require 'telegram/bot'
require 'ap'
token = ''

require 'sqlite3'

@db = SQLite3::Database.new 'database.db'

ITEMS = [:id, :title, :amount, :user_id, :in_report_list]


def insert_item(item, user_id)
	@db.execute "insert into items (title, amount, user_id, in_report_list) values ( ?, ?, ?, ? )", 
                                           	item[:title],
                                           	item[:amount], 
                                           	user_id,
                                           	1
end

def reset_statuses
	@db.execute "update items set in_report_list=?", 0
end

def get_hash(data, model)
	data ? model.map.with_index {|x, i| [x, data[i]]}.to_h : {}
end

def update_item(item, user_id)
	@db.execute "update items set amount=?, in_report_list=? where title=? and user_id=?",
											item[:amount], 
											1,
											item[:title],
											user_id
end

def update_item_status (item, user_id)
	@db.execute "update items set in_report_list=? where title=? and user_id=?",
											1,
											item[:title],
											user_id
end

def get_item_amount(item, user_id)
	@db.execute("select amount from items where title=? and user_id=?", item[:title], user_id).flatten.first
end



Telegram::Bot::Client.run(token) do |bot|
	bot.listen do |message|

		if message.text == "/start"
			msg = "Набери команду /stock в ChatWars и отправь форвард полученного сообщения этому боту"
	    	bot.api.send_message(chat_id: message.from.id, text: msg)
	    	next
	    end

	    if message.text == "/stock"
	    	next
	    end

	    next unless message.text =~ /Содержимое склада/

		stock = []
		message.text.each_line do |line|
			next if line =~ /Содержимое склада/
			title = line.slice(/[а-яА-Я ]+/).strip
			amount = line.slice(/\d+/).to_i
			stock << {title: title, amount: amount}
		end

		res_msg = "Изменения на складе: \n"

		# check stock

		stock.each do |item|
			db_item = get_item_amount(item, message.from.id)
			if db_item
				diff =  item[:amount] - db_item
				if diff == 0
					update_item_status(item, message.from.id)
				else
					res_msg += "#{item[:title]} #{diff}\n"
					update_item(item, message.from.id)
				end
			else	
				res_msg += "#{item[:title]} #{item[:amount]}\n"
				insert_item(item, message.from.id)
			end

		end

		#check db
		items = @db.execute("select * from items where user_id=? and in_report_list=?",  message.from.id, 0)
		items.each do |item|
			h_item = get_hash(item, ITEMS)
			res_msg += "#{h_item[:title]} -#{h_item[:amount]}\n" if h_item[:amount] != 0
			update_item({title: h_item[:title], amount: 0}, message.from.id)
		end

	    bot.api.send_message(chat_id: message.from.id, text: res_msg)
	    reset_statuses
	end
end