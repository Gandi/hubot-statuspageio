path = require 'path'

features = [
  'commands',
  'hook'
]

module.exports = (robot) ->
  for feature in features
    robot.logger.debug "Loading statuspage_#{feature}"
    robot.loadFile(path.resolve(__dirname, 'scripts'), "statuspage_#{feature}.coffee")
