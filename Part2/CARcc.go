/*
    Author:           Jason You All Rights Reserved
    Last modified:    March 6 2019
    Project:          Car Components Supply Chain

    SPDX-License-Identifier: Apache-2.0               

    Please save this chaincode in the proper PATH.

    This chaincode is for demonstration only, not
    real business usage.                            */



package main

import (

    "encoding/json"
    "fmt"
    "strconv"
    "strings"
    "errors"

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
	
    CarID		string  `json:"carid"`

}

// Car that stores the ComponentID mounted on it
// We only record one component for convinence,
// but we can use veracity string if we want
type Car struct {

    
    ComponentID  string `json:"ComponentID`    

}

// The creator structure (Task 3)
type Creator struct {

    Mspid       string `json:"Mspid"`
    
    IdBytes     string `json:"IdBytes"`

}

/*
    #############################################################
    #############################################################
    ############# Initialization of Interface ###################
    #############################################################
    #############################################################
*/

/*
    This function is called when this chaincode is instantiated.
    We have a separate function for ledger instantiation: see initLedger()
*/
func (s *SmartContract) Init(stub shim.ChaincodeStubInterface) peer.Response {
    
    // No action, because there is no components at the very beginning

    return shim.Success(nil)

}


/*
    #############################################################
    #############################################################
    ##################### Invoke the chaincode ##################
    #############################################################
    #############################################################
*/

/*

    Invoking by calling the specified function
    
    Privilege:  ANYONE

    @fn:        The function name
    @args:      All the arguments passed to that function

*/
func (s *SmartContract) Invoke(stub shim.ChaincodeStubInterface) peer.Response {
    
    fn, args := stub.GetFunctionAndParameters()

    if fn == "AddComponent" {

		return s.AddComponent(stub, args)

	} else if fn == "TransferComponent" {

		return s.TransferComponent(stub, args)

	} else if fn == "MountComponent" {

		return s.MountComponent(stub, args)

	} else if fn == "ReplaceComponent" {

		return s.ReplaceComponent(stub, args)

	} else if fn == "RecallComponent" {

		return s.RecallComponent(stub, args)

	} else if fn == "InitLedger" {

        return s.InitLedger(stub)

    } else if fn == "CreateCar" {

        return s.CreateCar(stub, args)

    } else if fn == "QueryCar" {

        return s.QueryCar(stub, args)

    } else if fn == "QueryComponent" {

        return s.QueryComponent(stub, args)
    }

    return shim.Error("Invalid Smart Contract function name.")
        
}


/*
    #############################################################
    #############################################################
    ################## Initializing Ledger ######################
    #############################################################
    #############################################################
*/

/*

    Initializing this ledger with multiple sample components for testing purpose.

    Privilege: ANYONE

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
    i := 0

    var ComponentID string

    for i < len(components) {

        fmt.Println("i = ", i, "component is", components[i])

        componentAsBytes, _ := json.Marshal(components[i])

        ComponentID = "00000000" + strconv.Itoa(i)

        stub.PutState(ComponentID, componentAsBytes)

        fmt.Println("[+] Added", components[i], "with ComponentID:", ComponentID, "Marshal form:", componentAsBytes)

        i = i + 1       // increment here

    }

    return shim.Success(nil)

}


/*
    #############################################################
    #############################################################
    ################### Add Car Component #######################
    #############################################################
    #############################################################
*/

/*

    Add car component

    ONLY called by Supplier

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
    creatorAsBytes, _   := stub.GetCreator()     // get the real identity of client
    creator             := Creator{}
    json.Unmarshal(creatorAsBytes, &creator)
    fmt.Println("[+] creator:", creator)
    fmt.Println("[+] creator.Mspid", creator.Mspid)
    fmt.Println("[+] creator.IdBytes", creator.IdBytes)
    fmt.Println("[+] creator.IdBytes", creatorAsBytes)

    // TODO: Design idea:
    // Once get the Mspid, we can verify that Org1 -> Supplier
    //                                        Org2 -> Manufacture
    // Then we just set "component.owner = creator.IdBytes"
    // 


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
    component := CarComponent{false, rolename, ""}

    // Encoding the component as byte payload in JSON format
    componentAsBytes, _ := json.Marshal(component)

    err := stub.PutState(ComponentID, componentAsBytes)

    if err != nil {

        return shim.Error(err.Error())

    }

    // Output result to the server
    fmt.Println("[+] Added", component, "by", rolename)

    // return peer success response
    return shim.Success(nil)
}


/*
    #############################################################
    #############################################################
    ################# Transfer Car Component ####################
    #############################################################
    #############################################################
*/

/*

    Transfer the Ownership of car components

    ONLY called by the Owner

    @stub:      the chaincode interface
    @args[0]:   Role of the invoker
    @args[1]:   New Owner
    @args[2]:   ComponentID

*/
func (s *SmartContract) TransferComponent(stub shim.ChaincodeStubInterface, args []string) peer.Response {

    /*
        #############################################################
        #################### Arguments Checking #####################
        #############################################################
    */

    if len(args) != 3 {

        return shim.Error("Incorrect number of arguments, expecting 3.")

    }

    ComponentID := args[2]

     // Check component ID format
    if !CheckIDFormat(ComponentID) {

        return shim.Error("Incorrect ComponentID format: expect 9-digit string")

    }

    /*
        #############################################################
        ####################### Main Function #######################
        #############################################################
    */

    // Here we just use the full role type and name for easy checking
    rolename := args[0]

    // New Owner shuold be format like: ROLE_TYPE.ROLE_NAME
    newOwner    := args[1]

    // Get the byte payload value matches the ComponentID on the blockchain
    componentAsBytes, _ := stub.GetState(ComponentID)

    component := CarComponent{}

    // Decode the JSON format to CarComponent Interface
    json.Unmarshal(componentAsBytes, &component)
    
    // Role checking: only the Owner can transfer the component
    oldOwner := component.Owner

    if !strings.EqualFold(oldOwner, rolename) {

        fmt.Println("[+] TransferComponent: oldOwner is", oldOwner, "rolename is", rolename)

        return shim.Error("You are not the Owner of this component, so cannot transfer it.")

    }

    // Update the Owner of this componet
    component.Owner = newOwner

    // Encode and upload to the blockchain with the ComponentID to be the key
    componentAsBytes, _ = json.Marshal(component)

    err := stub.PutState(ComponentID, componentAsBytes)

    if err != nil {

        return shim.Error(err.Error())

    }

    fmt.Println("[+] Transfered", component, "from", oldOwner, "to", newOwner, "by", rolename)

    // return peer success response
    return shim.Success(nil)

}


/*
    #############################################################
    #############################################################
    #################### Mount Car Component ####################
    #############################################################
    #############################################################
*/

/*

    Mount car components to the car, make sure that:
    (1) The car is new
    (2) The component is new

    ONLY called by Manufacture

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
    #############################################################
    ################# Replace Car Component #####################
    #############################################################
    #############################################################
*/


/*

    Replace the old car component with the given new car component
    Using the CarID to find the Car on blockchain, and then make
    sure that:
    (1) This car alreay have component mounted;
    (2) The replaced ComponentID shuold now be Retired.

    ONLY Manufature can replace component

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

    ONLY Manufacture can call recall components

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
    #############################################################
    ################## Check Car Component ######################
    #############################################################
    #############################################################
*/


/*

    Returns the validity of this component: true if valide, false otherwise
    This function is similar to a helper function, and can only be called
    by other functions with "role" and caller equals to "Car", not any invokers.

    @handler:   Car struct pointer
    @stub:      The chaincode stub interface
    @role:      the ROLE of the caller (must be Car)
    
    Returns (bool, error) types

*/
func (car *Car) CheckComponent(stub shim.ChaincodeStubInterface, role string) (bool, error) {


    /*
        #############################################################
        #################### Arguments Checking #####################
        #############################################################
    */

    if !strings.EqualFold(role, "Car") {

        return false, errors.New("Incorrect role, expect Car")

    }

    /*
        #############################################################
        ####################### Main Function #######################
        #############################################################
    */

    ComponentID := car.ComponentID

    if strings.EqualFold(ComponentID, "") {

        return false, errors.New("Got empty ComponentID from Car object")

    }

    componentAsBytes, _ := stub.GetState(ComponentID)

    component           := CarComponent{}

    json.Unmarshal(componentAsBytes, &component)

    return (!component.Retired), nil

}

/*
    #############################################################
    #############################################################
    #################### My Helper Functions ############3#######
    #############################################################
    #############################################################
*/

/*
    Check the ID format of car component: should be 9-digit string
    
    Return true if format is correct, and false otherwise
*/
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

    Creating a simple car onto the blockchain network (for test purpose)

    ONLY Manufacture can run this function, because only it can MountComponent,

    which means it is the first point to record a new incoming car.

    @args[0]: ROLE
    @args[1]: ComponentID
    @args[2]: CarID

*/
func (s *SmartContract) CreateCar(stub shim.ChaincodeStubInterface, args []string) peer.Response {

    /*
        #############################################################
        #################### Arguments Checking #####################
        #############################################################
    */

    if len(args) != 3 {

        return shim.Error("Incorrect number of argument: expect 3.")

    }

    // Get the first part of the input as the role of invoker
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

    CarID := args[2]

    // Recording this new car onto the blockchain
    var car = Car{ComponentID: ComponentID}

    carAsBytes, _ := json.Marshal(car)

    err := stub.PutState(CarID, carAsBytes)

    if err != nil {

        return shim.Error(err.Error())

    }

    fmt.Println("Created a car", car)

    return shim.Success(nil)
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


/*
    TODO: Helper function to query all components
*/


/*
    TODO: Helper function to query all cars
*/



// TODO: RemoveCar, TransferCar, etc.


func main() {

    // Create a new Smart Contract
	err := shim.Start(new(SmartContract))

	if err != nil {

		fmt.Printf("Error starting Simple chaincode: %s", err)

	}

}

