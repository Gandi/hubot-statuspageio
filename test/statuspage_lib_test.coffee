require('es6-promise').polyfill()

Helper = require('hubot-test-helper')

# helper loads a specific script if it's a file
helper = new Helper('../scripts/statuspage_commands.coffee')
StatusPage = require '../lib/statuspage'

http        = require('http')
nock        = require('nock')
sinon       = require('sinon')
chai        = require('chai')
chai.use(require('sinon-chai'))
expect      = chai.expect
querystring = require('querystring')
room = null

describe 'statuspage_lib module', ->
  beforeEach ->
    room = helper.createRoom()
    room.robot.adapterName = 'console'

  afterEach ->
    room.destroy()
# ---------------------------------------------------------------------------------------------
  context 'it set color', ->
    it 'should color irc', ->
      statuspage = new StatusPage room.robot, process.env
      result = statuspage.colorer('irc', 'degraded_performance', 'test')
      expect(result).to.eql '\u000308\u0002\u0002test\u0003'
  context 'it set color but the color is unknown', ->
    it 'should color irc', ->
      statuspage = new StatusPage room.robot, process.env
      result = statuspage.colorer('irc', 'thiscolorisunknown', 'test')
      expect(result).to.eql 'test'
  context 'it set color', ->
    it 'should color emoji', ->
      statuspage = new StatusPage room.robot, process.env
      result = statuspage.colorer('emoji', 'degraded_performance', 'test')
      expect(result).to.eql '🟡 test'
  context 'it set color but the color is unknown', ->
    it 'should color emoji', ->
      statuspage = new StatusPage room.robot, process.env
      result = statuspage.colorer('emoji', 'thiscolorisunknown', 'test')
      expect(result).to.eql 'test'
