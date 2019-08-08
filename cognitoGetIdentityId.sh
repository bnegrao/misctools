#!/bin/bash

function die {
    declare MSG="$@"
    echo -e "$0: Error: $MSG">&2
    exit 1
}

function usage {
    echo "USAGE: $0 <USERNAME> <PASSWORD>"
}

[[ $# -ne 2 ]] && die "Wrong arguments.\n$(usage)"


USERNAME=$1
USER_PASSWORD=$2

# environment
USER_POOL_ID="us-east-1_xxxxHsqOx"
IDENTITY_POOL_ID="us-east-1:xxxx777a-4e54-44b7-xxxx-350fcd83xxxx"
COGNITO_APP_CLIENT_ID="xxxxgdtslimnfemo01viexxxx"
COGNITO_TOKEN_PROVIDER="cognito-idp.us-east-1.amazonaws.com/us-east-1_xxxxHsqOx"

function getIdentityId {
    declare response=$(aws cognito-idp initiate-auth \
        --client-id $COGNITO_APP_CLIENT_ID \
        --auth-flow CUSTOM_AUTH \
        --auth-parameters USERNAME=$USERNAME)
    [ -z "$response" ] && die "failed in initiate-auth"

    #echo $response | jq >&2

    declare session=$(echo $response | jq .Session | sed 's/"//g')

    response=$(aws cognito-idp respond-to-auth-challenge \
    --client-id $COGNITO_APP_CLIENT_ID \
    --challenge-name CUSTOM_CHALLENGE \
    --session $session \
    --challenge-responses USERNAME=$USERNAME,ANSWER=$USER_PASSWORD)
    [ -z "$response" ] && die "failed in respond-to-auth-challenge"

    #echo $response | jq >&2

    declare idToken=$(echo $response | jq .AuthenticationResult.IdToken | sed 's/"//g')    
    [ -z "$idToken" -o "$idToken" = null ] && die "Could not obtain IdToken"

    declare identityId=$(aws cognito-identity get-id \
        --identity-pool-id $IDENTITY_POOL_ID --logins $COGNITO_TOKEN_PROVIDER=$idToken)        
    [ -z "$identityId" ] && die "failed in get-id"

    echo $identityId | jq .IdentityId | sed 's/"//g'
}

getIdentityId
