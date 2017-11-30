#!/usr/bin/python
import web
import json
from pprint import pprint

urls = ('/.*', 'hooks')

app = web.application(urls, globals())

class hooks:
    def __init__(self):
        self.queue = []

    def POST(self):
        data = json.loads(web.data())
        print
        print 'DATA RECEIVED:'
        print "--------------------------------"
        pprint(data)
        print
        print "--------------------------------"
        print "Merge commit SHA:", data['object_attributes']['merge_commit_sha']
        print "Merge request N: ", data['object_attributes']['iid']
        print "Source branch:   ", data['object_attributes']['source_branch']
        print "Target branch:   ", data['object_attributes']['target_branch']
        print "State:           ", data['object_attributes']['state']
        print "Work in progress:", data['object_attributes']['work_in_progress']
        print "Title:           ", data['object_attributes']['title']
        print "Description:     ", data['object_attributes']['description']
        print "Merge status:    ", data['object_attributes']['merge_status']

        self.AddSynth(data['object_attributes']['source_branch'], data['object_attributes']['target_branch'])
        return 'OK'
        
    def AddSynth(self, from_branch, to_branch):
        print "Adding to queue: {0} {1}".format(from_branch, to_branch)
        self.queue.append((from_branch, to_branch))

if __name__ == '__main__':
    app.run()
