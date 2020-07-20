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
    @robot.brain.data.statuspage.components ?= { }
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
        err 'Error: STATUSPAGE_PAGE_ID is not set in your environment.'
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
            try
              json_data = JSON.parse(data.join(''))
              if json_data.error?
                err "Error: #{response.statusCode} #{json_data.error}"
              else
                res json_data
            catch e
              err e
        req.on 'error', (error) ->
          err "#{error.code} #{error.message}"
        if method is 'PUT' or method is 'POST'
          req.write body
        req.end()
      else
        err 'Error: STATUSPAGE_API_KEY is not set in your environment.'

  parseWebhook: (message, adapter) ->
    new Promise (res, err) =>
      if message?.incident?.id?
        @getIncident(message.incident.id)
        .then (data) =>
          res @printIncident(data, false, adapter)
      else if message?.component?.id?
        @getComponent(message.component.id)
        .then (data) =>
          res @printComponent(data, false, adapter)
      else
        err 'Error: invalid payload received'

  getTemplatesByName: (name) ->
    new Promise (res, err) =>
      @getTemplates()
      .then (data) ->
        result = []
        for template in data
          if template.name.toUpperCase().indexOf(name.toUpperCase()) >= 0
            result.push(template)
        if result.length is 0
          err 'Error: no matching template found'
        else
          res result
      .catch (e) ->
        err e


  getTemplates: ->
    return @request('GET', '/incident_templates')


  getComponentByName: (name) ->
    @getComponentsByName(name, false)
    .then (data) ->
      if data.length is 1
        return data[0]
      if data.length > 1
        throw new Error('too many matching components')

  getComponentsByName: (name, recursive = true) ->
    if @robot.brain.data.statuspage.components[name]?
      id = @robot.brain.data.statuspage.components[name]
      if recursive
        Promise.all @getComponentRecursive(id)
      else
        Promise.resolve([@getComponent(id)])
    else
      @getComponents()
      .then (data) =>
        matched_comps = data.filter (comp) =>
          @robot.brain.data.statuspage.components[comp.name] = comp.id
          comp.name.toUpperCase().indexOf(name.toUpperCase()) >= 0
        if matched_comps.length is 1
          if recursive
            comp = matched_comps[0]
            Promise.all @getComponentRecursive(comp.id)
          else
            Promise.resolve(matched_comps)
        else if matched_comps.length > 1
          sub_components = matched_comps.map (comp) =>
            @robot.brain.data.statuspage.components[comp.name] = comp.id
            @getComponent(comp.id)
          Promise.all sub_components
        else
          throw new Error("unknown component #{name}")

  getComponents: ->
    @request('GET', '/components')

  getComponentRecursive: (comp_id) ->
    @request('GET', "/components/#{comp_id}")
    .then (data) =>
      result = [ Promise.resolve(data) ]
      if data.components?
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

  updateComponent: (component_id, update) ->
    @request('PUT', "/components/#{component_id}", update)

  createIncidentFromTemplate: (template, components) ->
    return new Promise (res, err) =>
      @getTemplatesByName(template)
      .then (template_data) =>
        if template_data.length > 1
          err 'Error: too many matching templates'
          return
        template = template_data[0]
        template.components = components
        template.component_ids = Object.keys(components)
        incident = { incident: template }
        @createIncident(incident)
        .then (data) ->
          res data

      .catch (e) ->
        err e
    
  createIncident: (incident) ->
    return @request('POST', '/incidents', incident)

  printTemplate: (template, full) ->
    if full
      return "[#{template.name}] #{template.title} : #{template.body}"
    return "[#{template.name}] #{template.title}"

  printComponent: (comp, full = false, adapterName = 'irc') ->
    name = comp.name
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
    return "#{status} #{name}#{desc}#{id}"

  printIncident: (inc, full = false, adapterName = 'irc') ->
    colored_id =
      @colorer(
        adapterName
        inc.status
        inc.id
      )

    @logger.debug inc
    colored_impact =
      @colorer(
        adapterName
        inc.impact
        inc.impact
      )
    affected_component =
      '{' + (inc.components.map (c) =>
        @colorer(adapterName, c.status, c.name)
      .join(', ')) + '}'
    name = inc.name
    status = inc.status
    result = "[#{colored_id} - #{colored_impact}] #{affected_component} : #{name} \
- #{status}"
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
      under_maintenance: 'cyan'
      verifying: 'aqua'
      completed: 'royal'
      minor: 'lightgreen'
      major: 'red'
      critical: 'brown'
      degraded_performance: 'yellow'
      partial_outage: 'yellow'
      major_outage: 'red'
    }
    if @coloring[adapter]?
      @coloring[adapter](text, colors[level])
    else
      @coloring.generic(text, colors[level])



module.exports = StatusPage
