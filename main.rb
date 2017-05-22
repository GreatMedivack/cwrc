require 'telegram/bot'
require 'ap'
token = ''

require 'sqlite3'

@db = SQLite3::Database.new 'database.db'

ITEMS = [:id, :title, :amount, :user_id, :in_report_list]

		RES_MSG = "Изменения на складе: \n"
		GET_MSG = "\t\t\nПолучено: \n"
		LOS_MSG = "\t\t\nПотеряно: \n"
		NOTHING_MSG = "Нет изменений \n"


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


		res_msg = ""
		get_res = ""
		los_res = ""


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


		# check stock

		stock.each do |item|
			db_item = get_item_amount(item, message.from.id)
			if db_item
				diff =  item[:amount] - db_item
				if diff == 0
					update_item_status(item, message.from.id)
				elsif diff > 0
					get_res += "\t\t\t\t#{item[:title]} +#{diff}\n"
					update_item(item, message.from.id)
				else
					los_res += "\t\t\t\t#{item[:title]} #{diff}\n"
					update_item(item, message.from.id)
				end
			else	
				get_res += "\t\t\t\t#{item[:title]} +#{item[:amount]}\n"
				insert_item(item, message.from.id)
			end

		end

		#check db
		items = @db.execute("select * from items where user_id=? and in_report_list=?",  message.from.id, 0)
		items.each do |item|
			h_item = get_hash(item, ITEMS)
			los_res += "#{h_item[:title]} -#{h_item[:amount]}\n" if h_item[:amount] != 0
			update_item({title: h_item[:title], amount: 0}, message.from.id)
		end

		res_msg += ( get_res != "" ? GET_MSG + get_res : "") + (los_res != "" ? LOS_MSG + los_res : "" )

		final_msg = res_msg == "" ? NOTHING_MSG : RES_MSG + res_msg

	    bot.api.send_message(chat_id: message.from.id, parse_mode: 'HTML' text: final_msg)
	    reset_statuses
	end
end