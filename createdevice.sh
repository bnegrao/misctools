#!/bin/bash

function die {
    declare MSG="$@"
    echo -e "$0: Error: $MSG">&2
    exit 1
}

function usage {
    echo "USAGE: $0 <ENV (dev|hml)> <TENANT> <STORE> <POSID> <PASSWORD>"
}

CONFIG_FILE="createdevice.conf.json"
[[ -f $CONFIG_FILE ]] || "die config file '$CONFIG_FILE' doesn't exist"

[[ $# -ne 5 ]] && die "Wrong arguments.\n$(usage)"

ENV=$1
TENANT=$2
STORE=$3
POSID=$4
USER_PASSWORD=$5

[[ "$ENV" == "dev" || "$ENV" == "hml" ]] || die "ENV '$ENV' is invalid.\n$(usage)"

USERNAME=${TENANT}_${STORE}_${POSID}_$(date +%s)
THINGNAME=$USERNAME

# environment
IOT_POLICY=`jq .${ENV}.IOT_POLICY $CONFIG_FILE| sed 's/"//g'`
THING_TYPE=`jq .${ENV}.THING_TYPE $CONFIG_FILE| sed 's/"//g'`
USER_POOL_ID=`jq .${ENV}.USER_POOL_ID $CONFIG_FILE| sed 's/"//g'`
IDENTITY_POOL_ID=`jq .${ENV}.IDENTITY_POOL_ID $CONFIG_FILE| sed 's/"//g'`
COGNITO_APP_CLIENT_ID=`jq .${ENV}.COGNITO_APP_CLIENT_ID $CONFIG_FILE| sed 's/"//g'`
COGNITO_TOKEN_PROVIDER=`jq .${ENV}.COGNITO_TOKEN_PROVIDER $CONFIG_FILE| sed 's/"//g'`
TABLE=`jq .${ENV}.TABLE $CONFIG_FILE| sed 's/"//g'`

function getIdentityId {
    declare response=$(aws cognito-idp initiate-auth \
        --client-id $COGNITO_APP_CLIENT_ID \
        --auth-flow CUSTOM_AUTH \
        --auth-parameters USERNAME=$USERNAME)
    [ -z "$response" ] && die "failed in initiate-auth"

    declare session=$(echo $response | jq .Session | sed 's/"//g')

    response=$(aws cognito-idp respond-to-auth-challenge \
    --client-id $COGNITO_APP_CLIENT_ID \
    --challenge-name CUSTOM_CHALLENGE \
    --session $session \
    --challenge-responses USERNAME=$USERNAME,ANSWER=$USER_PASSWORD)
    [ -z "$response" ] && die "failed in respond-to-auth-challenge"

    declare idToken=$(echo $response | jq .AuthenticationResult.IdToken | sed 's/"//g')

    declare identityId=$(aws cognito-identity get-id \
        --identity-pool-id $IDENTITY_POOL_ID --logins $COGNITO_TOKEN_PROVIDER=$idToken)        
    [ -z "$identityId" ] && die "failed in get-id"

    echo $identityId | jq .IdentityId | sed 's/"//g'
}


echo "Creating user on DynamoDB..."
aws dynamodb put-item --table $TABLE --item "{\"username\":{\"S\":\"$USERNAME\"},\"password\":{\"S\":\"$USER_PASSWORD\"},\"tenant-store-posId\":{\"S\":\"$TENANT-$STORE-$POSID\"},\"enabled\":{\"BOOL\":true}}"

echo creating cognito user $USERNAME
aws cognito-idp admin-create-user --user-pool-id $USER_POOL_ID --username $USERNAME \
    --user-attributes Name=custom:tenant,Value=$TENANT Name=custom:store,Value=$STORE Name=custom:posId,Value=$POSID \
    --message-action SUPPRESS > /dev/null \
    || die "failed to create cognito user"

echo -n "getting the user's identityId... "
principal=`getIdentityId`

echo $principal 

echo "creating iot thing $THINGNAME"
aws iot create-thing --thing-name $THINGNAME --thing-type-name $THING_TYPE \
    --attribute-payload "attributes={tenant=$TENANT,store=$STORE,posId=$POSID,enabled=true},merge=false" > /dev/null \
    || die "failed to create iot thing"

echo "attaching cognito identityId to iot policy $IOT_POLICY"
aws iot attach-policy --target $principal --policy-name $IOT_POLICY > /dev/null || die "failed to attach-policy"

echo "attaching cognito identityId to iot thing $THINGNAME"
aws iot attach-thing-principal --principal $principal --thing-name $THINGNAME > /dev/null || die "failed to attach-thing-principal"

echo $POSID $THINGNAME >> pdvs-${ENV}.txt
