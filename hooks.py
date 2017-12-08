#!/usr/bin/python
import web
import json
import os
import sys
import requests
import time
from pprint import pprint
from threading import Thread

head ={'PRIVATE-TOKEN': 'CbWF_XrjGbEGMssj9fkZ'}
urls = ('/.*', 'hooks')

app = web.application(urls, globals())
session = web.session.Session(app, web.session.DiskStore('/home/efex/sessions'))

def SendNote(msg, merge_request_number):
    print "Sending note: {0}".format(msg)
    sys.stdout.flush()
    note = requests.post("https://gitlab.cern.ch/api/v4/projects/atlas-l1calo-efex%2FeFEXFirmware/merge_requests/{0}/notes".format(merge_request_number), data={'body':msg}, headers=head)
    return note

def StartWorkflow(sb,tb,n):
    print "*******************************************"
    print "Launching run for merge request {0}".format(n)
    print "From: {0}   To: {1}".format(sb,tb)
    print "*******************************************"
    sys.stdout.flush()
    cmd="kinit -kt /home/efex/efex.keytab efex; /usr/bin/eosfusebind krb5; /bin/bash /home/efex/AutomationScripts/AutoLaunchRun.sh /home/efex/eFEXFirmware {0} {1} {2} /mnt/vd/eFEX-revision /eos/user/e/efex/www/revision".format(sb,tb,n)
    SendNote('This merge request matches all the required criteria, I shall launch the automatic work flow now.', n)
    print "Executing {0}".format(cmd)
    sys.stdout.flush()
    val = os.system(cmd) >> 8
    if val < 2:
        if val == 1:
            SendNote('This merge request does not modify any file that is revelant for any of the projects, so I shall approve it', n)
        else:
            SendNote('The automatic design flow was successful, so I shall approve this merge reqest', n)
        approve = requests.post("https://gitlab.cern.ch/api/v4/projects/atlas-l1calo-efex%2FeFEXFirmware/merge_requests/{0}/approve".format(n), headers=head)
    else:
        print "Auto launch run returned value {0}".format(val)
        SendNote('The automatic design flow have failed, so I am afraid I shall not be able to approve this merge reqest.', n)
    sys.stdout.flush()
        


class hooks:
    #def __init__(self):
    #    self.queue = []

    def POST(self):
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
        last_commit_author=data['object_attributes']['last_commit']['author']['name']
        action=data['object_attributes']['action']

        print
        print 'MERGE REQUEST RECEIVED:'
        print "--------------------------------"
        print
        print "Merge request N:     ", n
        print "Source branch:       ", sb 
        print "Target branch:       ", tb 
        print "State:               ", state 
        print "Work in progress:    ", wip 
        print "Title:               ", title 
        print "Description:         ", description 
        print "Last commit author:  ", last_commit_author 
        print "Action:              ", action
        time.sleep(1)
        u = requests.get(url, headers=head)
        time.sleep(1)
        r = requests.get("https://gitlab.cern.ch/api/v4/projects/atlas-l1calo-efex%2FeFEXFirmware/merge_requests/{0}".format(n), headers=head)
        data_web=json.loads(r.text)
        status=data_web['merge_status']
        print "Merge status:        ", status 
        print "--------------------------------"
        sys.stdout.flush()
        #pprint(data_web)
        if status == 'can_be_merged' and tb == 'master' and state == 'opened' and last_commit_author != 'efex' and action != 'approved' and not wip:
            thread = Thread(target = StartWorkflow, args = (sb,tb,n))
            thread.start()
        return 'OK'

if __name__ == '__main__':
    app.run()
