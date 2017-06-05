require 'telegram/bot'
require 'ap'
require 'date'
token = ''

require 'sqlite3'

@db = SQLite3::Database.new 'database.db'

ITEMS = [:id, :title, :amount, :user_id, :in_report_list]

		RES_MSG = "\u{1F4E5}<b>Изменения на складе:</b> \n"
		GET_MSG = "\t\t\n\u{1F53A}<b>Получено: </b>\n"
		LOS_MSG = "\t\t\n\u{1F53B}<b>Потеряно: </b>\n"
		NOTHING_MSG = "Нет изменений \n"
USERS = [:id, :name, :level, :class, :cw_id, :updated_at]

TRADE_BOT = 278525885
CW_BOT = 265204902
PROFILE_LIFE_TIME = 600

# Превый запуск

def user_initialize(user_id)
	user = @db.execute("select * from users where cw_id=?", user_id)
	if user == []
		@db.execute "insert into users (cw_id) values ( ? )", user_id
		user = @db.execute("select * from users where cw_id=?", user_id)
	else
	end
	get_hash(user.first, USERS)
end

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

def update_profile(msg, user)
	hero_name = hero_class = hero_level = 'unknown'
	msg.each_line do |line|
		if line =~ /замка/
			arr = line.split(',')
			hero_name = arr[0].slice(/[а-яА-Яa-zA-Z0-9\-\(\) ]{4,16}/)
			hero_class = arr[1].split().first
		elsif line =~ /Уровень/
			hero_level = line.slice(/\d+/)
		end
	end

	updated_at = Time.now.strftime("%Y-%m-%d")
	@db.execute "update users set name=?, level=?, class=?, updated_at=?  where id=?",
											hero_name, 
											hero_level,
											hero_class,
											updated_at,
											user[:id]
end

kb =  [	    ['Информация', 'Склад']	
	    #[Telegram::Bot::Types::KeyboardButton.new(text: 'Информация', one_time_keyboard: true)],
	    #[Telegram::Bot::Types::KeyboardButton.new(text: 'Склад', one_time_keyboard: true)]
	  ]
markup = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: kb, one_time_keyboard: false, resize_keyboard: true)

VALID_IDS = [ 	259969632,  # Гномик
	      		306246267,  # Раввви
	      		377267536,  # Равви твинк
   	      		98141300,   # Админ 
   	      		298568062,   # Кузя
			387881985 # Димас 
	    ]

Telegram::Bot::Client.run(token) do |bot|

	bot.listen do |message|

		res_msg = ""
		get_res = ""
		los_res = ""

	    unless VALID_IDS.include? message.from.id	
            bot.api.send_message(chat_id: 98141300, text: "#{message.from.id} \n#{message.text}")
	        next
        end

		if message.text == "/start"
			msg = "Набери команду /stock в @ChatWarsTradeBot и отправь форвард полученного сообщения этому боту"
	    	bot.api.send_message(chat_id: message.from.id, text: msg, reply_markup: markup)
	    	next
	    end

		user = user_initialize(message.from.id)

       	if message.text =~ /Битва семи замков через/
       		if message.forward_from.nil? || message.forward_date.nil? || message.forward_from.id != CW_BOT
	    		bot.api.send_message(chat_id: message.from.id, text: "Форвард не из @ChatWarsBot")
	    		next
       		elsif Time.now.to_i - message.forward_date > PROFILE_LIFE_TIME
	    		bot.api.send_message(chat_id: message.from.id, text: "Нужен профиль не старше 10 минут")
	    		next
       		end
	    	update_profile(message.text, user)
	    	bot.api.send_message(chat_id: message.from.id, text: "Профиль обновлен")
	    	next
	    end

        if Date.today - Date.parse(user[:updated_at]) > 5
	 		msg = "Твой профиль устарел. Набери /me в @ChatWarsBot и пришли форвард"
	    	bot.api.send_message(chat_id: message.from.id, text: msg)
	    	next
        end

	 	if message.text == "Информация"
	 		msg = "#{user[:cw_id]}\nИмя:\t<b>#{user[:name]}</b>\nКласс:\t#{user[:class]}\nУровень:\t#{user[:level]}"
	    	bot.api.send_message(chat_id: message.from.id, parse_mode: 'HTML', text: msg)
	 	end	
	 	
	 	if message.text == "Склад"
	 		items = @db.execute("select title, amount from items where user_id=? and amount>?",  user[:id], 0)
	    	stock = items.map {|item|  "\t\t\t\t\u{1F539}_#{item[0]}_  *x#{item[1]}*" }
	    	msg = stock.join("\n")
	    	msg = "Пусто" if msg.empty?
	    	bot.api.send_message(chat_id: message.from.id, parse_mode: 'Markdown', text: "\u{1F4DC}*Содержимое склада*\n#{msg}")
	 	end	

	    if message.text =~ /\/send_message/
	       	begin
	        	parse = message.text.split('*')
   	         	bot.api.send_message(chat_id: parse[1].to_i, text: parse[2])
			rescue
				bot.api.send_message(chat_id: 98141300, text: 'Не отправлено')
		 	 	next
			end
	    end

	    if message.text == "/stock"
	    	next
	    end

	    if message.text =~ /Твой склад с материалами/
       		if message.forward_from.nil? || message.forward_from.id != TRADE_BOT
	    		bot.api.send_message(chat_id: message.from.id, text: "Форвард не из @ChatWarsTradeBot")
       			next
       		end
	        bot.api.send_message(chat_id: 98141300, text: "#{user[:name]} отправил репорт!\n ")
			stock = []

			message.text.each_line do |line|
				break if line == "\n"
				next unless line =~ /^\/add_\d+ /
				title = line.slice(/[а-яА-Я][а-яА-Я 0-9]*[а-яА-Я]/).strip
				amount = line.slice(/ \d+/).to_i
				stock << {title: title, amount: amount}
			end

			# check stock

			stock.each do |item|
				db_item = get_item_amount(item, user[:id])
				if db_item
					diff =  item[:amount] - db_item
					if diff == 0
						update_item_status(item, user[:id])
					elsif diff > 0
						get_res += "\t\t\t\t#{item[:title]} +#{diff}\n"
						update_item(item, user[:id])
					else
						los_res += "\t\t\t\t#{item[:title]} #{diff}\n"
						update_item(item, user[:id])
					end
				else	
					get_res += "\t\t\t\t#{item[:title]} +#{item[:amount]}\n"
					insert_item(item, user[:id])
				end

			end

			#check db
			items = @db.execute("select * from items where user_id=? and in_report_list=?",  user[:id], 0)
			items.each do |item|
				h_item = get_hash(item, ITEMS)
				los_res += "\t\t\t\t#{h_item[:title]} -#{h_item[:amount]}\n" if h_item[:amount] != 0
				update_item({title: h_item[:title], amount: 0}, user[:id])
			end

			res_msg += ( get_res != "" ? GET_MSG + get_res : "") + (los_res != "" ? LOS_MSG + los_res : "" )

			final_msg = res_msg == "" ? NOTHING_MSG : RES_MSG + res_msg

		    bot.api.send_message(chat_id: message.from.id, parse_mode: 'HTML', text: final_msg)
		    reset_statuses
		end
	end
end
