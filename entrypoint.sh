#!/usr/bin/env bash
set -euo

if [[ "$@" == "run" ]]; then
    EC2_AVAIL_ZONE=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
    EC2_REGION="`echo \"$EC2_AVAIL_ZONE\" | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"

    while true; do
        OUTPUT="$(curl -s 'http://localhost:8153/go/api/agents' -u "${GOCD_USERNAME}:${GOCD_PASSWORD}" -H 'Accept: application/vnd.go.cd.v4+json')"
        FILTERED="$(echo "${OUTPUT}" | jq -r '._embedded.agents[] | select(.environments == []) | .agent_state')"
        TOTAL="$(echo "${FILTERED}" | wc -l)"
        IDLE="$(echo "${FILTERED}" | grep '^Idle$' | wc -l)"
        BUILDING="$(echo "${FILTERED}" | grep '^Building$' | wc -l)"
        CANCELLED="$(echo "${FILTERED}" | grep '^Cancelled$' | wc -l)"
        UNKNOWN="$(echo "${FILTERED}" | grep '^Unknown$' | wc -l)"
        echo "{'@timestamp': $(date +%s), 'total': ${TOTAL}, 'idle': ${IDLE}, 'building': ${BUILDING}, 'cancelled': ${CANCELLED}, 'unknown': ${UNKNOWN}}"
        aws cloudwatch --region "${EC2_REGION}" put-metric-data --metric-name TotalAgents --namespace GoCD --value "${TOTAL}" --unit "Count" &
        aws cloudwatch --region "${EC2_REGION}" put-metric-data --metric-name BuildingAgents --namespace GoCD --value "${BUILDING}" --unit "Count" &
        aws cloudwatch --region "${EC2_REGION}" put-metric-data --metric-name IdleAgents --namespace GoCD --value "${IDLE}" --unit "Count" &
        aws cloudwatch --region "${EC2_REGION}" put-metric-data --metric-name CancelledAgents --namespace GoCD --value "${CANCELLED}" --unit "Count" &
        aws cloudwatch --region "${EC2_REGION}" put-metric-data --metric-name UnknownAgents --namespace GoCD --value "${UNKNOWN}" --unit "Count" &
        sleep 60
    done
else
    exec "$@"
fi
