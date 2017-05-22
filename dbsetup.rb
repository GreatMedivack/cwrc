require 'sqlite3'

db = SQLite3::Database.new "database.db"

rows = db.execute <<-SQL
  create table items (
    ID INTEGER PRIMARY KEY AUTOINCREMENT,
    title varchar(250),
    amount integer,
    user_id integer,
    in_report_list boolean DEFAULT 0
  );
SQL


