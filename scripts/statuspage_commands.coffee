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
  robot.respond /sp(\s*)$/, 'status_incidents', (res) ->
    statuspage.getUnresolvedIncidents()
    .then (data) ->
      if not data.length? or data.length is 0
        res.send 'All good'
      else
        for inc in data
          res.send statuspage.printIncident(inc)
    .catch (e) ->
      res.send "Error : #{e}"
    res.finish()
  robot.respond /sp(?:\s*)(?:more(?:\s*)?)?([a-z0-9]*)/, 'status_details', (res) ->
    [_, incident_id] = res.match
    statuspage.getIncident(incident_id)
    .then (data) ->
      res.send statuspage.printIncident(inc, true)
    .catch (e) ->
      res.send "Error : #{e}"
    res.finish()
