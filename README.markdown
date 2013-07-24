# Looking for ttmscalr?

See instructions and help in [[bin/README.md](https://github.com/thinkthroughmath/scalr/tree/master/bin)].

# Scalr Gem

Scalr is a cloud infrastructure management provider. This gem is for interfacing with the Scalr.net API to obtain information about your instances and farms.

As of version 0.2.0 the Scalr gem has been updated to use the Scalr 2.0 API (thanks to threetee).

## Installing Scalr

    $ gem install scalr

## Usage

First, include rubygems and scalr:

    require 'rubygems'
    require 'scalr'

Now, just initialize scalr with your api values (can be found in your system settings on scalr.net):

    Scalr.key_id = "your_key_id"
    Scalr.access_key = "your_access_key"

Like most rubyists, I can't stand camel case, so you make calls to the Scalr API with their underscore equivalent names and parameters:

    response = Scalr.list_dns_zone_records(:domain_name => 'domain.com')

All API calls return a Scalr::Response instance with the following attributes:

    response.code # the HTTP response code from the API request
    response.message # the HTTP response message
    response.value # the value returned from the API as a hash
    response.error # if the requests returns an API error it is stored here for easy access

Just like the actions and inputs, all returned values are put in the response.value hash as underscored symbols (converted from the camel case returned by the gateway). 

I recommend opening up an irb session and making test calls to figure out the response structures.

## Note on Patches/Pull Requests
 
* Fork the project.
* Make your feature addition or bug fix.
* Commit, do not mess with rakefile, version, or history.
  (if you want to have your own version, that is fine but bump version in a commit by itself I can ignore when I pull)
* Send me a pull request. Bonus points for topic branches.

## Contributors

* [threetee](https://github.com/threetee)
* [jagthedrummer](https://github.com/jagthedrummer)

## Copyright

Copyright (c) 2010 RedBeard Tech. See LICENSE for details.
