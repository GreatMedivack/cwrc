require 'telegram/bot'
require 'date'
require 'ap'
token = ''
require 'sqlite3'

@db = SQLite3::Database.new 'database.db'

RES_MSG = "\u{1F4E5}<b>Изменения на складе:</b> \n"
GET_MSG = "\t\t\n\u{1F53A}<b>Получено: </b>\n"
LOS_MSG = "\t\t\n\u{1F53B}<b>Потеряно: </b>\n"
NOTHING_MSG = "Нет изменений \n"

ITEMS = [:id, :amount, :user_id, :item_type_id, :in_report_list]
GET_ITEM = [:amount, :title, :cw_id, :valuable]
GET_ITEMS = [:amount, :title, :item_type_id, :valuable]
GET_VALUABLE_ITEMS = [:cw_id, :amount, :title]
USERS = [:id, :name, :level, :class, :cw_id, :updated_at]

TRADE_BOT = 278525885
CW_BOT = 265204902
PROFILE_LIFE_TIME = 600
STOCK_LIFE_TIME = 60
ADMIN = 98141300
VALUABLE_ITEM = "\u{2B50}"
SIMPLE_ITEM = "\u{1F539}"
NOT_RESOURCE = "\u{1F458}"

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
	@db.execute "insert into items (item_type_id, amount, user_id, in_report_list) values ( ?, ?, ?, ? )",
                                           	item[:cw_id],
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
	@db.execute "update items set amount=?, in_report_list=? where item_type_id=? and user_id=?",
											item[:amount],
											1,
											item[:cw_id],
											user_id
end

# Работа с типами предметов

def get_item_name(cw_id)
	@db.execute("select title from item_types where cw_id=?", cw_id).flatten.first
end

def get_item_types_ids
	@db.execute("select cw_id from item_types").flatten
end

def add_item_type(title, cw_id)
	@db.execute "insert into item_types (title, cw_id, valuable) values ( ?, ?, ?)",
											title,
											cw_id,
											0
end

def update_item_status (item_type_id, user_id)
	@db.execute "update items set in_report_list=? where item_type_id=? and user_id=?",
											1,
											item_type_id,
											user_id
end

def get_item(item_type_id, user_id)
	data = @db.execute("select amount, item_types.title, item_type_id, item_types.valuable from items inner join item_types on items.item_type_id = item_types.cw_id where item_type_id=? and user_id=?", item_type_id, user_id).flatten
	data.empty? ? nil : GET_ITEM.map.with_index {|x, i| [x, data[i]]}.to_h
end

def get_valuable_resources(user_id)
	@db.execute("select items.item_type_id, items.amount, item_types.title from items inner join item_types on items.item_type_id = item_types.cw_id where items.user_id=? and item_types.valuable=? and items.amount > ?", user_id, 1, 0)
end

def create_res_hide_btns(items)
	buttons = []
	line = []
	items.each_with_index do |item, index|
		h_item = get_hash(item, GET_VALUABLE_ITEMS)
		line << Telegram::Bot::Types::InlineKeyboardButton.new( text: "#{h_item[:title]} x#{h_item[:amount]}",
																switch_inline_query: "/wts_#{h_item[:cw_id]}_#{h_item[:amount]}_1000")
		if (index + 1) % 3 == 0
				buttons << line
				line = []
		end
	end
	buttons << line
	markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: buttons)
end

def update_profile(msg, user)
	hero_name = hero_class = hero_level = 'unknown'
	msg.each_line do |line|
		if line =~ /, [А-Я][а-я]+ [А-Я][а-я]+ замка/
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

def share_stock
	@db.execute "select item_types.cw_id, item_types.title, sum(amount), item_types.valuable from items inner join item_types on items.item_type_id = item_types.cw_id where amount > 0 group by item_type_id order by item_types.valuable desc"
end

def valid_user?(id)
	valid_users = @db.execute("select cw_id from valid_users").flatten
	valid_users.include?(id)
end

def add_user_to_validlist(id)
	@db.execute("insert into valid_users (cw_id) values ( ? )", id) unless valid_user?(id)
end

kb =  [['Информация', 'Склад'], ['Спрятать ресурсы', 'Общий склад']]
markup = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: kb, one_time_keyboard: false, resize_keyboard: true)


Telegram::Bot::Client.run(token) do |bot|

	bot.listen do |message|
		user = user_initialize(message.from.id)

		case message
		  when Telegram::Bot::Types::CallbackQuery

		  when Telegram::Bot::Types::InlineQuery
		  		if message.query =~ /wts_\d+_\d+_1000/
		  			data = message.query.split('_')
		  			title =  get_item_name(data[1])
		  			results = [
		  				[1, "Спрятать #{title} x#{data[2]}", "/wts_#{data[1]}_#{data[2]}_1000"]
		  			].map do |arr|
				      Telegram::Bot::Types::InlineQueryResultArticle.new(
				        id: arr[0],
				        title: arr[1],
				        input_message_content: Telegram::Bot::Types::InputTextMessageContent.new(message_text: arr[2])
				      )
				    end
					bot.api.answer_inline_query(inline_query_id: message.id, results: results)
				end
		  when Telegram::Bot::Types::Message
				res_msg = ""
				get_res = ""
				los_res = ""

		    unless valid_user? message.from.id
	          bot.api.send_message(chat_id: 98141300, text: "#{message.from.id} \n#{message.text}\n\/adduser_#{message.from.id}")
		        next
	       end

				if message.text == "/start"
					msg = "Набери команду /stock в @ChatWarsTradeBot и отправь форвард полученного сообщения этому боту"
		    	bot.api.send_message(chat_id: message.from.id, text: msg, reply_markup: markup)
		    	next
		    end

		    if message.text == 'Спрятать ресурсы'
			    bot.api.send_message(chat_id: message.chat.id, text: 'Выбери ресурс', reply_markup: create_res_hide_btns(get_valuable_resources(user[:id])))
		    end

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
			 		items = @db.execute("select item_types.title, amount, item_types.valuable from items inner join item_types on items.item_type_id = item_types.cw_id where user_id=? and amount>? order by item_types.valuable desc",  user[:id], 0)
			    	stock = items.map {|item|  "\t\t\t\t #{item[2] == 1 ? VALUABLE_ITEM : SIMPLE_ITEM}_#{item[0]}_  *x#{item[1]}*" }
			    	msg = stock.join("\n")
			    	msg = "Пусто" if msg.empty?
			    	bot.api.send_message(chat_id: message.from.id, parse_mode: 'Markdown', text: "\u{1F4DC}*Содержимое склада*\n#{msg}")
			 	end

			 	if message.text == 'Общий склад'
			 		items = share_stock
					puts items
			 		stock = items.map {|item|  "\t\t\t\t #{item[3] == 1 ? VALUABLE_ITEM : (item[0] / 1000 > 0) ? NOT_RESOURCE : SIMPLE_ITEM}_#{item[1]}_  *x#{item[2]}*" }
			    	msg = stock.join("\n")
			    	msg = "Пусто" if msg.empty?
			    	bot.api.send_message(chat_id: message.from.id, parse_mode: 'Markdown', text: "\u{1F4DC}*Содержимое всех складов*\n#{msg}")
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

		    if message.text =~ /\/adduser_\d+/ && message.from.id == ADMIN
			user_id = message.text.split('_').last.to_i
			add_user_to_validlist(user_id)
			next
		    end

		    #Основной говнокод

		    if message.text =~ /Твой склад с материалами/
	      	if message.forward_from.nil? || message.forward_from.id != TRADE_BOT
		    		bot.api.send_message(chat_id: message.from.id, text: "Форвард не из @ChatWarsTradeBot")
	       		next
					elsif Time.now.to_i - message.forward_date > STOCK_LIFE_TIME
						bot.api.send_message(chat_id: message.from.id, text: "Нужен форвард не старше 1 минуты")
						next
	       	end
	        bot.api.send_message(chat_id: 98141300, text: "#{user[:name]} отправил репорт!\n ")
					stock = []

					cw_ids = get_item_types_ids

					message.text.each_line do |line|
						break if line == "\n"
						next unless line =~ /^\/add_\d+ /
						cw_id = line.slice(/^\/add_\d+ /).slice(/\d+/).to_i
						title = line.slice(/[а-яА-Я][а-яА-Я 0-9]*[а-яА-Я]/).strip
						unless cw_ids.include?(cw_id)
							add_item_type(title, cw_id)
							cw_ids << cw_id
						end
						amount = line.slice(/ \d+/).to_i
						stock << {cw_id: cw_id, amount: amount}
					end

					# check stock
					stock.each do |item|
						db_item = get_item(item[:cw_id], user[:id])
						if db_item
							diff = item[:amount] - db_item[:amount]
							if diff == 0
								update_item_status(item[:cw_id], user[:id])
							elsif diff > 0
								get_res += "\t\t\t\t#{db_item[:valuable] == 1 ? VALUABLE_ITEM : SIMPLE_ITEM }#{db_item[:title]} +#{diff}\n"
								update_item(item, user[:id])
							else
								los_res += "\t\t\t\t#{db_item[:valuable] == 1 ? VALUABLE_ITEM : SIMPLE_ITEM }#{db_item[:title]} #{diff}\n"
								update_item(item, user[:id])
							end
						else
							insert_item(item, user[:id])
							db_item = get_item(item[:cw_id], user[:id])
							get_res += "\t\t\t\t#{db_item[:valuable] == 1 ? VALUABLE_ITEM : SIMPLE_ITEM}#{db_item[:title]} +#{db_item[:amount]}\n"
						end
					end

					#check db
					items = @db.execute("select amount, item_types.title, item_type_id, item_types.valuable from items inner join item_types on items.item_type_id = item_types.cw_id where user_id=? and in_report_list=?",  user[:id], 0)
					items.each do |item|
						h_item = get_hash(item, GET_ITEMS)
						los_res += "\t\t\t\t#{h_item[:valuable] == 1 ? VALUABLE_ITEM : SIMPLE_ITEM }#{h_item[:title]} -#{h_item[:amount]}\n" if h_item[:amount] != 0
						update_item({cw_id: h_item[:item_type_id], amount: 0}, user[:id])
					end

					res_msg += ( get_res != "" ? GET_MSG + get_res : "") + (los_res != "" ? LOS_MSG + los_res : "" )

					final_msg = res_msg == "" ? NOTHING_MSG : RES_MSG + res_msg

				  bot.api.send_message(chat_id: message.from.id, parse_mode: 'HTML', text: final_msg)
				  reset_statuses
				end
		 end
	end
end
