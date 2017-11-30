#!/usr/bin/python
import web
import json
import os
import sys
from pprint import pprint

urls = ('/.*', 'hooks')

app = web.application(urls, globals())

class hooks:
    def __init__(self):
        self.queue = []

    def POST(self):
        data = json.loads(web.data())
        sb=data['object_attributes']['source_branch']
        tb=data['object_attributes']['target_branch']
        n=data['object_attributes']['iid']
        state=data['object_attributes']['state']
        wip=data['object_attributes']['work_in_progress']        
        status=data['object_attributes']['merge_status']
        description=data['object_attributes']['description']
        title=data['object_attributes']['title']

        print
        print 'DATA RECEIVED:'
        print "--------------------------------"
        #pprint(data)
        print
        print "Merge request N: ", n
        print "Source branch:   ", sb 
        print "Target branch:   ", tb 
        print "State:           ", state 
        print "Work in progress:", wip 
        print "Title:           ", title 
        print "Description:     ", description 
        print "Merge status:    ", status 
        print "--------------------------------"

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
            cmd = "kinit -kt /home/efex/efex.keytab efex; /usr/bin/eosfusebind krb5; /bin/bash /home/efex/AutomationScripts/AutoLaunchRun.sh /home/efex/eFEXFirmware {0} {1} /mnt/vd/eFEX-revision /eos/user/e/efex/www/revision".format('master','Tested')
            # when pre merging use sb and tb here intead of master and Tested
            print "Executing {0}".format(cmd)
            os.system(cmd + "&")

        sys.stdout.flush()
        return 'OK'

        
    def AddSynth(self, from_branch, to_branch):
        print "Adding to queue: {0} {1}".format(from_branch, to_branch)
        self.queue.append((from_branch, to_branch))

if __name__ == '__main__':
    app.run()
