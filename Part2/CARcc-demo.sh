#!/bin/bash

# Author:         Jason You All Rights Reserved
# Last modified:  March 4 2019
# Project:        Car Components Supply Chain
# LICENSE:        Apache 2.0


###########################################################
###################### Part 2 #############################
############## In Chaincode Dev Mode ######################
###########################################################
###########################################################


###################### Terminal 3 #########################
#
# List of functions
#   
#   INVOKE
#
#       InitLedger ()                                                       ANYONE
#       AddComponent(Role, ComponentID)                 Supplier            ONLY
#       TransferComponent(Role, NewOwner, ComponentID)  Sender & Receiver   ONLY
#       MountComponent (Role, ComponentID, CarID)       MANUFACTURE         ONLY
#       ReplaceComponent (Role, ComponentID, CarID)     MANUFACTURE         ONLY
#       RecallComponent (Role, ComponentID)             MANUFACTURE         ONLY
#       CreateCar (Role, CarID)                         MANUFACTURE         ONLY
#   
#   QUERY
#
#       QueryCar (CarID)                                                    ANYONE
#       QueryComponent (ComponentID)                                        ANYONE
#   
############################################################





###################### Terminal 1 ###########################
#############################################################

# docker-compose -f docker-compose-simple.yaml down  # just in case
docker-compose -f docker-compose-simple.yaml up

###################### Terminal 2 ###########################
# Using: $docker exec -it chaincode bash to get into the bash
#############################################################
cd chaincode/CARcc		# or just $ cd ./CARcc
go build

CORE_PEER_ADDRESS=peer:7052 CORE_CHAINCODE_ID_NAME=CARcc:0 ./CARcc

###################### Terminal 3 #########################
# Using: $docker exec -it cli bash to get into the bash
#
# All the commands to run in the Terminal 3 (docker-cli)
############################################################

# Install the chaincode on the peer
peer chaincode install -p chaincodedev/chaincode/CARcc -n CARcc -v 0
# Instantiate the chaincode
peer chaincode instantiate -n CARcc -v 0 -c '{"Args":[]}' -C myc

# Starting the invoke and query test
#
# Using our own initialization function
#
# General Invoke Template:
#	$ peer chaincode invoke -n CARcc -v 0 -c '{"Args":[]}' -C myc
#
# General Query Template:
#	$ peer chaincode query -n CARcc -v 0 -c '{"Args":[]}' -C myc


peer chaincode invoke -n CARcc -v 0 -c '{"Args":["InitLedger"]}' -C myc

peer chaincode invoke -n CARcc -v 0 -c '{"Args":["AddComponent", "Supplier.supplier1", "123456789"]}' -C myc



