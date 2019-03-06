# Author:         Jason You
# Last modified:  March 4 2019
# License:		  Apache 2.0
# Project:        Car Components Supply Chain
#
# Root Dir: ./fabric-samples/basic-network/



#########################################################
####################### Task 1.1 ########################
#########################################################


# 1. generate cryptography keys with "./crypto-config.yaml"
../bin/cryptogen generate --config=./crypto-config.yaml

# 2. set the currenct path to be the FABRIC_CFG_PATH
export FABRIC_CFG_PATH=$PWD


# ----------------------------
# Generating peers and orderer
# ----------------------------
	
# 3. Creating the genesis block
# ThreeOrgsOrdererGenesis is the profile defined in the configtx.yaml
# Here we output the genesis block to the ./channel-artifacts
# This allowing any entity communicate with the ordering service and get signature verification
../bin/configtxgen -profile ThreeOrgsOrdererGenesis -channelID byfn-sys-channel -outputBlock ./channel-artifacts/genesis.block

# Defining the channel name
export CHANNEL_NAME=mychannel



# 4. Generating the channel and anchor peers artifacts for organization 1, 2, and 3 with the ThreeOrgsChannel profile
../bin/configtxgen -profile ThreeOrgsChannel -outputCreateChannelTx ./channel-artifacts/channel.tx -channelID $CHANNEL_NAME

../bin/configtxgen -profile ThreeOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/Org1MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org1MSP

../bin/configtxgen -profile ThreeOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/Org2MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org2MSP

../bin/configtxgen -profile ThreeOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/Org3MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org3MSP
