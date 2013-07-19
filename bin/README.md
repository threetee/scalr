# ttmscalr - a command-line tool for working with Scalr

## Configuring

You need to tell Scalr your API credentials. Don't have these? Go get
them -- Andre can create an account for you, and once you login click on
your profile in the upper-right and choose 'API Access'.

You can tell Scalr your credentials in one of two ways:

__1.__ Export data to your environment. Both of the following must be
defined:

* `SCALR_KEY_ID`
* `SCALR_ACCESS_KEY`

__2.__ Create one of the following files with access credentials:

* `access_info` in the directory where the Scalr gem is stored
* `~/.ttm_scalr_access_info` <<< preferred!
* `access_info` in the current directory

(More specific files will be preferred over least specific.)

The Scalr access credentials should be in the file like this:

    KEY_ID     = 46ab...
    ACCESS_KEY = nxm+4hN...

DO NOT ADD THIS FILE TO git! It's already in `.gitignore` so you
shouldn't be able to do so accidentally in the scalr gem.

## Scalr commands

### Scalr background

There are some fundamental differences between Scalr and
Heroku. Heroku has a simple, flat model of
dyno-per-Procfile-entry. Scalr has multiple abstraction layers to let
you copy your app, restart parts of it without others being touched,
and so on.

The layers are:

* Farm
* Role
* Server

A __farm__ may contain multiple __roles__, each of which corresponds
roughly to a Procfile entry. Each __role__ within a __farm__ has its
own scaling algorithm (grow by n or %, min/max, etc). Each __role__
has a number of __servers__ which actually run the code.

There's one difference with Heroku related to the database
servers. Each functional database (master, shard 1, etc.)  is deployed
to its own __farm__ as a result of how Scalr's Postgres support
works. But all TTM __roles__ have access to all the databases through
configuration.

Some examples of our __farms__ and __roles__:

Farms:

* Prod-AppServer
* Prod-DB-(Primary|Shard([1-4]))
* Review

Roles:

* RailsAppServer
* Sidekiq
* Bunchball
* Reports
* DevDebug
* SystemWatcher

Configuration can be defined at the __Global__, __Farm__, __Role__, or
__Server__ levels and due to some scripting from our end are available
as environment variables similar to Heroku. Though unlike Heroku they
must begin with the `TTM_` prefix to be propagated.


### Usability ideas

* Be able to use farm name vs ID
* Be able to use 'internal mapping' of farm name vs scalr (e.g.,
  'ttm-production' vs 'Prod-AppServer', 'ttm-staging' or 'ttm-review'
  vs 'Review', etc.)


### config

Tasks to implement:

* get: globals || farm || farm + role || farm + role + server, all or
  single name
* set: globals || farm || farm + role || farm + role + server, one or
  more key/value pairs

### deploy

Tasks to accomplish:

* git push to scalr source
* scalr API deploy
* ...ensure asset compilation works, if not fail the deploy!
* ...triggers graceful unicorn restart
* ...unicorn will issue error if new code fails (??)
* listen for errors on PaperTrail

### ps

Tasks to implement:

* restart: takes farm || farm + role || farm + role + server
* start: takes farm || farm + role || farm + role + server
* stop: takes farm || farm + role || farm + role + server
* info: list/restrict-to farms || farms + roles || farms + roles +
  servers; give deterministic + short (!!) IDs to servers so users
  don't need to juggle GUIDs -- see scalar 'index' of each server.

### load_test

Tasks to accomplish:

* scalr API run rake task on environment (loads testing data; make
  available in app? pushes to S3?)
* get CSV of data that was loaded (HTTP call? pull file to S3?)
* scalr API start a specific farm
* wait for farm to start
* ... run load test ...
* stop specific farm (unload data?)

### psql

## Heroku commands

We'd like to be able to replicate everything we actually used with
heroku. Here's a list of all its commands:

    cwinters@abita:~/Projects/TTM/apangea$ heroku --help
    Usage: heroku COMMAND [--app APP] [command-specific-options]

    Primary help topics, type "heroku help TOPIC" for more details:

      addons    #  manage addon resources
      apps      #  manage apps (create, destroy)
      auth      #  authentication (login, logout)
      config    #  manage app config vars
      domains   #  manage custom domains
      logs      #  display logs for an app
      ps        #  manage processes (dynos, workers)
      releases  #  manage app releases
      run       #  run one-off commands (console, rake)
      sharing   #  manage collaborators on an app

    Additional topics:

      account      #  manage heroku account options
      certs        #  manage ssl endpoints for an app
      db           #  manage the database for an app
      drains       #  display syslog drains for an app
      fork         #  clone an existing app
      git          #  manage git for apps
      help         #  list commands and display help
      keys         #  manage authentication keys
      labs         #  manage optional features
      maintenance  #  manage maintenance mode for an app
      pg           #  manage heroku-postgresql databases
      pgbackups    #  manage backups of heroku postgresql databases
      plugins      #  manage plugins to the heroku gem
      stack        #  manage the stack for an app
      status       #  check status of heroku platform
      update       #  update the heroku client
      version      #  display version

Of these we'll probably implement things in this order:

__config__

    cwinters@abita:~/Projects/TTM/apangea$ heroku config --help
    Usage: heroku config

     display the config vars for an app

     -s, --shell  # output config vars in shell format

    Examples:

     $ heroku config
     A: one
     B: two

     $ heroku config --shell
     A=one
     B=two

    Additional commands, type "heroku help COMMAND" for more details:

      config:get KEY                            #  display a config value for an app
      config:set KEY1=VALUE1 [KEY2=VALUE2 ...]  #  set one or more config vars
      config:unset KEY1 [KEY2 ...]              #  unset one or more config vars

__ps__

    cwinters@abita:~/Projects/TTM/apangea$ heroku ps --help
    Usage: heroku ps

     list processes for an app

    Example:

     $ heroku ps
     === run: one-off processes
     run.1: up for 5m: `bash`

     === web: `bundle exec thin start -p $PORT`
     web.1: created for 30s

    Additional commands, type "heroku help COMMAND" for more details:

      ps:restart [PROCESS]                              #  restart an app process
      ps:scale PROCESS1=AMOUNT1 [PROCESS2=AMOUNT2 ...]  #  scale processes by the given amount
      ps:stop PROCESS                                   #  stop an app process


Plus some additional functionality:

* deploy
* psql (like pg:psql? just output shell command for it?)

## Also: api_check

You can check the Scalr API configuration with:

    ruby bin/api_check.rb

Which if everything is ok will just output:

    EVERYTHING OK!!!!!

You can also view all the API commands:

    ruby bin/api_check.rb all

or just those matching a substring:

    $ ruby bin/api_check.rb match app
    dm_application_create (DmApplicationCreate) @ 2.3.0
      => name (Name) [Required? true]
      => source_id (SourceID) [Required? true]

    dm_application_deploy (DmApplicationDeploy) @ 2.3.0
      => application_id (ApplicationID) [Required? true]
      => farm_role_id (FarmRoleID) [Required? true]
      => remote_path (RemotePath) [Required? true => default: /var/www]

    dm_applications_list (DmApplicationsList) @ 2.3.0

# Scalr API ideas

* Tasks should have a timestamp (dm_deployment_tasks_list)
* I should be able to fetch logs not only by a pagination offset,
  but also before/after a timestamp
