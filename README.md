# Hyperledger Fabric Car Supply Chain

Note: All the chaincode and configuration file provide in here are for demostration purpose. DON'T USE ANY OF THESE CODE ON YOUR REAL WORLD BUSINESS SCENARIO BEFORE SECURITY REVISING.

## Environment

* Hyperledger-Fabric = V1.1
* node	= v8.11.1
* nvm	= 6.8.0
* go version go1.11.4 darwin/amd64

## What is in this directory?

This directory contains several different operation on the Hyperledger Blockchain network. To test them, please use the `chaincode-dev-mode` and `balance-transfer` example provided in the official Hyperledger `fabric-samples` directory. For more technical details, please refer to the [documentation](https://hyperledger-fabric.readthedocs.io/en/release-1.4/chaincode4ade.html) of Hyperledgre Fabric.

These scripts are under the license of Apache 2.0 and part of them are adpoted from the Hyperledger `basic-network` sample. No Warranty in any from is provided.

### Part 1: Hyperledger Fabric Network Configuration

This part contains several configuration files that construct three organization consortiums: Org1, Org2 and Org3. All of their certificate files are mounted on the "chaincode" and "cli" docker containers by the `docker-compose-base.yaml` configuration file. I will explain each of these configuration files in more detail:

* `./base/docker-compose-base.yaml`
	* in this file we need to pay more attention to the *volumes* and *ports* fields. We use the *volumnes* field to define where do we send all the certificates of our artifacts, i.e. organizations/members and peers, to each of the containers.
	* And with the default *ports* to facilitate communication between peers and chaincode containers: 
		* `7051`: used for peer to peer communication and the gossip data dissemination protocol; 
		* `7052`: by default this port is used for chaincodes to communicate with peers, and if no value for this purpose is set then port 7052 will be assigned; 
		* `7053` the port used to be the port for the event hub service, which can be used by clients to subscribe to blockchain and chaincode updates and events.
* `./docker-compose-cli.yaml`: similar to the one above, instead this configuration file is for the *cli* docker container environment set.
* `./configtx.yaml`: 
	* This file is mainly used for fhe network set up, including all the basic fields for:
		* Organizations (e.g. Name, ID, MSPDir, AnchorPeers, etc.);
		* Orderer information: including choosing *SOLO* or *Kafaka* consensus algorithm, and you can find more information in [here](https://hyperledger-fabric.readthedocs.io/en/release-1.1/kafka.html);
		* Profile information: this part can help you to define consortium or consortia structure based on all the organizations defined. 
		   * **Note: This part must be in the bottom of this configuration file in HLF V1.4**
		* Access Control List (ACL)
		* [Many more...](https://hyperledger-fabric.readthedocs.io/en/latest/build_network.html#start-the-network)
* `./crypto-config.yaml`: Stores all the organization and orderer information, such as how many peers are in each organization.

You should move these configuration file to the `fabric-samples/basic-network` and setup the correct environment. Notice that these configuration files will probably not work with Hyperledger Fabric V1.4, because it have more strick formating rules and this might introduce errors.

After the correct set up, you should be able to launch your network in the root directory or your Hyperledger Fabric network with the command: `docker-compose -f Your-compose-file-name.yaml up`. Please fill free to modify these files to your business need, and test your network with reference to documentations like [this](https://hyperledger-fabric.readthedocs.io/en/latest/network/network.html).

### Part 2: Car Component Supply Chain Smart Contract

This part built a car component supply chain built based on several chaincode lever access control. In the future implementation I will add more identity management with the `GetCreator()` function provided by the `shim` package of golang.

The following are the functions that that chaincode support, and most them have restriction to differet roles:

* List of roles:
	* Supplier
	* Manufacture
	* Authorized dealors
	* Cars

* List of functions
	*   INVOKE
		*       InitLedger ()                                                       ANYONE
		*       AddComponent(Role, ComponentID)                 Supplier            ONLY
		*       TransferComponent(Role, NewOwner, ComponentID)  Sender & Receiver   ONLY
		*       MountComponent (Role, ComponentID, CarID)       MANUFACTURE         ONLY
		*       ReplaceComponent (Role, ComponentID, CarID)     MANUFACTURE         ONLY
		*       RecallComponent (Role, ComponentID)             MANUFACTURE         ONLY
		*       CreateCar (Role, CarID)                         MANUFACTURE         ONLY
	*   QUERY
		*       QueryCar (CarID)                                                    ANYONE
		*       QueryComponent (ComponentID)                                        ANYONE

### Part 3 Certificates

In this part I'm showing how to get certificate for the car component supply chain implementation: using different usernames such as "Supplier.supplier1" or "Manufacture.manufacture1".

The full example can be found in the `./fabric-samples/basic-network/testAPIs.sh`, and this script with the chaincode in part 2 can be tested with the provided network too.

### Part 4 Endorsement Policies

This part is sample implementation of endorsement policy for Supplier and Dealer. The chaincode need to be properly splited for different function privileges, because we can only assign once endorsement policy to each instantiated chaincode.

I already splited the chaincode based on their privileges for different, so they can easily be assigned for different endorsement policies.

We will add more policies later once the set of our chaincode functions are more comprehensive. It can be added either by SDK of Fabric (such as Node.js SDK), or manually deploy these policies on 

`peer chaincode instantiate -P <POLICY> -n <CHAINCODE_NAME> -v <VERSION> -C <CHANNEL_NAME> -c <COMMAND>`

Or you can just run `peer chaincode instantiate -h` to learn more details when you are in the "cli" docker container.

**Note:**

1. This is not the policy file, for the actually depolyment of endorsement policy please refer to [this documentation](https://hyperledger-fabric.readthedocs.io/en/latest/endorsement-policies.html).
2. To get into the docker container:
	3. `docker exec -it cli bash`
	4. `docker exec -it chaincode bash`


