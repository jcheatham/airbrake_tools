Power tools for Airbrake

 - hottest errors
 - list / search errors
 - analyze 1 error (ocurrance graphs / different backtraces + frequencies)

Install
=======

    gem install airbrake_tools

Usage
=====

    airbrake-tools your-account your-auth-token

Output
======

### Hot

```
airbrake-tools your-account your-auth-token hot
.............................
#1     793.5/hour   2170:total ▁▂▂█
 --> id: 51344729 -- first: 2012-06-25 15:47:11 UTC -- Mysql2::Error -- Mysql2::Error: Lost connection to MySQL server at 'reading initial communication packet', system error: 110
#2     595.6/hour    648:total ▁▂▄█
 --> id: 53991244 -- first: 2012-12-13 20:31:26 UTC -- ActiveRecord::RecordInvalid -- ActiveRecord::RecordInvalid: Validation failed: Requester is suspended.
#3     458.0/hour 191840:total ▁▁▁▄█
 --> id: 53864752 -- first: 2012-12-06 19:57:12 UTC -- SyntaxError -- [retrying processing mail at 782bcb63887c.eml] SyntaxError: unterminated quoted-word
#4     315.3/hour   5184:total ▆▅▁▁▂▁▆▆█▅
 --> id: 52897649 -- first: 2012-10-14 02:10:41 UTC -- Http::ClientError -- [The server responded with status 500]
```

### List

Shows all errors divided by pages
 - search
 - "fix all errors on page x"

```
 airbrake-tools your-account your-auth-token list | grep 'is suspended'
 Page 1 ----------
 54054554 -- ActiveRecord::RecordInvalid -- ActiveRecord::RecordInvalid: Validation failed: Requester is suspended.
 Page 2 ----------
 ...
```

### Summary

 - show details for 1 error (combines 150 notices)
 - show all different traces that caused this error (play with --compare-depth)
 - shows blame for the line if it's in the project and you are running airrake-tools from the project root

```
airbrake-tools your-account your-auth-token summary 51344729
last retrieved notice: 1 hours ago at 2012-12-19 22:43:20 UTC
last 2 hours:  ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▂▂▂▅▃█
last day:      ▁
Trace 1: occurred 100 times e.g. 7145616660, 7145614849
Mysql2::Error: Lost connection to MySQL server at 'reading initial communication packet', system error
./mysql2/lib/mysql2/client.rb:44:in `connect'
...

Trace 2: occurred 10 times e.g. 7145613107, 7145612108
Mysql2::Error: Lost connection to MySQL server
/usr/gems/mysql2/lib/mysql2/client.rb:58:in `disconnect'
lib/foo.rb:58:in `bar' acc8204 (<jcheatham@example.com> 2012-11-06 18:45:10 -0800 )
...

Trace 3: occurred 5 times e.g. 7145609979, 7145609161
Mysql2::Error: Lost connection to MySQL server during reconnect
./mysql2/lib/mysql2/client.rb:78:in `reconnect'
...
```

### Options

```
-p, --pages NUM                  How maybe pages to iterate over (default: hot:1 summary:5)
-c, --compare-depth NUM          At what level to compare backtraces (default: 7)
-e, --environment ENV            Only show errors from this environment (default: production)
--project NAME                   Name of project to fetch errors for
-h, --help                       Show this.
-v, --version                    Show Version
```

Development
======
In order for the specs to run, you need to copy `spec/fixtures.example.yml` to
`spec/features.yml` and edit to add your credentials.

Author
======
[Jonathan Cheatham](http://github.com/jcheatham)<br/>
coaxis@gmail.com<br/>
License: MIT
