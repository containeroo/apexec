# apexec

WORK IN PROGRESS

Script to use in combination with [webooks](https://github.com/adnanh/webhook)

## webhook example

Create a dedicated Gitlab user for apexec and set it as maintainer for all necessary repositories.

### hooks.yaml

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

### gitlab

Settings => Webhooks ==> add URL

```
https://webhook.example.com/hooks/apexec?playbook_file=main.yml&ssh_user=ansible&slack_channel=ansible
```
