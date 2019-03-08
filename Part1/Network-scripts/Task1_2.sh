# Author:         Jason You
# Last modified:  March 4 2019
# Project:        Car Components Supply Chain


#########################################################
####################### Task 1.2 ########################
#########################################################

# What does this do?
    # 5. docker compose configuration
# What are the linked files/parameters(s)?
    # ./docker-compose-cli.yaml
# What can I change?
    # The configuration file: ./docker-compose-cli.yaml
docker-compose -f docker-compose-cli.yaml up -d

# What does this do?
    # 6. Environmental variables set up for the core peer
# What are the linked files/parameters(s)?
    # N/A
# What can I change?
    # Environment variables for peer0.org1.example.com:7051
CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
CORE_PEER_ADDRESS=peer0.org1.example.com:7051
CORE_PEER_LOCALMSPID="Org1MSP"
CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt

# What does this do?
    # 7. Run the cli docker bash
# What are the linked files/parameters(s)?
# What can I change?
docker exec -it cli bash