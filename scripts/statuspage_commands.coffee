# Description:
#   enable communication with statuspage using API v1
#
# Dependencies:
#
# Configuration:
#
# Commands:
#
# Author:
#   kolo

StatusPage = require '../lib/statuspage'
moment = require 'moment'
path = require 'path'

module.exports = (robot) ->

  robot.brain.data.statuspage ?= { users: { } }
  robot.statuspage ?= new StatusPage robot, process.env
  statuspage = robot.statuspage

#   hubot sp version - give the version of hubot-statuspage loaded
  robot.respond /sp version\s*$/, 'statuspage_version', (res) ->
    pkg = require path.join __dirname, '..', 'package.json'
    res.send "hubot-statuspage is version #{pkg.version}"
    res.finish()

#   hubot sp [inc] - give the ongoing incidents
  robot.respond /sp(\s*)/, 'status_incidents', (res) ->
    statuspage.getIncidents()
    .then (data) ->
      if not data.length?
        res.send 'All good'
      else
        for inc in data
          if inc.impact_override ?
            impact = inc.impact_override
          else
            impact = inc.impact
          res.send "[#{inc.id}] {#{inc.components.join(', ')}} #{impact} - #{inc.status}"
      
