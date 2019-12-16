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

  robot.statuspage ?= new StatusPage robot, process.env
  statuspage = robot.statuspage

  # Webhook listener
  # console.log robot.adapterName
  if statusAnnounceRoom?
    robot.router.post statusEndpoint, (req, res) ->
      if req.body?
        statuspage.parseWebhook(req.body, robot.adapterName)
        .then (message) ->
          robot.messageRoom statusAnnounceRoom, message
          res.status(200).end()
        .catch (e) ->
          robot.logger.error "[statuspage] Invalid hook payload from #{req.ip}"
          robot.logger.debug 'invalid payload', req.body
          robot.logger.debug e
          res.status(422).end()
