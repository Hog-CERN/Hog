#!/usr/bin/python
import web
import json
import os
import sys
import requests
import time
from pprint import pprint

urls = ('/.*', 'hooks')

app = web.application(urls, globals())

class hooks:
    def __init__(self):
        self.queue = []

    def POST(self):
        #request webpage here!!
        data = json.loads(web.data())
        #pprint(data)
        sb=data['object_attributes']['source_branch']
        tb=data['object_attributes']['target_branch']
        state=data['object_attributes']['state']
        wip=data['object_attributes']['work_in_progress']        
        description=data['object_attributes']['description']
        title=data['object_attributes']['title']
        n=data['object_attributes']['iid']
        url=data['object_attributes']['url']
        print
        print 'MERGE REQUEST RECEIVED:'
        print "--------------------------------"
        print
        print "Merge request N: ", n
        print "Source branch:   ", sb 
        print "Target branch:   ", tb 
        print "State:           ", state 
        print "Work in progress:", wip 
        print "Title:           ", title 
        print "Description:     ", description 
        time.sleep(1)
        u = requests.get(url, headers={'PRIVATE-TOKEN': 'CbWF_XrjGbEGMssj9fkZ'})
        time.sleep(1)
        r = requests.get("https://gitlab.cern.ch/api/v4/projects/atlas-l1calo-efex%2FeFEXFirmware/merge_requests/{0}".format(n), headers={'PRIVATE-TOKEN': 'CbWF_XrjGbEGMssj9fkZ'})
        data_web=json.loads(r.text)
        status=data_web['merge_status']
        print "Merge status:    ", status 
        print "--------------------------------"
        #pprint(data_web)
        n = requests.get(url, headers={'PRIVATE-TOKEN': 'CbWF_XrjGbEGMssj9fkZ'})

        # For pre merging test use
        #if status == 'can_be_merged' and state == 'opened' and not wip:
        if status == 'can_be_merged' and tb == 'master' and state == 'merged' and not wip:
            print "*******************************************"
            print "Launching run for merge request {0}".format(n)
            print "From: {0}   To: {1}".format(sb,tb)
            print "Title: {0}".format(title)
            print 
            print "Description: "
            print description
            print
            print "*******************************************"
            cmd = "kinit -kt /home/efex/efex.keytab efex; /usr/bin/eosfusebind krb5; /bin/bash /home/efex/AutomationScripts/AutoLaunchRun.sh /home/efex/eFEXFirmware {0} {1} /mnt/vd/eFEX-revision /eos/user/e/efex/www/revision".format('master',n)
            # when pre merging use sb and tb here intead of master and Tested
            message="Launching automatic work flow"
            u = requests.post("https://gitlab.cern.ch/api/v4/projects/atlas-l1calo-efex%2FeFEXFirmware/merge_requests/{0}/notes".format(n), data={'body':message}, headers={'PRIVATE-TOKEN': 'CbWF_XrjGbEGMssj9fkZ'})
            print "Executing {0}".format(cmd)
            os.system(cmd + "&")

        sys.stdout.flush()
        return 'OK'

        
    def AddSynth(self, from_branch, to_branch):
        print "Adding to queue: {0} {1}".format(from_branch, to_branch)
        self.queue.append((from_branch, to_branch))

if __name__ == '__main__':
    app.run()
