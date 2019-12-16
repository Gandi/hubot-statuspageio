Hubot-statuspageio
==================

This plugin is based on the usage we have in Gandi of StatusPage.io. It may, in its first instance, not match your setup, so please verify that first.

Configuration
---------------

    # STATUSPAGE_API_KEY v2 configuration vars
    export STATUSPAGE_API_KEY=""
    export STATUSPAGE_PAGE_ID=""
    export STATUSPAGE_ANNOUNCE_ROOM=""
    export STATUSPAGE_ENDPOINT=""

Usage
--------
```
sp <incident_id> + comment - add a comment to an incident
sp <incident_id> is <none,minor,major,critical> - set the impact of an inciden
sp [inc] - give the ongoing incidents
sp c[omp] [comp_name] - get a component or list them all
sp inc <incident_id> - give the details about an incident
sp main[tenance] - give the ongoing maintenance
sp new <template_name> on <component:status,component:status...> - create new status using template_name on component(s)
sp set <incident_id> <id|mon|res> [comment] update a status
sp version - give the version of hubot-statuspage loaded
version - displays the version of this bot
what role does <user> have - Find out what roles are assigned to a specific user
```



Development
--------------

### Changelog

All changes are listed in the [CHANGELOG](CHANGELOG.md)

### Testing

    npm install

    # will run make test and coffeelint
    npm test 
    
    # or
    make test
    
    # or, for watch-mode
    make test-w

    # or for more documentation-style output
    make test-spec

    # and to generate coverage
    make test-cov

    # and to run the lint
    make lint

    # run the lint and the coverage
    make


### Contribute

Feel free to open a PR if you find any bug, typo, want to improve documentation, or think about a new feature. 

Gandi loves Free and Open Source Software. This project is used internally at Gandi but external contributions are **very welcome**. 

Attribution
-----------

### Authors

- [@baptistem](https://github.com/baptistem) - author

### License

This source code is available under [MIT license](LICENSE).

### Copyright

Copyright (c) 2019 - Gandi - https://gandi.net
