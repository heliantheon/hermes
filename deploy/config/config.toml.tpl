[app]
name = "Hermes"
version = "production"
debug = false

[log]
level = "info"
format = "json"

[server]
host = "0.0.0.0"
port = 18000

[db]
url = ""
enc-key = ""
slow-threshold = "200ms"

[db.pool]
max-idle-conns = 10
max-open-conns = 50
conn-max-lifetime = "1h"
conn-max-idle-time = "10m"

[aegis]
audience = "hermes"
issuer = "https://aegis.heliannuuthus.com/api"
secret-key = ""

[idp-defaults.github]
delegate = ""
require = ""

[idp-defaults.google]
delegate = ""
require = ""

