require 'sqlite3'

db = SQLite3::Database.new "database.db"

rows = db.execute <<-SQL
  create table items (
    ID INTEGER PRIMARY KEY AUTOINCREMENT,
    amount integer,
    user_id integer,
    in_report_list boolean DEFAULT 0,
    item_type_id integer
  );
SQL

rows = db.execute <<-SQL
  create table users (
    ID INTEGER PRIMARY KEY AUTOINCREMENT,
    name varchar(250) DEFAULT 'unknown',
    level integer DEFAULT 0,
    class varchar(250) DEFAULT 'unknown',
    cw_id integer,
    updated_at date DEFAULT '1970-01-01'
  );
SQL

rows = db.execute <<-SQL
  create table item_types (
    ID INTEGER PRIMARY KEY AUTOINCREMENT,
    title varchar(250),
    cw_id integer,
    valuable boolean
  );
SQL


rows = db.execute <<-SQL
  create table valid_users (
    ID INTEGER PRIMARY KEY AUTOINCREMENT,
    cw_id integer,
    comment varchar(250)
  );
SQL
