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

    if fn == "MountComponent" {
        return s.MountComponent(stub, args)
    } else if fn == "ReplaceComponent" {
        return s.ReplaceComponent(stub, args)
    } else if fn == "RecallComponent" {
        return s.RecallComponent(stub, args)
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
    #################### Mount Car Component ####################
    #############################################################
*/

/*
    Mount car components to the car, make sure that:
    (1) The car is new
    (2) The component is new
    Only called by Manufacture
    @args[0]:   the role of the function invoker
    @args[1]:   ComponentID
    @args[2]:   CarID
*/
func (s *SmartContract) MountComponent(stub shim.ChaincodeStubInterface, args []string) peer.Response {

    /*
        #############################################################
        #################### Arguments Checking #####################
        #############################################################
    */

    if len(args) != 3 {
        return shim.Error("Incorrect number of argument: expect 3.")
    }

    // Get the first part of the input as the role of invoker
    rolename := args[0]
    role := strings.Split(args[0], ".")[0]

    // Role checking: only can be called by supplier
    if !strings.EqualFold(role, "Manufacture") {
        return shim.Error("Incorrect role: expect Manufacture.")
    }

    ComponentID := args[1]

    // Check component ID format
    if !CheckIDFormat(ComponentID) {
        return shim.Error("Incorrect ComponentID format: expect 9-digit string")
    }

    /*
        #############################################################
        ####################### Main Function #######################
        #############################################################
    */

    CarID := args[2]

    // Get the byte payload value matches the ComponentID and CarID on the blockchain
    componentAsBytes, _ := stub.GetState(ComponentID)
    component           := CarComponent{}

    carAsBytes, _       := stub.GetState(CarID)
    car                 := Car{}

    // Decode the JSON format to CarComponent and Car Interface
    json.Unmarshal(componentAsBytes, &component)
    json.Unmarshal(carAsBytes, &car)

    // Check if component already Retired
    if component.Retired {
        return shim.Error("The given component is already Retired.")
    }

    // Check if component already mounted
    if !strings.EqualFold(component.CarID, "") {
        return shim.Error("The given component is already mounted.")
    }

    // Check that the car have any mounted component
    if !strings.EqualFold(car.ComponentID, "") {
        return shim.Error("The given car already mounted with component")
    }

    // Update the component and car
    component.CarID = CarID
    car.ComponentID = ComponentID

    // Encode and upload the component to the blockchain
    componentAsBytes, _ = json.Marshal(component)
    carAsBytes, _       = json.Marshal(car)

    err := stub.PutState(ComponentID, componentAsBytes)
    if err != nil {
        return shim.Error(err.Error())
    }
    err = stub.PutState(CarID, carAsBytes)
    if err != nil {
        return shim.Error(err.Error())
    }

    fmt.Println("Mounted", component, "onto", car, "by", rolename)

    // return peer success response
    return shim.Success(nil)
}


/*
    #############################################################
    ################# Replace Car Component #####################
    #############################################################
*/


/*
    Replace the old car component with the given new car component
    Using the CarID to find the Car on blockchain, and then make
    sure that:
    (1) This car alreay have component mounted;
    (2) The replaced ComponentID shuold now be Retired.

    Only Manufature can replace component
    @stub:      the chaincode interface
    @args[0]:   the role of the function invoker
    @args[1]:   ComponentID
    @args[2]:   CarID
*/
func (s *SmartContract) ReplaceComponent(stub shim.ChaincodeStubInterface, args []string) peer.Response {

    /*
        #############################################################
        #################### Arguments Checking #####################
        #############################################################
    */

    if len(args) != 3 {
        return shim.Error("Incorrect number of argument: expect 3.")
    }

    // Get the first part of the input as the role of invoker
    rolename    := args[0]
    role        := strings.Split(rolename, ".")[0]

    // Role checking: only can be called by supplier
    if !strings.EqualFold(role, "Manufacture") {
        return shim.Error("Incorrect role: expect Manufacture.")
    }

    ComponentID := args[1]

    // Check component ID format
    if !CheckIDFormat(ComponentID) {
        return shim.Error("Incorrect ComponentID format: expect 9-digit string")
    }


    /*
        #############################################################
        ####################### Main Function #######################
        #############################################################
    */

    CarID := args[2]
    
    // Get the byte payload value matches the ComponentID and CarID on the blockchain
    componentAsBytes, _ := stub.GetState(ComponentID)
    component           := CarComponent{}

    carAsBytes, _       := stub.GetState(CarID)
    car                 := Car{}

    // Decode the JSON format to CarComponent and Car Interface
    json.Unmarshal(componentAsBytes, &component)
    json.Unmarshal(carAsBytes, &car)


    // Check if component already Retired
    if component.Retired {
        return shim.Error("The given component is already Retired.")
    }

    // Check if component already mounted
    if !strings.EqualFold(component.CarID, "") {
        return shim.Error("The given component is already mounted.")
    }   // note: component is the new one

    // Check if this car is properly mounted with some comonent
    if strings.EqualFold(car.ComponentID, "") {
        return shim.Error("This car doesn't have an old component mounted")
    }

    // Get the old component information
    oldComponentID          := car.ComponentID
    oldComponentAsBytes, _  := stub.GetState(oldComponentID)
    oldComponent            := CarComponent{}
    json.Unmarshal(oldComponentAsBytes, &oldComponent)

    // Update the information of the new component and the car
    component.Retired       = false
    component.Owner         = oldComponent.Owner
    component.CarID         = CarID
    car.ComponentID         = ComponentID

    // We just mark this component as Retired, but we don't want to delete it.
    // Since we need to make sure that it is never used again in other place.
    oldComponent.Retired    = true
    oldComponent.Owner      = rolename
    oldComponent.CarID      = ""

    // Encoding all two components and the car
    componentAsBytes, _     = json.Marshal(component)
    carAsBytes, _           = json.Marshal(car)
    oldComponentAsBytes, _  = json.Marshal(oldComponent)

    // Update the world states
    stub.PutState(ComponentID, componentAsBytes)
    stub.PutState(CarID, carAsBytes)
    stub.PutState(oldComponentID, oldComponentAsBytes)

    fmt.Println("Replaced", oldComponent, "by", component, "on car", car, "by", rolename)

    return shim.Success(nil);
}

/*
    #############################################################
    #################### Recall Car Component ###################
    #############################################################
*/

/*
    Recall the component by manufacture: a component being recalled will be Retired

    Only Manufacture can call recall components
    @stub:      the chaincode interface
    @args[0]:   ROLE
    @args[1]:   ComponentID
*/
func (s *SmartContract) RecallComponent(stub shim.ChaincodeStubInterface, args []string) peer.Response {
    

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
    role        := strings.Split(rolename, ".")[0]

    // Role checking: only can be called by supplier
    if !strings.EqualFold(role, "Manufacture") {
        return shim.Error("Incorrect role: expect Manufacture.")
    }

    ComponentID := args[1]

    // Check component ID format
    if !CheckIDFormat(ComponentID) {
        return shim.Error("Incorrect ComponentID format: expect 9-digit string")
    }


    /*
        #############################################################
        ####################### Main Function #######################
        #############################################################
    */
    
    // Get the byte payload value matches the ComponentID and CarID on the blockchain
    componentAsBytes, _ := stub.GetState(ComponentID)
    component           := CarComponent{}
    json.Unmarshal(componentAsBytes, &component)


    // Check if component already Retired
    if component.Retired {
        return shim.Error("The given component is already Retired.")
    }

    // // Check if component already mounted
    // if strings.EqualFold(component.CarID, "") {
    //     return shim.Error("The given component is not mounted.")
    // }
    // We don't need to check it the component is mounted, because our
    // goal is to retire it.

    component.Retired   = true
    component.Owner     = rolename   // let this manufacture be the own
    component.CarID     = ""

    componentAsBytes, _ = json.Marshal(component)
    stub.PutState(ComponentID, componentAsBytes)

    fmt.Println("Recalled", component, "by", rolename)

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

