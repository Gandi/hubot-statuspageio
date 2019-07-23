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
    @robot.brain.data.statuspage ?= {
      users: { },
      components: { }
    }
    @logger = @robot.logger
    @logger.debug 'Statuspage Loaded'
    if process.env.STATUSPAGE_LOG_PATH?
      @errorlog = path.join process.env.STATUSPAGE_LOG_PATH, 'statuspage-error.log'

  getPermission: (user, group) =>
    return new Promise (res, err) =>
      isAuthorized = @robot.auth?.hasRole(user, [group, 'statusadmin']) or
                     @robot.auth?.isAdmin(user)
      if process.env.STATUSPAGE_NEED_GROUP_AUTH? and
         process.env.STATUSPAGE_NEED_GROUP_AUTH isnt '0' and
         @robot.auth? and
         not(isAuthorized)
        err "You don't have permission to do that."
      else
        res()

  request: (method, endpoint, query, from = false) ->
    return new Promise (res, err) ->
      version = ''
      if process.env.STATUSPAGE_API_VERSION?
        version = process.env.STATUSPAGE_API_VERSION
      else
        version = '/v1'
      if process.env.STATUSPAGE_API_KEY?
        auth = "OAuth #{process.env.STATUSPAGE_API_KEY}"
        body = JSON.stringify(query)
        if method is 'GET'
          qs = querystring.stringify(query)
          if qs isnt ''
            endpoint += "?#{qs}"
        options = {
          hostname: 'api.statuspage.io'
          port: 443
          method: method
          path: version + endpoint
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
            if data.length > 0
              json_data = JSON.parse(data.join(''))
              if json_data.error?
                console.log req.method, req.path
                err "#{response.statusCode} #{json_data.error}"
              else
                res json_data
            else
              res { }
        req.on 'error', (error) ->
          err "#{error.code} #{error.message}"
        if method is 'PUT' or method is 'POST'
          req.write body
          console.log body
        req.end()
      else
        err 'STATUSPAGE_API_KEY is not set in your environment.'

  getTemplateByName: (name, page_id = process.env.STATUSPAGE_PAGE_ID) ->
    return new Promise (res, err) =>
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
          err 'too many matching name'
          @logger.debug result
      .catch (e) ->
        err e

  getTemplates: (page_id = process.env.STATUSPAGE_PAGE_ID) ->
    return @request('GET', "/pages/#{page_id}/incident_templates")

  getComponentByName: (name, page_id = process.env.STATUSPAGE_PAGE_ID) ->
    return new Promise (res, err) =>
      if @robot.brain.data.statuspage.components[name]?
        id = @robot.brain.data.statuspage.components[name]
        @getComponent(id)
          .then (data) ->
            res data
          .catch (e) ->
            err e
      else
        @getComponents()
        .then (data) =>
          for comp in data
            @robot.brain.data.statuspage.components[comp.name] = comp.id
            if name = comp.name
              result = comp
          if result?
            res data
        .catch (e) ->
          err e

  getIncidents: (search = null, page_id = process.env.STATUSPAGE_PAGE_ID ) ->
    if search?
      query = { q: search }
    else
      query = { q: { status: 'open' } }
    return @request('GET', "/pages/#{page_id}/incidents.json", query)

  getComponents: (page_id = process.env.STATUSPAGE_PAGE_ID) ->
    return @request('GET', "/pages/#{page_id}/components")

  getComponent: (component_id, page_id = process.env.STATUSPAGE_PAGE_ID) ->
    return new Promise (res, err) =>
      @request('GET', "/pages/#{page_id}/components/#{component_id}")
      .then (data) =>
        if data.components?.length > 0
          sub_components = Promise.map data.components, (comp) =>
            @getComponent(comp, page_id)
          res Promise.all sub_components
        else
          res @request('GET', "/pages/#{page_id}/components/#{component_id}")
      .catch (e) ->
        err e

  getUnresolvedIncidents: (search = null, page_id = process.env.STATUSPAGE_PAGE_ID ) ->
    if search?
      query = { q: search }
    else
      query = { q: { status: 'open' } }
    return @request('GET', "/pages/#{page_id}/incidents/unresolved")

  getIncident: (incident_id, page_id = process.env.STATUSPAGE_PAGE_ID ) ->
    return @request('GET', "/pages/#{page_id}/incidents/#{incident_id}")

  getActiveMaintenance: (page_id = process.env.STATUSPAGE_PAGE_ID) ->
    return @request('GET', "/pages/#{page_id}/incidents/active_maintenance")

  updateIncident: (incident_id, update, page_id = process.env.STATUSPAGE_PAGE_ID) ->
    return @request('PUT', "/pages/#{page_id}/incidents/#{incident_id}.json", update)

  createIncidentFromTemplate: (template, components, page_id = process.env.STATUSPAGE_PAGE_ID) ->
    return new Promise (res, err) =>
      @getTemplateByName(template, page_id)
      .then (template_data) =>
        template_data.components = components
        template_data.components_id = Object.keys(components)
        incident = { incident: template_data }
        @createIncident(incident, page_id)
        .then (data) ->
          res data
        .catch (e) ->
          err e
    
  createIncident: (incident, page_id = process.env.STATUSPAGE_PAGE_ID) ->
    return @request('POST', "/pages/#{page_id}/incidents", incident)

  printComponent: (comp, full = false, adapterName = 'irc') ->
    colored_status = @colorer(
      adapterName
      comp.status
      comp.status
    )
    desc = if full? and comp.description? then " #{comp.description}" else ''
    return "[#{colored_status}] #{comp.name}#{desc}"

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

    slack: (text, color) ->
      "*#{text}*"

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
 
  logError: (message, payload) ->
    if @errorlog?
      fs.appendFileSync @errorlog, '\n---------------------\n'
      fs.appendFileSync @errorlog, "#{moment().utc().format()} - #{message}\n\n"
      fs.appendFileSync @errorlog, JSON.stringify(payload, null, 2), 'utf-8'



module.exports = StatusPage
