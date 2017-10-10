require 'sqlite3'

@db = SQLite3::Database.new 'database.db'
arr = [
"259969632;Гномик",
"306246267;Раввви",
"377267536;Равви твинк",
"98141300#;дмин",
"298568062;Кузя",
"387881985;Димас",
"318388551;Толстян",
"352073877;Курва",
"435159344;Толстян спойлер",
"370245828;Леня",
"238296233;lions heart King",
"112391353;lions heart queen"
]

arr.each do |line|
    pline =  line.split(';')
    cw_id = pline[0].to_i
    comment =  pline[1]
    @db.execute "insert into valid_users (cw_id, comment) values ( ?, ?)", cw_id, comment
end
