# Description:
#   enable communication with statuspage using API v1
#
# Dependencies:
#
# Configuration:
#
# Commands:
#
#   hubot sp version - give the version of hubot-statuspage loaded
#
#   hubot sp [inc] - give the ongoing incidents
#   hubot sp inc <incident_id> - give the details about an incident
#   hubot sp main[tenance] - give the ongoing maintenance
#   hubot sp c[omp] [comp_name] - get a component or list them all
#
#   hubot sp new <template_name> on <component:status,component:status...> - create new status using template_name on component(s)
#
#   hubot sp set <incident_id> <id|mon|res> [comment] update a status
#   hubot sp <incident_id> is <none,minor,major,critical> - set the impact of an inciden
#   hubot sp <incident_id> + comment - add a comment to an incident
#
# Author:
#   kolo
StatusPage = require '../lib/statuspage'
moment = require 'moment'
path = require 'path'
Promise = require 'bluebird'
module.exports = (robot) ->

  robot.brain.data.statuspage ?= { users: { } }
  robot.statuspage ?= new StatusPage robot, process.env
  statusAnnounceRoom = process.env.STATUSPAGE_ANNOUNCE_ROOM
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
          res.send statuspage.printIncident(inc, false, robot.adapterName)
    .catch (e) ->
      res.send "Error: #{e}"
    res.finish()
  

  robot.on 'status_create', (payload) ->
    statuspage.createIncidentFromTemplate(payload.name, payload.components)
    .then (data) ->
      robot.messageRoom statusAnnounceRoom,
      statuspage.printIncident(data, false, robot.adapterName)
    .catch (e) ->
      robot.messageRoom statusAnnounceRoom, "Error: #{e}"

# hubot sp new <template_name> on <component:status,component:status...>
  robot.respond /sp(?:\s*) (?:new|create) (.*) on (.*)?$/, (res) ->
    [_, name_value, components_value] = res.match
    payload = {
      name: name_value
      components: components_value
    }
    components_list = payload.components.split(',')
    Promise.map components_list, (comp) ->
      comp_list = comp.split(':')
      statuspage.getComponentByName(comp_list[0], false)
      .then (data) ->
        if data.id?
          result = { }
          result[data.id] = comp_list[1]
          return result
        else
          throw new Error("unknown component #{comp_list[0]}")
    .then (data) =>
      comp = { }
      for d in data
        Object.assign(comp, d)
      payload.components = comp
      @robot.emit 'status_create', payload
    .catch (e) ->
      res.send "#{e}"

#   hubot sp main[tenance] - give the ongoing maintenance
  robot.respond /sp(?:\s*) main(tenance)?/, 'status_maintenance', (res) ->
    statuspage.getActiveMaintenance()
    .then (data) ->
      if not data.length? or data.length is 0
        res.send 'There is no active maintenance'
      else
        for inc in data
          res.send statuspage.printIncident(inc, false, robot.adapterName)
    .catch (e) ->
      res.send "Error: #{e}"
    res.finish()

  # hubot sp set <incident_id> <id|mon|res> [comment] update a status
  robot.respond /sp(?:\s*) ?(?:set) ([a-z0-9]*) ([a-zA-Z]*) ?(.*)?$/, 'status_update', (res) ->
    [_, incident_id, status, comment] = res.match
    if status.toUpperCase().indexOf('ID') >= 0
      status = 'identified'
    else if status.toUpperCase().indexOf('MON') >= 0
      status = 'monitoring'
    else if status.toUpperCase().indexOf('RES') >= 0
      status = 'resolved'
    update = {
      incident: { }
    }
    if status?
      update.incident.status = status
    if comment?
      update.incident.message = comment
    statuspage.updateIncident(incident_id, update)
    .then (data) ->
      res.send statuspage.printIncident(data, true, robot.adapterName)
    .catch (e) ->
      res.send "Error: #{e}"
    res.finish()

  # hubot sp <incident_id> + comment - add a comment to an incident
  robot.respond /sp(?:\s+)([a-z0-9]*) \+ (.*)$/, 'status_update', (res) ->
    [_, incident_id, comment] = res.match
    update = {
      incident: {
        message: comment
      }
    }
    statuspage.updateIncident(incident_id, update)
    .then (data) ->
      res.send statuspage.printIncident(data, true, robot.adapterName)
    .catch (e) ->
      res.send "Error: #{e}"
    res.finish()

  # hubot sp <incident_id> is <none,minor,major,critical> - set the impact of an incident
  robot.respond /sp(?:\s+)([a-z0-9]*) is ([a-zA-Z]*)(?:\s*)$/, 'status_impact', (res) ->
    [_, incident_id, impact] = res.match
    if impact.toUpperCase().indexOf('MIN') >= 0
      impact = 'minor'
    else if impact.toUpperCase().indexOf('MAJ') >= 0
      impact = 'major'
    else if impact.toUpperCase().indexOf('NO') >= 0
      impact = 'none'
    else if impact.toUpperCase().indexOf('CRIT') >= 0
      impact = 'critical'
    else
      res.send "unknown impact #{impact}"
      res.finish()
      return
    update = {
      incident: {
        impact: impact
        impact_override: impact
      }
    }
    statuspage.updateIncident(incident_id, update)
    .then (data) ->
      res.send statuspage.printIncident(data, true, robot.adapterName)
    .catch (e) ->
      res.send "Error: #{e}"
    res.finish()


  # hubot sp c[omp] [comp_name] - get a component or list them all
  robot.respond /sp(?:\s*) co(?:mp)? ?(.*)?$/, 'status_component', (res) ->
    [_, component] = res.match
    if component?
      statuspage.getComponentByName(component)
      .then (data) ->
        if data.length? > 0
          for comp in data
            res.send statuspage.printComponent(comp, true, robot.adapterName)
        else
          res.send statuspage.printComponent(data, true, robot.adapterName)
      .catch (e) ->
        res.send "Error: #{e}"
    else
      statuspage.getComponents()
      .then (data) ->
        for comp in data
          res.send statuspage.printComponent(comp, false, robot.adapterName)
      .catch (e) ->
        res.send "Error: #{e}"
    res.finish()

#   hubot sp inc <incident_id> - give the details about an incident
  robot.respond /sp(?:\s*)(?:inc(?:\s*)?)?([a-z0-9]*)$/, 'status_details', (res) ->
    [_, incident_id] = res.match
    statuspage.getIncident(incident_id)
    .then (inc) ->
      res.send statuspage.printIncident(inc, true, robot.adapterName)
    .catch (e) ->
      res.send "Error: #{e}"
    res.finish()
