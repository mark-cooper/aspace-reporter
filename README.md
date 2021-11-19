# ASpace Reporter plugin

Generate some basic stats from ArchivesSpace and optionally
ship report data using the ASapce Messenger plugin.

```ruby
AppConfig[:plugins] << 'aspace-reporter'
# display report data in logs, will not send
AppConfig[:aspace_reporter_debug] = true
# midnight, once a day
AppConfig[:aspace_reporter_schedule] = '0 0 * * *'
# set url and debug to false to POST the report data
AppConfig[:aspace_reporter_secret_url] = nil
```
