require 'sqlite3'

db = SQLite3::Database.new "database.db"

rows = db.execute <<-SQL
  create table items (
    ID INTEGER PRIMARY KEY AUTOINCREMENT,
    title varchar(250),
    amount integer,
    user_id integer,
    in_report_list boolean DEFAULT 0,
    to_hide boolean DEFAULT 0
  );
SQL

rows = db.execute <<-SQL
  create table users (
    ID INTEGER PRIMARY KEY AUTOINCREMENT,
    name varchar(250) DEFAULT 'unknown',
    level integer DEFAULT 0,
    class varchar(250) DEFAULT 'unknown',
    cw_id integer
  );
SQL

rows = db.execute <<-SQL
  create table item_types (
    ID INTEGER PRIMARY KEY AUTOINCREMENT,
    title varchar(250),
    cw_id integer
  );
SQL
