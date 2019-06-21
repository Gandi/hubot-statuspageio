require('es6-promise').polyfill()

Helper = require('hubot-test-helper')
helper = new Helper('../scripts/statuspage_commands.coffee')

StatusPage = require '../lib/statuspage'
http = require('http')
nock = require('nock')
sinon = require('sinon')
chai = require('chai')
chai.use(require('sinon-chai'))
expect = chai.expect
querystring = require('querystring')
room = null



describe 'statuspage lib test', ->
  hubotHear = (message,userName = 'koko', tempo = 42) ->
    beforeEach (done) ->
      room.user.say userName, message
      setTimeout (done), tempo
  
  hubotResponse = (i = 1) ->
    room.messages[i]?[1]

  hubot = (message,userName = 'koko') ->
    hubotHear "@hubot #{message}", userName

  say = (command, cb) ->
    context "\"#{command}\"", ->
      hubot command
      cb()

  beforeEach ->
    process.env.STATUSPAGE_API_KEY = 'xxx'
    process.env.STATUSPAGE_PAGE_ID = 'xxx'
    room = helper.createRoom()
    room.robot.adaptaterName = 'console'
    room.robot.brain.userForId 'user', {
      name: 'user'
    }
    a= nock('https://api.statuspage.io')
    .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/incidents.json")
    .reply(200, require('./fixtures/incident_list-ok.json'))
  afterEach ->
    delete process.env.STATUSPAGE_API_KEY
    delete process.env.STATUSPAGE_PAGE_ID
    room.destroy()
  
  context 'list all current incident for a given page', ->
    it 'should answer', ->
      statuspage = new StatusPage room.robot
      statuspage.getIncidents()
      .then (announce) ->
        expect(announce).to.eql require('./fixtures/incident_list-ok.json')

  say 'sp', ->
    it 'replies with the incident list', ->
      expect(hubotResponse()).to.match /All good/
