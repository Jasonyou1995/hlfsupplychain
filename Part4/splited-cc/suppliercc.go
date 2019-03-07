/*
    Author:           Jason You All Rights Reserved
    Last modified:    March 6 2019
    Project:          Car Components Supply Chain

    SPDX-License-Identifier: Apache-2.0               */

package main

import (
    // "bytes"
    "encoding/json"
    "fmt"
    "strconv"
    "strings"
    // "errors"

    "github.com/hyperledger/fabric/core/chaincode/shim"
    "github.com/hyperledger/fabric/protos/peer"
)

/*
    #############################################################
    ############ Building the basic structures ##################
    #############################################################
*/


// Define the Smart Contract structure (not the component)
type SmartContract struct {
    // suppose to be empty
}

// Car Component structure
type CarComponent struct {
    Retired     bool    `json:"retired"`
    Owner       string  `json:"Owner"`   // entity: "ROLE_TYPE.ROLE_NAME"
    CarID       string  `json:"carid"`
}

// Car that stores the ComponentID mounted on it
// We only record one component for convinence,
// but we can use veracity string if we want
type Car struct {
    ComponentID  string `json:"ComponentID`    
}


/*
    #############################################################
    ############# Initialization of Interface ###################
    #############################################################
*/

// This function is called when this chaincode is instantiated
// We have a separate function for ledger instantiation: see initLedger()
func (s *SmartContract) Init(stub shim.ChaincodeStubInterface) peer.Response {
    // No action, because there is no components at the very beginning
    return shim.Success(nil)
}


/*
    #############################################################
    ##################### Invoke the chaincode ##################
    #############################################################
*/

// Invoking the correct function
func (s *SmartContract) Invoke(stub shim.ChaincodeStubInterface) peer.Response {
    
    fn, args := stub.GetFunctionAndParameters()

    if fn == "AddComponent" {
        return s.AddComponent(stub, args)
    } else if fn == "InitLedger" {
        return s.InitLedger(stub)
    } else if fn == "QueryCar" {
        return s.QueryCar(stub, args)
    } else if fn == "QueryComponent" {
        return s.QueryComponent(stub, args)
    }

    return shim.Error("Invalid Smart Contract function name.")
        
}


/*
    #############################################################
    ################## Initializing Ledger ######################
    #############################################################
*/

/*
    Initializing this ledger with multiple sample components for testing purpose
    Can be ran by any peer and client
    @stub:      the chaincode interface
*/
func (s *SmartContract) InitLedger(stub shim.ChaincodeStubInterface) peer.Response {
    
    // Build six initial components, with one of them already Retired
    // There are three CarID's in here: CAR0, CAR1, and CAR2
    components := []CarComponent{
        CarComponent{Retired: false,    Owner: "Supplier.s0",       CarID: "CAR0"},
        CarComponent{Retired: false,    Owner: "Supplier.s1",       CarID: "CAR1"},
        CarComponent{Retired: false,    Owner: "Manufacture.m0",    CarID: "CAR2"},
        CarComponent{Retired: false,    Owner: "Manufacture.m2",    CarID: "CAR3"},
        CarComponent{Retired: false,    Owner: "Dealer.d0",         CarID: "CAR4"},
        CarComponent{Retired: true,     Owner: "Dealer.d1",         CarID: "CAR5"},
    } 

    /*
    List of ComponentID:
        000000000
        000000001
        000000002
        000000003
        000000004
        000000005
    */
    // Component${i}
    i := 0
    var ComponentID string
    for i < len(components) {
        fmt.Println("i = ", i, "component is", components[i])
        componentAsBytes, _ := json.Marshal(components[i])  // debug
        ComponentID = "00000000" + strconv.Itoa(i)
        stub.PutState(ComponentID, componentAsBytes)
        fmt.Println("Added", components[i], "with ComponentID:", ComponentID, "Marshal form:", componentAsBytes)
        i = i + 1       // increment
    }
    return shim.Success(nil)
}


/*
    #############################################################
    ################### Add Car Component #######################
    #############################################################
*/

/*
    Add car component
    Only called by Supplier
    @stub:      the chaincode interface
    @args[0]:   the role of the function invoker
    @args[1]:   ComponentID (9-digit unique string)
*/
func (s *SmartContract) AddComponent(stub shim.ChaincodeStubInterface, args []string) peer.Response {

    /*
        #############################################################
        #################### Arguments Checking #####################
        #############################################################
    */

    if len(args) != 2 {
        return shim.Error("Incorrect number of argument: expect 2.")
    }

    // Get the first part of the input as the role of invoker
    rolename    := args[0]
    role        := strings.Split(args[0], ".")[0]

    // Role checking: only can be called by supplier
    if !strings.EqualFold(role, "Supplier") {
        return shim.Error("Incorrect role: expect Supplier.")
    }

    ComponentID := args[1]

    // Check component ID format
    if !CheckIDFormat(ComponentID) {
        return shim.Error("Incorrect ComponentID format: expect 9-digit string")
    }

    /*
        #############################################################
        ###################### Access Control #######################
        #############################################################
    */

    // designing my own access control logic (integrate with old mechanism)
    creator, _ := stub.GetCreator()     // get the real identity of client
    fmt.Println("creator", creator)


    /*
        #############################################################
        ####################### Main Function #######################
        #############################################################
    */

    // Check if this is a Retired component.
    exist, _ := stub.GetState(ComponentID)
    if exist != nil {
        return shim.Error("The given ComponentID is already used.")
    }

    // Build a new component with the given ComponentID. Since only Supplier
    // can call this function, it will be the initial Owner.
    var component = CarComponent{false, rolename, ""}

    // Encoding the component as byte payload in JSON format
    componentAsBytes, _ := json.Marshal(component)

    err := stub.PutState(ComponentID, componentAsBytes)
    if err != nil {
        return shim.Error(err.Error())
    }

    // Output result to the server for debug
    fmt.Println("Added", component, "by", rolename)

    // return peer success response
    return shim.Success(nil)
}


/*
    #############################################################
    #################### My Helper Functions ############3#######
    #############################################################
*/

// Check the ID format of car component: should be 9-digit string
// Return true if format is correct, and false otherwise
func CheckIDFormat(ComponentID string) bool {
    if len(ComponentID) != 9 {
        // check the length of the ComponentID is nine
        return false
    } else if _, err := strconv.Atoi(ComponentID); err != nil {
        // check the ComponentID are all digits
        return false
    } else {
        // now everything looks fine
        return true
    }
}


/*
    Query one car
    @args[0]:   The CarID
*/
func (s *SmartContract) QueryCar(stub shim.ChaincodeStubInterface, args []string) peer.Response {

    if len(args) != 1 {
        return shim.Error("Incorrect number of arguments, expecting 1")
    }

    CarID := args[0]
    fmt.Println("Client trying to query car", CarID, "...")

    // We don't need to Unmarshal because we will transfer it back to client as bytes
    carAsBytes, err := stub.GetState(CarID)

    if err != nil {
        return shim.Error(err.Error())
    } else if len(carAsBytes) == 0 {
        return shim.Error("QueryCar Error: CarID " + CarID + " not found")
    }

    fmt.Println("QueryCar:", carAsBytes)

    return shim.Success(carAsBytes)
}

/*
    Query one component by ComponentID
    @args[0]: ComponentID
*/
func (s *SmartContract) QueryComponent(stub shim.ChaincodeStubInterface, args []string) peer.Response {

    if len(args) != 1 {
        return shim.Error("Incorrect number of arguments, expecting 1")
    }

    ComponentID := args[0]

    // Check component ID format
    if !CheckIDFormat(ComponentID) {
        return shim.Error("Incorrect ComponentID format: expect 9-digit string")
    }

    fmt.Println("Client trying to query component", ComponentID, "...")

    // We don't need to Unmarshal because we will transfer it back to client as bytes
    componentAsBytes, err := stub.GetState(ComponentID)

    if err != nil {
        return shim.Error(err.Error())
    } else if len(ComponentID) == 0 {
        return shim.Error("QueryComponent Error: ComponentID " + ComponentID + " not found")
    }

    fmt.Println("QueryComponent:", componentAsBytes)


    return shim.Success(componentAsBytes)
}


func main() {
    // Create a new 
    err := shim.Start(new(SmartContract))
    if err != nil {
        fmt.Printf("Error starting Simple chaincode: %s", err)
    }
}

