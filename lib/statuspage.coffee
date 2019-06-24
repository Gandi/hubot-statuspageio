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
      services: { }
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
                err "#{response.statusCode} #{json_data.error}"
              else
                res json_data
            else
              res { }
        req.on 'error', (error) ->
          err "#{error.code} #{error.message}"
        if method is 'PUT' or method is 'POST'
          req.write body
        req.end()
      else
        err 'STATUSPAGE_API_KEY is not set in your environment.'
  getIncidents: (search = null, page_id = process.env.STATUSPAGE_PAGE_ID ) ->
    if search?
      query = { q: search }
    else
      query = { }
    return @request('GET', "/pages/#{page_id}/incidents.json", query)

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
      trigger: 'red',
      triggered: 'red',
      unacknowledge: 'red',
      unacknowledged: 'red',
      acknowledge: 'yellow',
      acknowledged: 'yellow',
      completed: 'green',
      assign: 'blue',
      escalate: 'blue'
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
