# Description:
#   webhook endpoint for Pagerduty
#
# Dependencies:
#
# Configuration:
#   PAGERV2_ENDPOINT
#   PAGERV2_ANNOUNCE_ROOM
#
# Commands:
#
# Author:
#   kolo

StatusPage = require '../lib/statuspage'

module.exports = (robot) ->

  statusEndpoint = process.env.STATUSPAGE_ENDPOINT or '/status_hook'
  statusAnnounceRoom = process.env.STATUSPAGE_ANNOUNCE_ROOM
  statusCustomEmit = process.env.STATUSPAGE_CUSTOM_EMIT

  robot.statuspage ?= new StatusPage robot, process.env
  statuspage = robot.statuspage

  # Webhook listener
  # console.log robot.adapterName
  if statusAnnounceRoom?
    robot.router.post statusEndpoint, (req, res) ->
      if req.body?
        isComponent = req.body.component?
        isIncident = req.body.incident?
        statuspage.parseWebhook(req.body, robot.adapterName)
        .then (data) ->
          if isComponent
            message = statuspage.printComponent(data, false, robot.adapterName)
          if isIncident
            message = statuspage.printIncident(data, false, robot.adapterName)
          robot.messageRoom statusAnnounceRoom, message
          if statusCustomEmit?
            if isComponent
              data = { 'component': data }
            if isIncident
              data =  { 'incident': data }
            robot.emit statusCustomEmit, data
          res.status(200).end()
        .catch (e) ->
          robot.logger.error "[statuspage] Invalid hook payload from #{req.ip}"
          robot.logger.debug 'invalid payload', req.body
          robot.logger.debug e
          res.status(422).end()
