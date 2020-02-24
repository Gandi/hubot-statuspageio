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



describe 'statuspage script test', ->
  hubotHear = (message, userName = 'koko', tempo = 42) ->
    beforeEach (done) ->
      room.user.say userName, message
      setTimeout (done), tempo
  
  hubotResponse = (i = 1) ->
    room.messages[i]?[1]

  hubot = (message, userName = 'koko') ->
    hubotHear "@hubot #{message}", userName

  say = (command, cb) ->
    context "\"#{command}\"", ->
      hubot command
      cb()
  beforeEach ->
    process.env.STATUSPAGE_API_KEY = 'xxx'
    process.env.STATUSPAGE_PAGE_ID = 'xxx'
    process.env.STATUSPAGE_LOG_PATH = 'statuspage.log'
    process.env.STATUSPAGE_ANNOUNCE_ROOM = 'console'
    room = helper.createRoom()
    room.robot.adapterName = 'console'
    room.robot.brain.userForId 'user', {
      name: 'user'
    }
  afterEach ->
    delete process.env.STATUSPAGE_API_KEY
    delete process.env.STATUSPAGE_PAGE_ID
    room.robot.brain.statuspage = { }
    room.destroy()
    nock.cleanAll()

#------------------------------------------------------------------------------
  describe 'the environment is not setup', ->
    context 'the api key is not setup', ->
      beforeEach ->
        delete process.env.STATUSPAGE_API_KEY
      say 'sp', ->
        it 'returns an explicit error', ->
          expect(hubotResponse()).to.eql 'Error: STATUSPAGE_API_KEY is not set in your environment.'

 
    context 'the api_version is not setup', ->
      beforeEach ->
        delete process.env.STATUSPAGE_PAGE_ID
      say 'sp', ->
        it 'returns an explicit error', ->
          expect(hubotResponse()).to.eql 'Error: STATUSPAGE_PAGE_ID is not set in your environment.'
               

  say 'sp version', ->
    it 'should give the version number', ->
      expect(hubotResponse()).to.match /hubot-statuspage is version [0-9]+\.[0-9]+\.[0-9]+/

#------------------------------------------------------------------------------
  describe 'list all current incident for a given page', ->
    context 'when there is no incident', ->
      beforeEach ->
        a = nock('https://api.statuspage.io')
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/incidents/unresolved")
        .reply(200, require('./fixtures/incident_list-empty-ok.json'))
      say 'sp', ->
        it 'replies with no incident', ->
          expect(hubotResponse()).to.eql 'There is no unresolved incident'
    context 'when there are incidents', ->
      beforeEach ->
        a = nock('https://api.statuspage.io')
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/incidents/unresolved")
        .reply(200, require('./fixtures/incident_list-ok.json'))
      say 'sp', ->
        it 'replies with the incident list', ->
          expect(hubotResponse()).to.eql '[ljk51ph6s12d - critical] {}' +
          ' : Data Layer Migration - scheduled'

#----

    context 'when there is something wrong', ->
      beforeEach ->
        a = nock('https://api.statuspage.io')
        a.get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/incidents/unresolved")
        .reply(404, require('./fixtures/incident_ko.json'))
      say 'sp', ->
        it 'replies with the error message', ->
          expect(hubotResponse()).to.eql 'Error: 404 Incident not found'
    context 'when there is something wrong with the request', ->
      beforeEach ->
        a = nock('https://api.statuspage.io')
        a.get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/incidents/unresolved")
        .reply(404, require('./fixtures/incident_ko.json'))
      say 'sp', ->
        it 'replies with the error message', ->
          expect(hubotResponse()).to.match /Error: (.*)/

#------------------------------------------------------------------------------
  describe 'list all current maintenance for a given page', ->
    context 'when there is no maintenance', ->
      beforeEach ->
        a = nock('https://api.statuspage.io')
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/incidents/active_maintenance")
        .reply(200, require('./fixtures/incident_list-empty-ok.json'))
      say 'sp main', ->
        it 'replies with no incident', ->
          expect(hubotResponse()).to.eql 'There is no active maintenance'
    context 'when there are maintenance', ->
      beforeEach ->
        a = nock('https://api.statuspage.io')
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/incidents/active_maintenance")
        .reply(200, require('./fixtures/incident_list-ok.json'))
      say 'sp main', ->
        it 'replies with the maintenance list', ->
          expect(hubotResponse()).to.eql '[ljk51ph6s12d - critical] {}' +
          ' : Data Layer Migration - scheduled'

#----

    context 'when there is something wrong', ->
      beforeEach ->
        a = nock('https://api.statuspage.io')
        a.get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/incidents/active_maintenance")
        .reply(404, require('./fixtures/incident_ko.json'))
      say 'sp maintenance', ->
        it 'replies with the error message', ->
          expect(hubotResponse()).to.eql 'Error: 404 Incident not found'
 
#------------------------------------------------------------------------------
  describe 'changing the state of an incident', ->
    context 'when everything goes right', ->
      beforeEach ->
        a = nock('https://api.statuspage.io')
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/incidents/2")
        .reply(200, require('./fixtures/incident_update-ok.json'))
        .put("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/incidents/2.json")
        .reply(200, require('./fixtures/incident_update-ok.json'))
      say 'sp set 2 ID', ->
        it 'replies with the update incident', ->
          expect(hubotResponse()).to.eql '[1y9p5smwzhyf - critical] {component1}' +
          ' : Data Layer Migration - scheduled\n' +
          ' update details - Wed 07:51'
      say 'sp set 2 MON', ->
        it 'replies with the update incident', ->
          expect(hubotResponse()).to.eql '[1y9p5smwzhyf - critical] {component1}' +
          ' : Data Layer Migration - scheduled\n' +
          ' update details - Wed 07:51'
      say 'sp set 2 RES + all good', ->
        it 'replies with the update incident', ->
          expect(hubotResponse()).to.eql '[1y9p5smwzhyf - critical] {component1}' +
          ' : Data Layer Migration - scheduled\n' +
          ' update details - Wed 07:51'

#----

    context 'when something is wrong', ->
      beforeEach ->
        a = nock('https://api.statuspage.io')
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/incidents/1")
        .reply(200, require('./fixtures/incident_update-ok.json'))
        .put("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/incidents/1.json")
        .reply(404, require('./fixtures/incident_ko.json'))
      say 'sp set 1 ID', ->
        it 'replies with the error message', ->
          expect(hubotResponse()).to.match  /Error: 404 Incident not found/
 
#------------------------------------------------------------------------------
  describe 'adding a comment to an incident', ->
    context 'when everything goes right', ->
      beforeEach ->
        a = nock('https://api.statuspage.io')
        .put("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/incidents/2.json")
        .reply(200, require('./fixtures/incident_update-ok.json'))
    
      say 'sp 2 + things are getting better', ->
        it 'replies with the update incident', ->
          expect(hubotResponse()).to.eql '[1y9p5smwzhyf - critical] {component1}' +
          ' : Data Layer Migration - scheduled\n' +
          ' update details - Wed 07:51'
 
#----

    context 'when something is wrong', ->
      beforeEach ->
        a = nock('https://api.statuspage.io')
        .put("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/incidents/3.json")
        .reply(404, require('./fixtures/incident_ko.json'))
      say 'sp 3 + things are getting better', ->
        it 'replies with the error message', ->
          expect(hubotResponse()).to.match  /Error: 404 Incident not found/
  
#------------------------------------------------------------------------------
  describe 'changing the impact of an incident', ->
    context 'when everything goes right', ->
      beforeEach ->
        a = nock('https://api.statuspage.io')
        .put("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/incidents/2.json")
        .reply(200, require('./fixtures/incident_update-ok.json'))
      say 'sp 2 is none', ->
        it 'replies with the update incident', ->
          expect(hubotResponse()).to.eql '[1y9p5smwzhyf - critical] {component1}' +
          ' : Data Layer Migration - scheduled\n' +
          ' update details - Wed 07:51'
      say 'sp 2 is minor', ->
        it 'replies with the update incident', ->
          expect(hubotResponse()).to.eql '[1y9p5smwzhyf - critical] {component1}' +
          ' : Data Layer Migration - scheduled\n' +
          ' update details - Wed 07:51'
      say 'sp 2 is major', ->
        it 'replies with the update incident', ->
          expect(hubotResponse()).to.eql '[1y9p5smwzhyf - critical] {component1}' +
          ' : Data Layer Migration - scheduled\n' +
          ' update details - Wed 07:51'
      say 'sp 2 is critical', ->
        it 'replies with the update incident', ->
          expect(hubotResponse()).to.eql '[1y9p5smwzhyf - critical] {component1}' +
          ' : Data Layer Migration - scheduled\n' +
          ' update details - Wed 07:51'

#----

    context 'when something is wrong', ->
      beforeEach ->
        a = nock('https://api.statuspage.io')
        .put("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/incidents/3.json")
        .reply(404, require('./fixtures/incident_ko.json'))
      say 'sp 3 is things', ->
        it 'replies with the error message', ->
          expect(hubotResponse()).to.eql 'unknown impact things'
      say 'sp 3 is none', ->
        it 'replies with the error message', ->
          expect(hubotResponse()).to.match  /Error: 404 Incident not found/

 #-----------------------------------------------------------------------------
  describe 'list all component', ->
    beforeEach ->
      room.robot.brain.data = {
        'statuspage': {
          'components': { }
        }
      }
    context 'when you give a component', ->
      beforeEach ->
        a = nock('https://api.statuspage.io')
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/components")
        .reply(200, require('./fixtures/component_list-ok.json'))
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/components/1")
        .reply(200, require('./fixtures/component_detail_1-ok.json'))
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/components/2")
        .reply(200, require('./fixtures/component_detail_nested-ok.json'))
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/components/1")
        .reply(200, require('./fixtures/component_detail_1-ok.json'))
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/components/3")
        .reply(200, require('./fixtures/component_detail_3-ok.json'))
      say 'sp co component1', ->
        it 'replies with the details of the component', ->
          expect(hubotResponse()).to.eql '[operational] component1 component description - 1'
      say 'sp co component2', ->
        it 'replies with nested component', ->
          expect(hubotResponse()).to.eql ' component2 string - 2'
   
    context 'when the component id is known', ->
      beforeEach ->
        room.robot.brain.data = {
          'statuspage': {
            'components': {
              'component1': 'id'
            }
          }
        }
        a = nock('https://api.statuspage.io')
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/components/id")
        .reply(200, require('./fixtures/component_detail_1-ok.json'))
      say 'sp co component1', ->
        it 'replies with the component info', ->
          expect(hubotResponse()).to.eql '[operational] component1 component description - 1'
          
    context 'when there is no component given', ->
      beforeEach ->
        a = nock('https://api.statuspage.io')
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/components")
        .reply(200, require('./fixtures/component_list-ok.json'))
      say 'sp co', ->
        it 'replies with the component list', ->
          expect(hubotResponse()).to.eql '[operational] component1'


#----

    context 'when there is something wrong with the server', ->
      beforeEach ->
        a = nock('https://api.statuspage.io')
        a.get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/components")
        .reply(404, require('./fixtures/incident_ko.json'))
      say 'sp co', ->
        it 'replies with the error message', ->
          expect(hubotResponse()).to.eql 'Error: 404 Incident not found'
      say 'sp co co', ->
        it 'replies with the error message', ->
          expect(hubotResponse()).to.eql 'Error: 404 Incident not found'

    context 'when there is no components', ->
      beforeEach ->
        a = nock('https://api.statuspage.io')
        a.get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/components")
        .reply(404, require('./fixtures/component_list-empty.json'))
      say 'sp co', ->
        it 'replies with the error message', ->
          expect(hubotResponse()).to.eql 'No component found'
      say 'sp co co', ->
        it 'replies with the error message', ->
          expect(hubotResponse()).to.eql 'Error: unknown component co'



#------------------------------------------------------------------------------
  describe 'create a new incident', ->
    beforeEach ->
      room.robot.brain.data = {
        'statuspage': {
          'components': { }
        }
      }

    context 'when everything is right', ->
      beforeEach ->
        a = nock('https://api.statuspage.io')
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/incident_templates")
        .reply(200, require('./fixtures/template_list-ok.json'))
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/components")
        .reply(200, require('./fixtures/component_list-ok.json'))
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/components/1")
        .reply(200, require('./fixtures/component_detail_1-ok.json'))
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/components/3")
        .reply(200, require('./fixtures/component_detail_3-ok.json'))
        .post("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/incidents")
        .query({
          'incident': {
            'id': 'sv3vlf40dfzp',
            'name': 'stemplatename',
            'title': 'templatetitle',
            'body': 'template body',
            'group_id': '13nc3tpps3hx',
            'update_status': 'investigating',
            'should_tweet': true,
            'should_send_notifications': true,
            'components': {
              '1': 'holiday'
            },
            'component_ids': [
              '1'
            ]
          }
        })
        .reply(200, require('./fixtures/incident_new-ok.json'))
      say 'sp new templatename on component2:critical', ->
        it 'replies with the created incident', ->
          expect(hubotResponse()).to.eql '[yyyyyyyyyyy - critical] {component2}' +
          ' : Data Layer Migration - scheduled'

#----

    context 'when the component is wrong', ->
      beforeEach ->
        a = nock('https://api.statuspage.io')
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/components")
        .reply(200, require('./fixtures/component_list-ok.json'))
      say 'sp new templatename on wrongcomponent:critical', ->
        it 'replies with the created incident', ->
          expect(hubotResponse()).to.eql 'Error: unknown component wrongcomponent'
  
    context 'when there is an error in template name', ->
      beforeEach ->
        a = nock('https://api.statuspage.io')
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/incident_templates")
        .reply(200, require('./fixtures/template_list-ok.json'))
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/components")
        .reply(200, require('./fixtures/component_list-ok.json'))
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/components/3")
        .reply(200, require('./fixtures/component_detail_3-ok.json'))
 
      say 'sp new wrongtemplate on component3:critical', ->
        it 'it replies with the error', ->
          expect(hubotResponse()).to.eql 'Error: no matching template found'
 
    context 'when there is an error with template name', ->
      beforeEach ->
        a = nock('https://api.statuspage.io')
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/incident_templates")
        .reply(200, require('./fixtures/template_list-ok.json'))
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/components")
        .reply(200, require('./fixtures/component_list-ok.json'))
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/components/1")
        .reply(200, require('./fixtures/component_detail_1-ok.json'))
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/components/3")
        .reply(200, require('./fixtures/component_detail_3-ok.json'))
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/components")
        .reply(200, require('./fixtures/component_list-ok.json'))
 
      say 'sp new t on component3:critical', ->
        it 'it replies with the error', ->
          expect(hubotResponse()).to.eql 'Error: too many matching templates'

    context 'when there is an error with component', ->
      beforeEach ->
        a = nock('https://api.statuspage.io')
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/components")
        .reply(200, require('./fixtures/component_list-ok.json'))
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/components/1")
        .reply(200, require('./fixtures/component_detail_1-ok.json'))
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/components/2")
        .reply(200, require('./fixtures/component_detail_nested-ok.json'))
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/components/3")
        .reply(200, require('./fixtures/component_detail_3-ok.json'))
      say 'sp new template on component:critical', ->
        it 'it replies with the error', ->
          expect(hubotResponse()).to.eql 'Error: too many matching components'


    context 'when there is something wrong server side', ->
      beforeEach ->
        a = nock('https://api.statuspage.io')
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/components")
        .reply(200, require('./fixtures/component_list-ok.json'))
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/components/1")
        .reply(200, require('./fixtures/component_detail_1-ok.json'))
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/components/3")
        .reply(200, require('./fixtures/component_detail_3-ok.json'))
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/incident_templates")
        .reply(404, require('./fixtures/incident_ko.json'))

      say 'sp new templatename on component3:critical', ->
        it 'replies with the error message', ->
          expect(hubotResponse()).to.eql 'Error: 404 Incident not found'
 

#------------------------------------------------------------------------------
  describe 'give details about an incident', ->
    context 'when there is an incident', ->
      beforeEach ->
        a = nock('https://api.statuspage.io')
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/incidents/1")
        .reply(200, require('./fixtures/incident_detail-ok.json'))
      say 'sp inc 1', ->
        it 'replies with no incident', ->
          expect(hubotResponse()).to.eql '[yyyyyyyyyyy - critical] {component1}'+
          ' : Data Layer Migration - scheduled\n' +
          ' update details - Wed 07:51'
#----

    context 'when something is wrong', ->
      beforeEach ->
        a = nock('https://api.statuspage.io')
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/incidents/4")
        .reply(404, require('./fixtures/incident_ko.json'))
      say 'sp inc 4', ->
        it 'replies with no incident', ->
          expect(hubotResponse()).to.eql 'Error: 404 Incident not found'


#------------------------------------------------------------------------------
  describe 'update the status of a component', ->
    context 'when everything goes right', ->
      beforeEach ->
        room.robot.brain.data.statuspage.components = { 'component1': 1 }
        a = nock('https://api.statuspage.io')
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/components/1")
        .reply(200, require('./fixtures/component_detail_1-ok.json'))
        .put("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/components/1")
        .reply(200, require('./fixtures/component_detail_1-ok.json'))
      say 'sp comp component1 is deg', ->
        it 'replies with a confirmation', ->
          expect(hubotResponse()).to.eql 'Update sent'
      say 'sp comp component1 is op', ->
        it 'replies with a confirmation', ->
          expect(hubotResponse()).to.eql 'Update sent'
      say 'sp comp component1 is part', ->
        it 'replies with a confirmation', ->
          expect(hubotResponse()).to.eql 'Update sent'
      say 'sp comp component1 is maj', ->
        it 'replies with a confirmation', ->
          expect(hubotResponse()).to.eql 'Update sent'
      say 'sp comp component1 is maintenance', ->
        it 'replies with a confirmation', ->
          expect(hubotResponse()).to.eql 'Update sent'
#---
    context 'when something goes wrong with a component', ->
      beforeEach ->
        room.robot.brain.data.statuspage = { }
        room.robot.brain.data.statuspage.components = { }
        a = nock('https://api.statuspage.io')
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/components")
        .reply(200, require('./fixtures/component_list-ok.json'))
        .put("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/components/1")
        .reply(200, require('./fixtures/component_detail_1-ok.json'))
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/components")
        .reply(200, require('./fixtures/component_list-ok.json'))
      say 'sp comp component1,component5 is maintenance', ->
        it 'replies with an accurate error', ->
          expect(hubotResponse()).to.eql 'Unable to update Error: unknown component component5'
    context 'when something goes wrong with the update', ->
      beforeEach ->
        room.robot.brain.data.statuspage = { }
        room.robot.brain.data.statuspage.components = { }
        a = nock('https://api.statuspage.io')
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/components")
        .reply(200, require('./fixtures/component_list-ok.json'))
        .put("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/components/1")
        .reply(500, 'internal server error')
      say 'sp comp component1 is maintenance', ->
        it 'replies with an accurate error', ->
          expect(hubotResponse()).to.match /Unable to update SyntaxError.*/



#------------------------------------------------------------------------------
  describe 'list available templates', ->
    beforeEach ->
      room.robot.brain.data = {
        'statuspage': {
          'components': { }
        }
      }

    context 'when everything is right', ->
      beforeEach ->
        a = nock('https://api.statuspage.io')
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/incident_templates")
        .reply(200, require('./fixtures/template_list-ok.json'))
      say 'sp t', ->
        it 'replies with the list of templates', ->
          expect(hubotResponse()).to.eql '[stemplatename] templatetitle'
      say 'sp t templatename', ->
        it 'replies with the list of templates', ->
          expect(hubotResponse()).to.eql '[stemplatename] templatetitle : template body'

#---
    context 'when something is wrong because of the server', ->
      beforeEach ->
        a = nock('https://api.statuspage.io')
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/incident_templates")
        .reply(404, require('./fixtures/incident_ko.json'))
      say 'sp t', ->
        it 'replies with the error message', ->
          expect(hubotResponse()).to.eql 'Error: 404 Incident not found'
    context 'when there is no templates', ->
      beforeEach ->
        a = nock('https://api.statuspage.io')
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/incident_templates")
        .reply(404, require('./fixtures/template_list-empty.json'))
      say 'sp t', ->
        it 'replies with a clear message', ->
          expect(hubotResponse()).to.eql 'Error: no template found'
    context 'when there is no matching template', ->
      beforeEach ->
        a = nock('https://api.statuspage.io')
        .get("/v1/pages/#{process.env.STATUSPAGE_PAGE_ID}/incident_templates")
        .reply(404, require('./fixtures/template_list-ok.json'))
      say 'sp t oazihdozaihd', ->
        it 'replies with a clear message', ->
          expect(hubotResponse()).to.eql 'Error: no matching template found'
