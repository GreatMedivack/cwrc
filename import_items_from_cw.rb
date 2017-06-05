require 'sqlite3'

@db = SQLite3::Database.new 'database.db'

File.open("items_base", "r") do |f|
  f.each_line do |line|
    pline =  line.split(';')
    cw_id = pline[0].slice(/\d+/).to_i
    title =  pline[1]
    valuable = pline[2].slice(/\d/).to_i
    @db.execute "insert into item_types (title, cw_id, valuable) values ( ?, ?, ?)",
    																	title,
    																	cw_id,
    																	valuable
  end
end
