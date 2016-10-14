#!/bin/sh
set -x
set -e
set -u
set -o pipefail

HA_REFRESH_INTERVAL=${HA_REFRESH_INTERVAL:-5}
HA_ETCD_BASE_DIR=${HA_ETCD_BASE_DIR:-/services/simple-ha/}
HA_ETCD_EXISTING_DIR=${HA_ETCD_EXISTING_DIR:-${HA_ETCD_BASE_DIR}/existing/}
HA_ETCD_AVAILABLE_DIR=${HA_ETCD_AVAILABLE_DIR:-${HA_ETCD_BASE_DIR}/available/}
HA_ETCD_MYNAME=${HA_ETCD_MYNAME:-$(uname -n)}
HA_ETCD_MYIP=${HA_ETCD_MYIP:-${COREOS_PUBLIC_IPV4}}

HA_ALLOW_UPDATE=${HA_ALLOW_UPDATE:-0}


initial_run() {
  # If this fails, we need to initially insert
  set +x
  local ALREADY_EXISTS=$(etcdctl ls --quorum "${HA_ETCD_AVAILABLE_DIR}/${HA_ETCD_MYNAME}" > /dev/null 2>&1; echo $?)
  set -x

  if [ ${ALREADY_EXISTS} -ne 0 ]
  then
    etcdctl set "${HA_ETCD_AVAILABLE_DIR}/${HA_ETCD_MYNAME}" ${HA_ETCD_MYIP}
  else
    if [ "${HA_ALLOW_UPDATE}" -eq 1 ]
    then
      etcdctl update "${HA_ETCD_AVAILABLE_DIR}/${HA_ETCD_MYNAME}" ${HA_ETCD_MYIP}
    else
      exit 10
    fi
  fi
  HA_CURRSUM=$(for LINE in $(etcdctl ls --recursive -p "${HA_ETCD_EXISTING_DIR}"); do echo "${LINE}"; etcdctl get "${LINE}"; done | sha1sum | cut -d ' ' -f1)
}

main_loop(){
  while true
  do
    HA_LASTUM=${HA_CURRSUM}
    HA_CURRSUM=$(for LINE in $(etcdctl ls --recursive -p "${HA_ETCD_EXISTING_DIR}"); do echo "${LINE}"; etcdctl get "${LINE}"; done | sha1sum | cut -d ' ' -f1)

    if [ ! "${HA_CURRSUM}" == "${HA_LASTUM}" ]
    then
      # DNS Magic happens here
      docker run --rm -ti
    fi
    sleep ${HA_REFRESH_INTERVAL}
  done
}


while getopts e:u OPT
do
  case "${OPT}" in
    u)
      HA_ALLOW_UPDATE=1
    e)
      CF_ENV_FILE=${OPTARG} # Ongoing
    ;;
  esac
done

initial_run
main_loop