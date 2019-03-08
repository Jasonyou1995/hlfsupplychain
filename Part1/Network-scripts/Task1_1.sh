# Author:         Jason You
# Last modified:  March 4 2019
# Project:        Car Components Supply Chain


#########################################################
####################### Task 1.1 ########################
#########################################################


# What does this do?
	# 1. generate crypto with "./crypto-config.yaml"
# What are the linked files/parameters(s)?
	# configuration file
# What can I change?
	# configuration time can be changed
../bin/cryptogen generate --config=./crypto-config.yaml

# What does this do?
	# 2. set the currenct path to be the FABRIC_CFG_PATH
# What are the linked files/parameters(s)?
	# Path of the current directory
# What can I change?
	# Path of the current directory
export FABRIC_CFG_PATH=$PWD


# - ---------------------------
#   Generating peers and orderer
# - ---------------------------
	
# What does this do? (creating the genesis block)
	# 3. ThreeOrgsOrdererGenesis is the profile defined in the configtx.yaml
	#    and here we output the genesis block to the channel-artifacts: a lot of genesis blocks
	#    (define the consortium)
	#    This allowing any entity communicate with the ordering service and get signature verification
# What are the linked files/parameters(s)?
	# the configtx.yaml
	# `generateChannelArtifacts()` in the byfn.sh
# What can I change?
	# The outputBlock and the channel ID
../bin/configtxgen -profile ThreeOrgsOrdererGenesis -channelID byfn-sys-channel -outputBlock ./channel-artifacts/genesis.block

# Define the channel name (not the same as the channel ID)
export CHANNEL_NAME=mychannel


# What does this do? (creating the channel)
	# 4. Generating the channel and anchor peers for organization 1, 2, and 3 with the ThreeOrgsChannel profile
# What are the linked files/parameters(s)?
	# ./channel-artifacts/*.tx
# What can I change?
	# The channel and anchor peers
../bin/configtxgen -profile ThreeOrgsChannel -outputCreateChannelTx ./channel-artifacts/channel.tx -channelID $CHANNEL_NAME

../bin/configtxgen -profile ThreeOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/Org1MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org1MSP

../bin/configtxgen -profile ThreeOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/Org2MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org2MSP

../bin/configtxgen -profile ThreeOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/Org3MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org3MSP
