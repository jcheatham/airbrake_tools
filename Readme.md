Power tools for Airbrake

 - hottest errors
 - list / search errors

Install
=======

    gem install airbrake_tools

Usage
=====

    airbrake_tools your-account your-auth-token

Output
======

### Hot
```
airbrake_tools your-account your-auth-token hot
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
```
 airbrake_tools your-account your-auth-token list | grep 'is suspended'
 Page 1 ----------
 54054554 -- ActiveRecord::RecordInvalid -- ActiveRecord::RecordInvalid: Validation failed: Requester is suspended.
 Page 2 ----------
 ...
```

### Options

```
    -e, --environment ENV            Only show errors from this environment (default: production)
    -h, --help                       Show this.
    -v, --version                    Show Version
```
Author
======
[Jonathan Cheatham](http://github.com/jcheatham)<br/>
coaxis@gmail.com<br/>
License: MIT<br/>
[![Build Status](https://travis-ci.org/jcheatham/airbrake_tools.png)](https://travis-ci.org/jcheatham/airbrake_tools)
