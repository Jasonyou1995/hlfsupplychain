#!/bin/bash


#                 Jason You
# Last modified:  March 4 2019
# Project:        Car Components Supply Chain
#
# This is only the samples for Hyperledger Fabric
# endorsement policies, and not an actual file.
#

###########################################################
###################### Task 4 #############################
###########################################################
###########################################################
###########################################################

# Our list of chaincode
#	* suppliercc	: only endorsed by Supplier
#	* manufcc		: only endorsed by Manufacture
#	* transfercc	: only endorsed by the sender and receiver

# This is the command in the cli docker to run to set the
# endorsement policies for each chaincode we set up
#
# All of these commands are running in instantiation step


#############################################################
################# Using cli docker bash #####################
#############################################################

# suppliercc (org1)
peer chaincode instantiate -n suppliercc -v 0 -C myc -c '{"Args":[]}' -P "AND(Org1.peer)"

# manufcc (org2)
peer chaincode instantiate -n manufcc -v 0 -C myc -c '{"Args":[]}' -P "AND(Org2.peer)"

# transfercc
# TODO: we know Mspid, IdBytes. (Does this works?)
# Since we only have two organizations, we can have either organization to endorse
peer chaincode instantiate -n transfercc -v 0 -C myc -c '{"Args":[]}' -P "OR(Org1.peer, Org2.peer)"



#############################################################
################# Using Node.js SDK #########################
#############################################################
# suppliercc (org1)
{
	identities: [
		{ role: { name: "peer", mspId: "Org1" }}
	],
	policy: {
		"1-of": [{ "signed-by": 0 }]
	}
}

# manufcc (org2)
{
	identities: [
		{ role: { name: "peer", mspId: "Org2" }}
	],
	policy: {
		"1-of": [{ "signed-by": 0 }]
	}
}

# transfercc
{
	identities: [
		{ role: { name: "peer", mspId: "Org1" },
		  role: { name: "peer", mspId: "Org2" }}
	],
	policy: {
		"1-of": [{ "signed-by": 0 }, { "signed-by": 1}]
	}
}