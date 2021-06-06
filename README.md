# apexec

WORK IN PROGRESS

Script to use in combination with [webhook](https://github.com/adnanh/webhook)

## Requirements

- [webhook](https://github.com/adnanh/webhook)
- Ansible Playbook
- GitLab
- git client
- Slack App (optional)
- [jq](https://github.com/stedolan/jq) (only if using Slack)
- curl (minimum version 7.67.0)

## webhook example

Create a dedicated Gitlab user for apexec and set it as maintainer for all necessary repositories.

### Gitlab webhooks: hooks.yaml

```yaml
---
- id: apexec
  execute-command: "/opt/apexec/apexec.sh"
  response-message: Executing apexec script
  include-command-output-in-response: false
  pass-arguments-to-command:
    - source: payload  # PLAYBOOK_URL
      name: repository.git_ssh_url
    - source: query  # PLAYBOOK_FILE
      name: playbook_file
    - source: query  # SSH_USER
      name: ssh_user
    - source: string  # SLACK_TOKEN
      name: <SLACK_WEBHOOK_URL>
    - source: query  # SLACK_CHANNEL (without hashtag!)
      name: slack_channel
    - source: query  # path to Ansible vault password file (optional)
      name: vault_password_file
  trigger-rule:
    and:
      - match:
          type: value
          value: <GITLAB_TOKEN>
          parameter:
            source: header
            name: X-Gitlab-Token
      - match:
          type: value
          value: refs/heads/master
          parameter:
            source: payload
            name: ref
```

### Gitlab webhook

Settings => Webhooks ==> add URL

```text
https://webhook.example.com/hooks/apexec?playbook_file=main.yml&ssh_user=ansible&slack_channel=ansible&vault_password_file=%2Fopt%2Fapexec%2Fansible-vault-pass
```

*ATTENTION**

If you are using a vault password file, you must encode the slashes with `%2F`

### Gitlab pipeline: hooks.yaml

```yaml
---
- id: apexec
  execute-command: "/opt/apexec/apexec.sh"
  response-message: Executing apexec script
  include-command-output-in-response: true
  pass-arguments-to-command:
    - source: payload  # PLAYBOOK_URL
      name: git_ssh_url
    - source: payload  # PLAYBOOK_FILE
      name: playbook_file
    - source: payload  # SSH_USER
      name: ssh_user
    - source: string  # SLACK_APP_TOKEN
      name: <SLACK_APP_TOKEN>
    - source: payload  # SLACK_CHANNEL (without hashtag!)
      name: slack_channel
    - source: payload  # path to Ansible vault password file (optional)
      name: vault_password_file
  trigger-rule:
    match:
      type: value
      value: <GITLAB_TOKEN>
      parameter:
        source: header
        name: WEBHOOK-TOKEN
```

### Gitlab pipeline

You can use wget:

```yaml
---
stages:
  - trigger-webhook

trigger-webhook:
  stage: trigger-webhook
  image: busybox:1.33.1
  script:
    - ssh_url=$(echo "${CI_REPOSITORY_URL}" | sed -r 's#(http.*://).*:.*@([^/]+)/(.+)$#git@\2:\3#g')
    - payload="git_ssh_url=${ssh_url}&playbook_file=${PLAYBOOK_FILE}&ssh_user=${SSH_USER}&slack_channel=${SLACK_CHANNEL}&vault_password_file=${VAULT_PASSWORD_FILE}"
    - echo "${payload}"
    - 'wget -O - --post-data "${payload}" --header "WEBHOOK-TOKEN: ${WEBHOOK_TOKEN}" ${WEBHOOK_URL}'
  only:
    - master
```

Or curl:

```yaml
---
stages:
  - trigger-webhook

trigger-webhook:
  stage: trigger-webhook
  image: busybox:1.33.1
  script:
    - ssh_url=$(echo "${CI_REPOSITORY_URL}" | sed -r 's#(http.*://).*:.*@([^/]+)/(.+)$#git@\2:\3#g')
    - payload="git_ssh_url=${ssh_url}&playbook_file=${PLAYBOOK_FILE}&ssh_user=${SSH_USER}&slack_channel=${SLACK_CHANNEL}&vault_password_file=${VAULT_PASSWORD_FILE}"
    - echo "${payload}"
    - 'curl --silent --show-error --request POST --data ${payload} --header "WEBHOOK-TOKEN: ${WEBHOOK_TOKEN}" ${WEBHOOK_URL}'
  only:
    - master
```

Add the following variables to the repository:

| variable            | description                                       | examle                                   |
|:--------------------|:--------------------------------------------------|:-----------------------------------------|
| PLAYBOOK_FILE       | name of playbook file                             | main.yml                                 |
| SSH_USER            | user for Ansible to connect to hosts              | my-ansible-user                          |
| SLACK_CHANNEL       | channel in Slack to upload Ansible output         | ansible                                  |
| VAULT_PASSWORD_FILE | path to file with password for ansible-vault      | /opt/apexec/ansible-password-file        |
| WEBHOOK_TOKEN       | user defined token to authenticate agains webhook | mysecretpassword                         |
| WEBHOOK_URL         | URL to webhook server with webhook-id             | https://webhook.example.com/hooks/apexec |

## Slack App

To receive Slack notifications you have to create a Slack App. Please refer to [this guide](https://github.com/slackapi/python-slackclient/blob/master/tutorial/01-creating-the-slack-app.md).
