# apexec

WORK IN PROGRESS

Script to use in combination with [webooks](https://github.com/adnanh/webhook)


## webhook example

```yaml
---
- id: apexc
  execute-command: "/opt/apexc/apexc.sh"
  response-message: Executing apexc script
  include-command-output-in-response: false
  pass-arguments-to-command:
    - source: payload  # PLAYBOOK_URL
      name: repository.git_http_url
    - source: string  # PLAYBOOK_FILE
      name: main.yaml
    - source: string  # SSH_USER
      name: {{ getenv "SSH_USER" }}
    - source: string  # SLACK_TOKEN
      name: {{ getenv "SLACK_TOKEN" }}
    - source: string  # SLACK_CHANNEL (without hashtag!)
      name: ansible
  trigger-rule:
    and:
      - match:
          type: payload-hash-sha1
          secret: {{ getenv "GITLAB_TOKEN" }}
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
