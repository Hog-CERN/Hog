# Copyright https://gitlab.com/gitlab-gold/tpoffenbarger/intermingle/dynamic-pipelines

import json
import sys

import requests
from envparse import Env, ConfigurationError
import os
from zipfile import ZipFile, BadZipFile

env = Env()
if not os.path.isfile('.env'):
    print('You must save a .env file as an upstream artifact '
          'containing the Child Pipeline Creator\'s Job ID as: CREATE_JOB_ID')
    # exit(1)
else:
    env.read_envfile()

KEY_DESCRIPTIONS = {
    'CREATE_JOB_ID':
    ("The CREATE_JOB_ID key is missing and is used to identify "
     "any job that ran after the job that triggered the job artifacts. "
     "Please create a .env by running `'echo CREATE_JOB_ID=${CREATE_JOB_ID} > .env'` "
     "in the script section of a job that precedes trigger: job for your child pipelines. "
     "The `.env` file will need to be saved as an artifact. "),
    'HOG_PUSH_TOKEN':
    ("Please save your Personal Access Token as a HOG_PUSH_TOKEN variable in your CI/CD "
     "Settings for the project, as this is needed to use the API to find child pipeline "
     "jobs and download artifacts.")
}


def get_response(url, headers):
    response = requests.get(url, headers=headers)
    if not response.ok:
        generic_message = 'Invalid response from GitLab'
        try:
            generic_message = response.json().get('message', generic_message)
        except json.decoder.JSONDecodeError:
            pass
        sys.stderr.write(generic_message + '\n')
        exit(1)
    return response.json()


def download_file(dl_url, headers, job_id):
    sys.stdout.write('Downloading artifacts for child job at:' + str(dl_url) +
                     '\n')
    sys.stdout.flush()
    downloaded = requests.get(dl_url, headers=headers, allow_redirects=True)
    if not downloaded.ok:
        sys.stderr.write("Failed to download a file. Cancelling rest of job." +
                         '\n')
        exit(1)

    path_to_zip = os.path.join('jobs', f'{job_id}.zip')
    with open(path_to_zip, 'wb') as f:
        f.write(downloaded.content)
    try:
        with ZipFile(path_to_zip, 'r') as zip_ref:
            zip_ref.extractall('jobs')
        os.remove(path_to_zip)
    except BadZipFile:
        sys.stderr.write('Cannot find file at:' + str(path_to_zip) + '\n')
        sys.stderr.flush()


def main():
    """
    download artifacts and place them in the jobs directory
    """
    v4_origin = 'https://gitlab.com/api/v4'
    project_id = env("CI_PROJECT_ID")
    commit_sha = env("CI_COMMIT_SHA")
    headers = {'PRIVATE-TOKEN': env('HOG_PUSH_TOKEN')}

    page = 1
    page_url = f'{v4_origin}/projects/{project_id}/jobs/?page={page}'
    parent_pipeline_id = env('PARENT_PIPELINE_ID', default=None)
    if parent_pipeline_id:
        page_url = f'{v4_origin}/projects/{project_id}/pipelines/{parent_pipeline_id}/jobs/?page={page}'
    json_response = get_response(page_url, headers)

    while json_response:

        create_job_id = env('CREATE_JOB_ID', cast=int, default=-1)

        for job in json_response:
            job_with_artifacts = [
                x for x in job.get('artifacts', [])
                if x.get('file_type', '') == 'archive'
            ]

            if not job_with_artifacts:
                continue
            if job['commit']['id'] != commit_sha:
                continue
            if not parent_pipeline_id and int(job['id']) <= create_job_id:
                return

            dl_url = f'{v4_origin}/projects/{project_id}/jobs/{job["id"]}/artifacts/'
            download_file(dl_url, headers, job_id=job["id"])

        page += 1
        page_url = f'{v4_origin}/projects/{project_id}/jobs/?page={page}'
        if parent_pipeline_id:
            page_url = f'{v4_origin}/projects/{project_id}/pipelines/{parent_pipeline_id}/jobs/?page={page}'
        json_response = get_response(page_url, headers)


if __name__ == '__main__':
    try:
        main()
    except ConfigurationError as e:
        try:
            sys.stderr.write(KEY_DESCRIPTIONS[e.args[0].split("'")[1:-1][0]] +
                             '\n')
        except (IndexError, KeyError):
            sys.stderr.write(str(e) + '\n')
        exit(5)
