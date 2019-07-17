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
  robot.respond /sp(\s*)(?:inc)?$/, 'status_incidents', (res) ->
    statuspage.getUnresolvedIncidents()
    .then (data) ->
      if not data.length? or data.length is 0
        res.send 'There is no unresolved incident'
      else
        for inc in data
          res.send statuspage.printIncident(inc)
    .catch (e) ->
      res.send "Error : #{e}"
    res.finish()

#   hubot sp [more] <incident_id> - give the details about an incident
  robot.respond /sp(?:\s*)(?:more(?:\s*)?)?([a-z0-9]*)$/, 'status_details', (res) ->
    [_, incident_id] = res.match
    statuspage.getIncident(incident_id)
    .then (data) ->
      res.send statuspage.printIncident(inc, true)
    .catch (e) ->
      res.send "Error : #{e}"
    res.finish()

#   hubot sp main[tenance] - give the ongoing maintenance
  robot.respond /sp(?:\s*) main(tenance)?/, 'status_maintenance', (res) ->
    statuspage.getActiveMaintenance()
    .then (data) ->
      if not data.length? or data.length is 0
        res.send 'There is no active maintenance'
      else
        for inc in data
          res.send statuspage.printIncident(inc)
    .catch (e) ->
      res.send "Error : #{e}"
    res.finish()

  # hubot sp set <incident_id> <id|mon|res> [comment] - update a status to id(entified)|mon(itoring)|res(olved) with an optional comment
  robot.respond /sp(?:\s*) ?(?:set) ([a-z0-9]*) ([a-zA-Z]*) ?(.*)?$/, 'status_update', (res) ->
    [_, incident_id, status,comment] = res.match
    if status.toUpperCase().indexOf('ID') >= 0
      status = "identified"
    else if status.toUpperCase().indexOf('MON') >= 0
      status = "monitoring"
    else if status.toUpperCase().indexOf('RES') >= 0
      status = "resolved"
    update = { incident : {} }
    if status?
      update.incident.status = status
    if message?
      update.incident.message = message
    statuspage.updateIncident(incident_id, update)
    .then (data) ->
       console.log data
       res.send statuspage.printIncident(data, true)
    .catch (e) ->
       res.send "Error: #{e}"
    res.finish()

  # hubot sp <incident_id> + comment - add a comment to an incident
  robot.respond /sp(?:\s*) ([a-z0-9]*) + (.*)$/, 'status_update', (res) ->
    [_, incident_id, comment] = res.match
    update =
      incident:
        message: comment
    statuspage.updateIncident(incident_id,update)
    .then (data) ->
      res.send statuspage.printIncident(data,true)
    .catch (e) ->
      res.send "Error: #{e}"
    res.finish()

  # hubot sp <incident_id> is <none,minor,major,critical> - set the impact of an incident
  robot.respond /sp(?:\s*) ([a-z0-9]*) is ([a-zA-Z]*)(?:\s*)$/, 'status_impact', (res) ->
    [_, incident_id, impact] = res.match
    if impact.toUpperCase().indexOf('NO') >= 0
      impact = "none"
    else if impact.toUpperCase().indexOf('MIN') >= 0
      impact = "minor"
    else if impact.toUpperCase().indexOf('MAJ') >= 0
      impact = "major"
    else if impact.toUpperCase().indexOf('CRIT') >= 0
      impact = "critical"
    else
      res.send "unknown impact #{impact}"
      res.finish()
      return
    update =
      incident:
        impact: impact
        impact_override: impact
    statuspage.updateIncident(incident_id,update)
    .then (data) ->
       res.send statuspage.printIncident(data,true)
    .catch (e) ->
       res.send "Error: #{e}"
    res.finish()
