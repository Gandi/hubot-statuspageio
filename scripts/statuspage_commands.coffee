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
      res.send "#{e}"
    res.finish()
  

  robot.on 'status_create', (payload) ->
    statuspage.createIncidentFromTemplate(payload.name, payload.components)
    .then (data) ->
      robot.messageRoom statusAnnounceRoom,
      statuspage.printIncident(data, false, robot.adapterName)
    .catch (e) ->
      robot.messageRoom statusAnnounceRoom, "#{e}"

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
      statuspage.getComponentByName(comp_list[0])
      .then (data) ->
        result = { }
        result[data.id] = comp_list[1]
        return result
      .catch (e) ->
        res.send "#{e}"
    .then (data) =>
      comp = { }
      for d in data
        Object.assign(comp, d)
      payload.components = comp
      @robot.emit 'status_create', payload

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
      res.send "#{e}"
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
    update.incident.auto_transition_to_operational_state = true
    statuspage.getIncident(incident_id)
    .then (data) ->
      update.incident.components_id = data.components.map (comp) -> comp.id
      statuspage.updateIncident(incident_id, update)
      .then (data) ->
        res.send statuspage.printIncident(data, true, robot.adapterName)
    .catch (e) ->
      res.send "#{e}"
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
      res.send "#{e}"
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
      res.send "#{e}"
    res.finish()

  # hubot sp t[emplates] [template_name] - list all available template, filtered by templatename
  robot.respond /sp(?:\s*) t(?:emplates)? ?(.*)?$/, 'status_component', (res) ->
    [_, name] = res.match
    if name?
      statuspage.getTemplatesByName(name)
      .then (found_templates) ->
        for found_template in found_templates
          if found_template?
            res.send statuspage.printTemplate(found_template, true)
      .catch (e) ->
        res.send "#{e}"
    else
      statuspage.getTemplates()
      .then (found_templates) ->
        if not found_templates? or found_templates.length is 0
          res.send 'Error: no template found'
        else
          for found_template in found_templates
            res.send statuspage.printTemplate(found_template, false)
      .catch (e) ->
        res.send "#{e}"
    res.finish()

  # hubot sp co?m?p? <comp_name> is <op|deg|part|maj|main|> - change the status of a component
  robot.respond '/sp(?:\s*) co(?:mp)? (.*) is (op(?:e(?:rational)?)?|deg(?:raded)?'+
  '|part(?:ial outage)?|maj(?:or outage)?|main(?:tenance)?)/i', (res) ->
    [_, components_string, status] = res.match
    if status.toUpperCase().indexOf('OP') >= 0
      status = 'operational'
    else if status.toUpperCase().indexOf('DEG') >= 0
      status = 'degraded_performance'
    else if status.toUpperCase().indexOf('PART') >= 0
      status = 'partial_outage'
    else if status.toUpperCase().indexOf('MAJ') >= 0
      status = 'major_outage'
    else if status.toUpperCase().indexOf('MAIN') >= 0
      status = 'under_maintenance'
    components = components_string.split(',')
    component_ids = components.map (component) ->
      statuspage.getComponentByName(component, false)
    Promise.all(component_ids)
    .then (data) ->
      updates = []
      for component in data
        component.status = status
        component_data = { component: { status: status } }
        updates.push statuspage.updateComponent(component.id, component_data)
      Promise.all(updates)
      .then ->
        res.send 'Update sent'
    .catch (e) ->
      res.send "Unable to update #{e}"
      res.finish()
    res.finish()

  # hubot sp c[omp] [comp_name] - get a component and his nested component or list them all
  robot.respond /sp(?:\s*) co(?:mp)? ?(.*)?$/, 'status_component', (res) ->
    [_, component] = res.match
    if component?
      statuspage.getComponentsByName(component)
      .then (data) ->
        for comp in data
          res.send statuspage.printComponent(comp, true, robot.adapterName)
      .catch (e) ->
        res.send "#{e}"
    else
      statuspage.getComponents()
      .then (data) ->
        for comp in data
          res.send statuspage.printComponent(comp, false, robot.adapterName)
        if not data? or data.length is 0
          res.send 'No component found'
      .catch (e) ->
        res.send "#{e}"
    res.finish()

#   hubot sp inc <incident_id> - give the details about an incident
  robot.respond /sp(?:\s*)(?:inc(?:\s*)?)?([a-z0-9]*)$/, 'status_details', (res) ->
    [_, incident_id] = res.match
    statuspage.getIncident(incident_id)
    .then (inc) ->
      res.send statuspage.printIncident(inc, true, robot.adapterName)
    .catch (e) ->
      res.send "#{e}"
    res.finish()
