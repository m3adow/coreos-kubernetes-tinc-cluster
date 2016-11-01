#!/bin/bash
set -x
set -e
set -u
set -o pipefail

SDEF_ETCD_DIR=${SDEF_ETCD_DIR:-/services/sdef/}
SDEF_ETCD_MYNAME=${SDEF_ETCD_MYNAME:-$(uname -n)}
SDEF_ETCD_MYIP=${SDEF_ETCD_MYIP:-${COREOS_PUBLIC_IPV4}}

SDEF_ALLOW_UPDATE=${SDEF_ALLOW_UPDATE:-1}
SDEF_ETCD_TTL=${SDEF_ETCD_TTL:-10}
SDEF_REFRESH_INTERVAL=${SDEF_REFRESH_INTERVAL:-5}

CF_API_EMAIL=${CF_API_EMAIL:-}
CF_API_KEY=${CF_API_KEY:-}

set_key() {
  local MY_TTL=${1:-${SDEF_ETCD_TTL}}
  etcdctl set --ttl ${SDEF_ETCD_TTL} "${SDEF_ETCD_DIR}/${SDEF_ETCD_MYNAME}" ${SDEF_ETCD_MYIP}
}

# get chksum of cluster IPs to simplify check for change
get_chksum() {
  SDEF_CURRSUM=$(for LINE in $(etcdctl ls --recursive -p "${SDEF_ETCD_DIR}"); do echo "${LINE}"; etcdctl get "${LINE}"; done | sha1sum | cut -d ' ' -f1)
}


initial_run() {
  # If this fails, we need to initially insert
  set +x
  local ALREADY_EXISTS=$(etcdctl ls --quorum "${SDEF_ETCD_DIR}/${SDEF_ETCD_MYNAME}" > /dev/null 2>&1; echo $?)
  set -x

  if [ "${ALREADY_EXISTS}" -ne 0 -o "${SDEF_ALLOW_UPDATE}" -eq 1 ]
  then
    set_key
  else
    exit 10
  fi
  get_chksum
}

main_loop(){
  while true
  do
    set_key
    SDEF_LASTUM=${SDEF_CURRSUM}
    get_chksum

    if [ ! "${SDEF_CURRSUM}" == "${SDEF_LASTUM}" ]
    then
      local NEW_ENDPOINTS=$(for LINE in $(etcdctl ls --recursive -p "${SDEF_ETCD_DIR}"); do etcdctl get "${LINE}"; done | tr -s '\n' ',' | sed 's/,$//')
      # Use a tempfile so we don't leak the key on the command line
      local TMPENVFILE=$(mktemp)
      echo "CF_API_EMAIL=${CF_API_EMAIL}" > ${TMPENVFILE}
      echo "CF_API_KEY=${CF_API_KEY}" >> ${TMPENVFILE}

      # Increase TTL before running the container so the key isn't removed before the next loop run (error prone, I know)
      set_key 30
      # DNS Magic happens here
      docker run --rm --env-file "${TMPENVFILE}" m3adow/change-cloudflare-dns-entries -d "${SDEF_DOMAIN}" -i "${NEW_ENDPOINTS}"
      rm -f ${TMPENVFILE}
    fi
    sleep ${SDEF_REFRESH_INTERVAL}
  done
}


while getopts d:e:u OPT
do
  case "${OPT}" in
    d)
      SDEF_DOMAIN="${OPTARG}"
    ;;
    u)
      SDEF_ALLOW_UPDATE=1
    ;;
    e)
      # If an env file is set, source it
      source ${OPTARG}
    ;;
  esac
done

initial_run
main_loop
