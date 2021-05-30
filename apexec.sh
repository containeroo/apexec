#!/usr/bin/env bash

[ ! -x "$(command -v pwgen)" ] && \
  echo "pwgen not found!" && \
  exit 1

function show_help {
  echo "
Usage: apexec.sh PLAYBOOK_URL
                 PLAYBOOK_FILE
                 SSH_USER
                 SLACK_TOKEN
                 SLACK_CHANNEL
                 [-h|--help]

Helper script for https://github.com/adnanh/webhook.

All arguments are positional arguments!
  "
  exit 0
}

function init {
  ((!$#)) && \
    echo "No arguments supplied!" && \
    exit 1

  [ ! -d /tmp/apexec ] && mkdir -p /tmp/apexec
  WORK_DIR="/tmp/apexec/$(pwgen 6 1)"
  PLAYBOOK_URL=${1}
  PLAYBOOK_FILE=${2}
  SSH_USER=${3}
  SLACK_TOKEN=${4}
  SLACK_CHANNEL=${5}

  [ -z "${PLAYBOOK_URL}" ] && \
    echo "environment variable 'PLAYBOOK_URL' not set!" && \
    exit 1

  [ -z "${PLAYBOOK_FILE}" ] && \
    echo "environment variable 'PLAYBOOK_FILE' not set!" && \
    exit 1

  [ -z "${SSH_USER}" ] && \
    echo "environment variable 'SSH_USER' not set!" && \
    exit 1
}

function pull_playbook {
  git clone --recursive ${PLAYBOOK_URL} ${WORK_DIR}
  cd ${WORK_DIR}
}

function install_requirements {
  [ -f requirements.yml ] && ansible-galaxy install -r requirements.yml --force
}

function execute_ansible_playbook {
  ansible-playbook ${PLAYBOOK_FILE} --diff --extra-vars=ansible_user=${SSH_USER} --vault-password-file ~/tmp/ansible-vault-pass &> log.txt
}

function send_notification {
  [ -z "${SLACK_TOKEN}" ] && \
    echo "environment variable 'SLACK_TOKEN' not set" && \
    return
  [ -z "${SLACK_CHANNEL}" ] && \
    echo "environment variable 'SLACK_TOKEN' not set" && \
    return

  summary=$(sed -n '/PLAY RECAP .*/ { :a; n; p; ba; }' log.txt | sed -r '/^\s*$/d')
  playbook_name=${PLAYBOOK_URL##*/}
  playbook_name=${playbook_name%.git}
  echo -e "PLAY RECAP:\n${summary}\n$(cat log.txt)" > log.txt
  curl -F file=@log.txt -F "initial_comment=Ansible Playbook execution: ${playbook_name}" -F "channels=#${SLACK_CHANNEL}" -H "Authorization: Bearer ${SLACK_TOKEN}" https://slack.com/api/files.upload
}

function cleanup {
  rm -rf ${WORK_DIR}
}


[[ " $* " =~ " -h " ]] || [[ " $* " =~ " --help " ]] && \
  show_help

init ${1} ${2} ${3} ${4} ${5}
pull_playbook
install_requirements
execute_ansible_playbook
send_notification
cleanup
