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
                 VAULT_PASSWORD_FILE (optional)
                 ANSIBLE_EXTRA_ARGS (optional)
                 [-h|--help]

Ansible playbook execution script for https://github.com/adnanh/webhook.

All arguments are positional!"
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
  ANSIBLE_EXTRA_ARGS=${7}

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
    VAULT_PASSWORD_FILE="--vault-password-file=${VAULT_PASSWORD_FILE}"

  PLAYBOOK_NAME=${PLAYBOOK_URL##*/}
  PLAYBOOK_NAME=${PLAYBOOK_NAME%.git}
  LOG_FILE="/tmp/${PLAYBOOK_NAME}-${JOB_ID}.log"
}

function pull_playbook {
  git clone --recursive "${PLAYBOOK_URL}" "${WORK_DIR}"
  cd "${WORK_DIR}" || return
}

function install_requirements {
  [ -f requirements.yml ] && ansible-galaxy install -r requirements.yml --force
}

function execute_ansible_playbook {
  ansible-playbook "${PLAYBOOK_FILE}" --diff "${ANSIBLE_EXTRA_ARGS}" --extra-vars=ansible_user="${SSH_USER}" "${VAULT_PASSWORD_FILE}" &> "${LOG_FILE}"
  cat "${LOG_FILE}"
}

function send_notification {
  [ -z "${SLACK_TOKEN}" ] && \
    echo "argument 'SLACK_TOKEN' not set" && \
    return
  [ -z "${SLACK_CHANNEL}" ] && \
    echo "argument 'SLACK_TOKEN' not set" && \
    return

  [ ! -f "${LOG_FILE}" ] && \
    echo "cannot send Slack notification. File '${LOG_FILE}' not found!" && \
    return

  grep --quiet "failed=0" "${LOG_FILE}" || ERROR_MSG=" failed"
  grep --quiet "unreachable=0" "${LOG_FILE}" || ERROR_MSG=" failed"

  response=$(curl \
                  --silent \
                  --show-error \
                  --no-progress-meter \
                  --form file=@"${LOG_FILE}" \
                  --form "initial_comment=Ansible Playbook execution${ERROR_MSG}: ${PLAYBOOK_NAME}" \
                  --form "channels=#${SLACK_CHANNEL}" \
                  --header "Authorization: Bearer ${SLACK_TOKEN}" \
                  https://slack.com/api/files.upload)

  [ $(jq .ok? <<< "$response") == true ] && \
    echo "Slack notification successfully send" || \
    echo "Error sending Slack notification. $(jq -r <<< "$response")"
}

function cleanup {
  rm -rf "${WORK_DIR}"
}

((!$#)) && \
  echo "No arguments supplied!" && \
  show_help && \
  exit 1

[[ " $* " =~ " -h " ]] || [[ " $* " =~ " --help " ]] && \
  show_help && \
  exit 0

init "${@}"
pull_playbook
install_requirements
execute_ansible_playbook
send_notification
cleanup
