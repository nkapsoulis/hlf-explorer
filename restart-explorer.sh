#!/bin/bash

COMPOSE_YAML="docker-compose.yaml"
ORG1="org1.example.com"
PEER0_ORG1_PORT=7051 # works with peer0
CHANNEL="mychannel"

CONFIG_FILE="config.json"
PROFILE=`jq -r '."network-configs"."test-network".profile' ${CONFIG_FILE}`
ORGS_DIR="../test-network/organizations"
DISCOVERY_AS_LOCALHOST="false"

KEY_PATH=`echo /tmp/crypto/peerOrganizations/${ORG1}/users/Admin@${ORG1}/msp/keystore/priv_sk`

CERT_PATH=`echo /tmp/crypto/peerOrganizations/${ORG1}/users/Admin@${ORG1}/msp/signcerts/Admin@org1.example.com-cert.pem`
jq 'del(.channels.mychannel.peers[]) | .channels.mychannel[] |= . + {"peer0.'"${ORG1}"'":{}}' $PROFILE > temp && mv temp $PROFILE
if [ $CHANNEL != 'mychannel' ]; then
  jq '.channels.'"${CHANNEL}"' = .channels.mychannel | del(.channels.mychannel)' $PROFILE > temp && mv temp $PROFILE
fi
jq '.organizations.Org1MSP.adminPrivateKey.path = "'${KEY_PATH}'" | .organizations.Org1MSP.signedCert.path = "'${CERT_PATH}'"' $PROFILE > temp && mv temp $PROFILE
jq '.organizations.Org1MSP.peers = ["peer0.'${ORG1}'"]' $PROFILE > temp && mv temp $PROFILE
jq '.peers."peer0.'${ORG1}'".tlsCACerts.path = "'/tmp/crypto/peerOrganizations/${ORG1}/peers/peer0.${ORG1}/tls/ca.crt'"' $PROFILE > temp && mv temp $PROFILE
if [ $ORG1 != 'org1.example.com' ]; then
  jq '.peers."peer0.'${ORG1}'" = .peers."peer0.org1.example.com" | del(.peers."peer0.org1.example.com")' $PROFILE > temp && mv temp $PROFILE
fi
jq '.peers."peer0.'${ORG1}'".url = "'grpcs://peer0.${ORG1}:${PEER0_ORG1_PORT}'"' $PROFILE > temp && mv temp $PROFILE

docker container inspect ca_org1 > temp
NETWORK=`jq -r '.[0:] | .[] | .NetworkSettings.Networks | keys | .[]' temp` && rm temp
yq e '.networks."mynetwork.com".external.name = "'${NETWORK}'"' $COMPOSE_YAML > temp && mv temp $COMPOSE_YAML
yq e '.services."explorer.mynetwork.com".volumes[0] = "./'${CONFIG_FILE}':/opt/explorer/app/platform/fabric/config.json"' $COMPOSE_YAML > temp && mv temp $COMPOSE_YAML
CONN_PROFILE=`echo $PROFILE | cut -d'/' -f2`
yq e '.services."explorer.mynetwork.com".volumes[1] = "./'"${CONN_PROFILE}"':/opt/explorer/app/platform/fabric/connection-profile"' $COMPOSE_YAML > temp && mv temp $COMPOSE_YAML
yq e '.services."explorer.mynetwork.com".volumes[2] = "'${ORGS_DIR}':/tmp/crypto"' $COMPOSE_YAML > temp && mv temp $COMPOSE_YAML
yq e '.services."explorer.mynetwork.com".environment[8] = "DISCOVERY_AS_LOCALHOST='${DISCOVERY_AS_LOCALHOST}'"' $COMPOSE_YAML > temp && mv temp $COMPOSE_YAML

docker-compose down -v
sleep 3
docker-compose up -d

# username: exploreradmin, password: exploreradminpw