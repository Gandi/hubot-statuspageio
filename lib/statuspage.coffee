# Description:
#   handles communication with StatusPage API v2
#
# Dependencies:
#
# Configuration:
#  STATUSPAGE_API_KEY
#
# Author:
#   kolo

fs = require 'fs'
path = require 'path'
https = require 'https'
moment = require 'moment'
Promise = require 'bluebird'
querystring = require 'querystring'

class StatusPage

  constructor: (@robot) ->
    @robot.brain.data.statuspage ?= { }
    @robot.brain.data.users ?= { }
    @robot.brain.data.components ?= { }
    @logger = @robot.logger
    @logger.debug 'Statuspage Loaded'
    if process.env.STATUSPAGE_LOG_PATH?
      @errorlog = path.join process.env.STATUSPAGE_LOG_PATH, 'statuspage-error.log'

  request: (method, endpoint, query, from = false) ->
    return new Promise (res, err) ->
      version = ''
      if process.env.STATUSPAGE_PAGE_ID?
        page = "/pages/#{process.env.STATUSPAGE_PAGE_ID}"
      else
        err 'STATUSPAGE_PAGE_ID is not set in your environment.'
      version = '/v1'
      if process.env.STATUSPAGE_API_KEY?
        auth = "OAuth #{process.env.STATUSPAGE_API_KEY}"
        body = JSON.stringify(query)
        options = {
          hostname: 'api.statuspage.io'
          port: 443
          method: method
          path: version + page + endpoint
          headers: {
            Authorization: auth,
            Accept: "'Content-Type': 'application/json'"
          }
        }
        if from?
          options.headers.From = from
        req = https.request options, (response) ->
          data = []
          response.on 'data', (chunk) ->
            data.push chunk
          response.on 'end', ->
            json_data = JSON.parse(data.join(''))
            if json_data.error?
              err "#{response.statusCode} #{json_data.error}"
            else
              res json_data
        req.on 'error', (error) ->
          err "#{error.code} #{error.message}"
        if method is 'PUT' or method is 'POST'
          req.write body
        req.end()
      else
        err 'STATUSPAGE_API_KEY is not set in your environment.'

  getTemplateByName: (name) ->
    new Promise (res, err) =>
      @getTemplates()
      .then (data) ->
        result = []
        for template in data
          if template.name.toUpperCase().indexOf(name.toUpperCase()) >= 0
            result.push(template)
        if result.length is 1
          res result[0]
        else if result.length is 0
          err 'no matching template found'
        else
          err 'too many matching templates'
      .catch (e) ->
        err e

  getTemplates: ->
    return @request('GET', '/incident_templates')

  getComponentByName: (name, recursive = true) ->
    if @robot.brain.data.statuspage.components[name]?
      id = @robot.brain.data.statuspage.components[name]
      Promise.all [@getComponent(id)]
    else
      @getComponents()
      .then (data) =>
        matched_comps = data.filter (comp) ->
          comp.name.toUpperCase().indexOf(name.toUpperCase()) >= 0
        if matched_comps.length is 1
          if recursive
            comp = matched_comps[0]
            @robot.brain.data.statuspage.components[comp.name] = comp.id
            Promise.all @getComponentRecursive(comp.id)
          else
            Promise.resolve(matched_comps)
        else if matched_comps.length > 1
          sub_components = matched_comps.map (comp) =>
            @robot.brain.data.statuspage.components[comp.name] = comp.id
            @getComponent(comp.id)
          Promise.all sub_components

  getComponents: ->
    return @request('GET', '/components')

  getComponentRecursive: (comp_id) ->
    @request('GET', "/components/#{comp_id}")
    .then (data) =>
      result = [ Promise.resolve(data) ]
      for comp in data.components
        result.push @getComponent(comp)
      return result


  getComponent: (component_id) ->
    @request('GET', "/components/#{component_id}")

  getUnresolvedIncidents: (search = null ) ->
    return @request('GET', '/incidents/unresolved')

  getIncident: (incident_id) ->
    return @request('GET', "/incidents/#{incident_id}")

  getActiveMaintenance: ->
    return @request('GET', '/incidents/active_maintenance')

  updateIncident: (incident_id, update) ->
    return @request('PUT', "/incidents/#{incident_id}.json", update)

  createIncidentFromTemplate: (template, components) ->
    return new Promise (res, err) =>
      @getTemplateByName(template)
      .then (template_data) =>
        template_data.components = components
        template_data.component_ids = Object.keys(components)
        incident = { incident: template_data }
        @createIncident(incident)
        .then (data) ->
          res data

      .catch (e) ->
        err e
    
  createIncident: (incident) ->
    return @request('POST', '/incidents', incident)

  printComponent: (comp, full = false, adapterName = 'irc') ->
    if comp.status?
      status = @colorer(
        adapterName
        comp.status
        "[#{comp.status}]"
      )
    else
      status = ''
    desc = if full and comp.description? then " #{comp.description}" else ''
    id = if full then " - #{comp.id}" else ''
    return "#{status} #{comp.name}#{desc}#{id}"

  printIncident: (inc, full = false, adapterName = 'irc') ->
    colored_id = @colorer(
      adapterName
      inc.status
      inc.id
    )
    @logger.debug inc
    impact = inc.impact
    colored_impact = @colorer(
      adapterName
      impact
      impact
    )
    affected_component = inc.components.map (c) =>
      @colorer(adapterName, c.status, c.name)
    result = "[#{colored_id} - #{colored_impact}] {#{affected_component.join(', ')}} : #{inc.name} \
- #{inc.status}"
    if full
      if inc.incident_updates.length > 0
        update = inc.incident_updates[0]
        formated_date = moment(update.updated_at).utc().format('ddd HH:mm')
        result += "\n #{update.body} - #{formated_date}"
    return result

  coloring: {
    irc: (text, color) ->
      colors = require('irc-colors')
      if colors[color]
        colors[color](text)
      else
        text

    generic: (text, color) ->
      text
  }

  colorer: (adapter, level, text) ->
    colors = {
      investigated: 'red'
      identified: 'yellow'
      monitoring: 'lightgreen'
      resolved: 'green'
      operational: 'green'
      scheduled: 'teal'
      inprogress: 'cyan'
      verifying: 'aqua'
      completed: 'royal'
      minor: 'lightgreen'
      major: 'red'
      critical: 'brown'
      degraded_performance: 'yellow'
    }
    if @coloring[adapter]?
      @coloring[adapter](text, colors[level])
    else
      @coloring.generic(text, colors[level])



module.exports = StatusPage
