require('es6-promise').polyfill()

Helper = require('hubot-test-helper')

# helper loads a specific script if it's a file
helper = new Helper('../scripts/statuspage_hook.coffee')
StatusPage = require '../lib/statuspage'

http        = require('http')
nock        = require('nock')
sinon       = require('sinon')
chai        = require('chai')
chai.use(require('sinon-chai'))
expect      = chai.expect
querystring = require('querystring')
room = null

describe 'statuspage_hook module', ->

  hubotHear = (message, userName = 'momo', tempo = 40) ->
    beforeEach (done) ->
      room.user.say userName, message
      setTimeout (done), tempo

  hubot = (message, userName = 'momo') ->
    hubotHear "@hubot #{message}", userName

  hubotResponse = (i = 1) ->
    room.messages[i]?[1]

  hubotResponseCount = ->
    room.messages.length

  beforeEach ->
    process.env.STATUSPAGE_API_KEY = 'xxx'
    process.env.STATUSPAGE_PAGE_ID = 'xxx'
    process.env.STATUSPAGE_SCHEDULE_ID = '42'
    process.env.STATUSPAGE_ANNOUNCE_ROOM = '#dev'
    process.env.STATUSPAGE_ENDPOINT = '/test_hook'
    process.env.STATUSPAGE_CUSTOM_EMIT = 'test'
    process.env.PORT = 8089
    room = helper.createRoom()
    room.robot.adapterName = 'console'
    a = nock('https://api.statuspage.io')
    .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/components/1")
    .reply(200, require('./fixtures/component_detail_1-ok.json'))
    .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/incidents/yyyyyyyyyyy")
    .reply(200, require('./fixtures/incident_detail-ok.json'))
    room.robot.brain.userForId 'user', {
      name: 'user'
    }
    room.robot.brain.userForId 'user_with_email', {
      name: 'user_with_email',
      email_address: 'user@example.com'
    }
    room.robot.brain.userForId 'user_with_phid', {
      name: 'user_with_phid',
      phid: 'PHID-USER-123456789'
    }

  afterEach ->
    delete process.env.STATUSPAGE_API_KEY
    delete process.env.STATUSPAGE_SCHEDULE_ID
    delete process.env.STATUSPAGE_ANNOUNCE_ROOM
    delete process.env.STATUSPAGE_ENDPOINT
    delete process.env.PORT
    delete process.env.STATUSPAGE_CUSTOM_ACTION_FILE
    room.destroy()

# -------------------------------------------------------------------------------------------------
  context 'webhook receive a component update', ->

    it 'should react', ->
      expected = require('./fixtures/component_detail_1-ok.json')
      statuspage = new StatusPage room.robot
      statuspage.parseWebhook(
        require('./fixtures/webhook_component-ok.json'),
        'console'
      ).then (announce) ->
        expect(announce).to.eql expected

# -------------------------------------------------------------------------------------------------
  context 'webhook receive a incident update', ->

    it 'should react', ->
      expected = require './fixtures/incident_detail-ok.json'
      statuspage = new StatusPage room.robot
      statuspage.parseWebhook(
        require('./fixtures/webhook_incident-ok.json'),
        'console'
      ).then (announce) ->
        expect(announce).to.eql expected

# -------------------------------------------------------------------------------------------------
  context 'webhook receive a buggy component update', ->
    it 'should react', ->
      expected = 'Error: invalid payload received'
      statuspage = new StatusPage room.robot
      statuspage.parseWebhook(
        require('./fixtures/webhook_component-ko.json'),
        'console'
      ).catch (announce) ->
        expect(announce).to.eql expected

# -------------------------------------------------------------------------------------------------
  context 'webhook receive a buggy incident update', ->
    it 'should react', ->
      statuspage = new StatusPage room.robot
      statuspage.parseWebhook(
        require('./fixtures/webhook_incident-ko.json'),
        'console'
      ).catch (error) ->
        expect(error).to.eql 'Error: invalid payload received'
# ---------------------------------------------------------------------------------------------
  context 'test the http responses', ->
    beforeEach ->
      room.robot.logger = sinon.spy()
      room.robot.logger.debug = sinon.spy()
      room.robot.logger.error = sinon.spy()
      room.robot.emit = sinon.spy()

    context 'with invalid payload', ->
      beforeEach (done) ->
        do nock.enableNetConnect
        options = {
          host: 'localhost',
          port: process.env.PORT,
          path: process.env.STATUSPAGE_ENDPOINT,
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          }
        }
        data = querystring.stringify({ })
        req = http.request options, (@response) => done()
        req.write('')
        req.end()
      it 'responds with status 422', ->
        expect(room.robot.logger.error)
          .callCount 1
        expect(@response.statusCode).to.equal 422

    context 'with valid component payload', ->
      beforeEach (done) ->
        do nock.enableNetConnect
        options = {
          host: 'localhost',
          port: process.env.PORT,
          path: process.env.STATUSPAGE_ENDPOINT,
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          }
        }
        data = require('./fixtures/webhook_component-ok.json')
        req = http.request options, (@response) => done()
        req.write(JSON.stringify(data))
        req.end()
      it 'responds with status 200', ->
        expect(room.robot.logger.error)
          .callCount 0
        expect(room.robot.emit)
          .callCount 1
        expect(@response.statusCode).to.equal 200

    context 'with valid incident payload', ->
      beforeEach (done) ->
        do nock.enableNetConnect
        options = {
          host: 'localhost',
          port: process.env.PORT,
          path: process.env.STATUSPAGE_ENDPOINT,
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          }
        }
        data = require('./fixtures/webhook_incident-ok.json')
        req = http.request options, (@response) => done()
        req.write(JSON.stringify(data))
        req.end()
      it 'responds with status 200', ->
        expect(room.robot.logger.error)
          .callCount 0
        expect(room.robot.emit)
          .callCount 1
        expect(@response.statusCode).to.equal 200
