#!/usr/bin/env bash
set -eEu

if [[ "$@" == "master" ]]; then
    echo "{\"@timestamp\": $(date +%s), \"message\": \"initialising\"}"
    EC2_AVAIL_ZONE=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
    EC2_REGION="`echo \"$EC2_AVAIL_ZONE\" | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"
    INSTANCE_ID="$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
    ASG_NAME="$(aws autoscaling describe-auto-scaling-instances --region "${EC2_REGION}" --instance-ids=${INSTANCE_ID} | jq -r '.AutoScalingInstances[].AutoScalingGroupName')"
    CUR_STATE="Unknown"
    PREV_STATE="Unknown"
    echo "{\"@timestamp\": $(date +%s), \"message\": \"logging startup values\", \"EC2_AVAIL_ZONE\": \"${EC2_AVAIL_ZONE}\", \"EC2_REGION\": \"${EC2_REGION}\", \"INSTANCE_ID\": \"${INSTANCE_ID}\", \"ASG_NAME\": \"${ASG_NAME}\", \"CUR_STATE\": \"${CUR_STATE}\", \"PREV_STATE\": \"${PREV_STATE}\"}"

    while true; do
        OUTPUT="$(curl -s 'http://localhost:8153/go/api/agents' -u "${GOCD_USERNAME}:${GOCD_PASSWORD}" -H 'Accept: application/vnd.go.cd.v4+json')"
        FILTERED="$(echo "${OUTPUT}" | jq -r '._embedded.agents[] | select(.environments == []) | .agent_state')"
        TOTAL="$(echo "${FILTERED}" | wc -l)"
        IDLE="$(echo "${FILTERED}" | grep '^Idle$' | wc -l)"
        BUILDING="$(echo "${FILTERED}" | grep '^Building$' | wc -l)"
        CANCELLED="$(echo "${FILTERED}" | grep '^Cancelled$' | wc -l)"
        UNKNOWN="$(echo "${FILTERED}" | grep '^Unknown$' | wc -l)"
        MISSING="$(echo "${FILTERED}" | grep '^Missing$' | wc -l)"
        echo "{'@timestamp': $(date +%s), 'total': ${TOTAL}, 'idle': ${IDLE}, 'building': ${BUILDING}, 'cancelled': ${CANCELLED}, 'unknown': ${UNKNOWN}, 'missing': ${MISSING}}"
        aws cloudwatch --region "${EC2_REGION}" put-metric-data --metric-name TotalAgents --namespace GoCD --value "${TOTAL}" --unit "Count" &
        aws cloudwatch --region "${EC2_REGION}" put-metric-data --metric-name BuildingAgents --namespace GoCD --value "${BUILDING}" --unit "Count" &
        aws cloudwatch --region "${EC2_REGION}" put-metric-data --metric-name IdleAgents --namespace GoCD --value "${IDLE}" --unit "Count" &
        aws cloudwatch --region "${EC2_REGION}" put-metric-data --metric-name CancelledAgents --namespace GoCD --value "${CANCELLED}" --unit "Count" &
        aws cloudwatch --region "${EC2_REGION}" put-metric-data --metric-name UnknownAgents --namespace GoCD --value "${UNKNOWN}" --unit "Count" &
        aws cloudwatch --region "${EC2_REGION}" put-metric-data --metric-name MissingAgents --namespace GoCD --value "${MISSING}" --unit "Count" &
        sleep 40
    done
elif [[ "$@" == "agent" ]]; then
    echo "{\"@timestamp\": $(date +%s), \"message\": \"initialising\"}"
    EC2_AVAIL_ZONE=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
    EC2_REGION="`echo \"$EC2_AVAIL_ZONE\" | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"
    INSTANCE_ID="$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
    ASG_NAME="$(aws autoscaling describe-auto-scaling-instances --region "${EC2_REGION}" --instance-ids=${INSTANCE_ID} | jq -r '.AutoScalingInstances[].AutoScalingGroupName')"
    CUR_STATE="Unknown"
    PREV_STATE="Unknown"
    echo "{\"@timestamp\": $(date +%s), \"message\": \"logging startup values\", \"EC2_AVAIL_ZONE\": \"${EC2_AVAIL_ZONE}\", \"EC2_REGION\": \"${EC2_REGION}\", \"INSTANCE_ID\": \"${INSTANCE_ID}\", \"ASG_NAME\": \"${ASG_NAME}\", \"CUR_STATE\": \"${CUR_STATE}\", \"PREV_STATE\": \"${PREV_STATE}\"}"

    while true; do
        OUTPUT="$(curl -s "${GOCD_URL}/api/agents" -u "${GOCD_USERNAME}:${GOCD_PASSWORD}" -H 'Accept: application/vnd.go.cd.v4+json')"
        CUR_STATE="$(echo "${OUTPUT}" | jq -r "._embedded.agents[] | select(.hostname == \"${HOSTNAME}\") | .build_state")"
        if [[ "${CUR_STATE}" == "Building" ]] && ! [[ "${CUR_STATE}" == "${PREV_STATE}" ]]; then  # if the agent's state has changed from something to Building, protect the instance
                echo "{\"@timestamp\": $(date +%s), \"message\": \"protecting instance\", \"INSTANCE_ID\": \"${INSTANCE_ID}\", \"ASG_NAME\": \"${ASG_NAME}\", \"CUR_STATE\": \"${CUR_STATE}\", \"PREV_STATE\": \"${PREV_STATE}\"}"
                aws autoscaling set-instance-protection --region "${EC2_REGION}" --instance-ids "${INSTANCE_ID}" --auto-scaling-group-name "${ASG_NAME}" --protected-from-scale-in &
        elif [[ "${PREV_STATE}" == "Building" ]] && ! [[ "${CUR_STATE}" == "${PREV_STATE}" ]]; then  # if the agent's state has changed from Building to something else, unprotect it
                echo "{\"@timestamp\": $(date +%s), \"message\": \"unprotecting instance\", \"INSTANCE_ID\": \"${INSTANCE_ID}\", \"ASG_NAME\": \"${ASG_NAME}\", \"CUR_STATE\": \"${CUR_STATE}\", \"PREV_STATE\": \"${PREV_STATE}\"}"
                aws autoscaling set-instance-protection --region "${EC2_REGION}" --instance-ids "${INSTANCE_ID}" --auto-scaling-group-name "${ASG_NAME}" --no-protected-from-scale-in &
        else
                echo "{\"@timestamp\": $(date +%s), \"message\": \"doing nothing\", \"INSTANCE_ID\": \"${INSTANCE_ID}\", \"ASG_NAME\": \"${ASG_NAME}\", \"CUR_STATE\": \"${CUR_STATE}\", \"PREV_STATE\": \"${PREV_STATE}\"}"
        fi
        sleep 5s
        PREV_STATE="${CUR_STATE}"
    done
else
    exec "$@"
fi
