#!/usr/bin/env bash

set -o errexit

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
                 VAULT_PASSWORD_FILE (optional)
                 [-h|--help]

Helper script for https://github.com/adnanh/webhook.

All arguments are positional!
  "
}

function init {
  [ ! -d /tmp/apexec ] && mkdir -p /tmp/apexec
  JOB_ID=$(pwgen 6 1)
  WORK_DIR=/tmp/apexec/${JOB_ID}
  PLAYBOOK_URL=${1}
  PLAYBOOK_FILE=${2}
  SSH_USER=${3}
  SLACK_TOKEN=${4}
  SLACK_CHANNEL=${5}
  VAULT_PASSWORD_FILE=${6}

  [ -z "${PLAYBOOK_URL}" ] && \
    echo "argument 'PLAYBOOK_URL' not set!" && \
    exit 1

  [ -z "${PLAYBOOK_FILE}" ] && \
    echo "argument 'PLAYBOOK_FILE' not set!" && \
    exit 1

  [ -z "${SSH_USER}" ] && \
    echo "argument 'SSH_USER' not set!" && \
    exit 1

  [ -n "${VAULT_PASSWORD_FILE}" ] && \
    VAULT_PASSWORD_FILE="--vault-password-file ${VAULT_PASSWORD_FILE}"

  PLAYBOOK_NAME=${PLAYBOOK_URL##*/}
  PLAYBOOK_NAME=${PLAYBOOK_NAME%.git}
}

function pull_playbook {
  git clone --recursive ${PLAYBOOK_URL} ${WORK_DIR}
  cd ${WORK_DIR}
}

function install_requirements {
  [ -f requirements.yml ] && ansible-galaxy install -r requirements.yml --force
}

function execute_ansible_playbook {
  ansible-playbook ${PLAYBOOK_FILE} --diff --extra-vars=ansible_user=${SSH_USER} ${VAULT_PASSWORD_FILE} &> /tmp/${PLAYBOOK_NAME}-${JOB_ID}.log
  cat /tmp/${PLAYBOOK_NAME}-${JOB_ID}.log
}

function send_notification {
  [ -z "${SLACK_TOKEN}" ] && \
    echo "argument 'SLACK_TOKEN' not set" && \
    return
  [ -z "${SLACK_CHANNEL}" ] && \
    echo "argument 'SLACK_TOKEN' not set" && \
    return

  summary=$(sed -n '/PLAY RECAP .*/ { :a; n; p; ba; }' /tmp/${PLAYBOOK_NAME}-${JOB_ID}.log | sed -r '/^\s*$/d')
  echo -e "PLAY RECAP:\n${summary}\n$(cat /tmp/${PLAYBOOK_NAME}-${JOB_ID}.log)" > /tmp/${PLAYBOOK_NAME}-${JOB_ID}.log
  curl -F file=@/tmp/${PLAYBOOK_NAME}-${JOB_ID}.log -F "initial_comment=Ansible Playbook execution: ${PLAYBOOK_NAME}" -F "channels=#${SLACK_CHANNEL}" -H "Authorization: Bearer ${SLACK_TOKEN}" https://slack.com/api/files.upload
}

function cleanup {
  rm -rf ${WORK_DIR}
}

function cmdfail {
  cleanup
  echo "failed to run script!"
  exit 1
}

((!$#)) && \
  echo "No arguments supplied!" && \
  show_help && \
  exit 1

[[ " $* " =~ " -h " ]] || [[ " $* " =~ " --help " ]] && \
  show_help && \
  exit 0

trap cmdfail ERR

init ${@}
pull_playbook
install_requirements
execute_ansible_playbook
send_notification
cleanup
