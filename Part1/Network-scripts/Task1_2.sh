# Author:         Jason You
# Last modified:  March 4 2019
# License:		  Apache 2.0
# Project:        Car Components Supply Chain
#
# Root Dir: ./fabric-samples/basic-network/

#########################################################
####################### Task 1.2 ########################
#########################################################

# 5. docker compose configuration
# option: docker-compose -f docker-compose-cli.yaml down
docker-compose -f docker-compose-cli.yaml up -d

# 6. Environmental variables set up for the core peer
# This will over write the ENV VAR we set in the configuration file
CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
CORE_PEER_ADDRESS=peer0.org1.example.com:7051
CORE_PEER_LOCALMSPID="Org1MSP"
CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt

# 7. Run the cli docker bash
docker exec -it cli bash