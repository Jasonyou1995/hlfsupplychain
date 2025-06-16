package main

import (
	"encoding/json"
	"fmt"
	"log"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// SupplyChainContract represents the contract for supply chain management
type SupplyChainContract struct {
	contractapi.Contract
}

// Product represents a product in the supply chain
type Product struct {
	ID               string            `json:"id"`
	Name             string            `json:"name"`
	Description      string            `json:"description"`
	ManufacturerID   string            `json:"manufacturerId"`
	BatchID          string            `json:"batchId"`
	CreatedAt        time.Time         `json:"createdAt"`
	UpdatedAt        time.Time         `json:"updatedAt"`
	Status           string            `json:"status"` // created, shipped, delivered, recalled
	CurrentLocation  string            `json:"currentLocation"`
	Temperature      float64           `json:"temperature"`
	Humidity         float64           `json:"humidity"`
	QualityMetrics   map[string]string `json:"qualityMetrics"`
	Certifications   []string          `json:"certifications"`
	SupplyChainSteps []TrackingEvent   `json:"supplyChainSteps"`
}

// TrackingEvent represents an event in the supply chain
type TrackingEvent struct {
	ID          string            `json:"id"`
	ProductID   string            `json:"productId"`
	EventType   string            `json:"eventType"` // manufactured, shipped, received, quality_check, etc.
	Timestamp   time.Time         `json:"timestamp"`
	Location    string            `json:"location"`
	ActorID     string            `json:"actorId"`
	ActorType   string            `json:"actorType"` // manufacturer, supplier, logistics, retailer, auditor
	Data        map[string]string `json:"data"`
	Temperature float64           `json:"temperature"`
	Humidity    float64           `json:"humidity"`
	Verified    bool              `json:"verified"`
}

// ProductPrivateData represents private data that only certain organizations can access
type ProductPrivateData struct {
	ProductID            string   `json:"productId"`
	CostPrice            float64  `json:"costPrice"`
	SupplierID           string   `json:"supplierId"`
	ManufacturingDetails string   `json:"manufacturingDetails"`
	QualityIssues        []string `json:"qualityIssues"`
}

// ProductQueryResult structure used for handling result of query
type ProductQueryResult struct {
	Key    string   `json:"Key"`
	Record *Product `json:"Record"`
}

// HistoryQueryResult structure used for returning result of history query
type HistoryQueryResult struct {
	TxId      string    `json:"txId"`
	Timestamp time.Time `json:"timestamp"`
	Record    *Product  `json:"record"`
	IsDelete  bool      `json:"isDelete"`
}

// InitLedger initializes the ledger with sample data
func (s *SupplyChainContract) InitLedger(ctx contractapi.TransactionContextInterface) error {
	products := []Product{
		{
			ID:              "PROD001",
			Name:            "Automotive Battery",
			Description:     "High-performance lithium-ion battery for electric vehicles",
			ManufacturerID:  "MANUFACTURER001",
			BatchID:         "BATCH001",
			CreatedAt:       time.Now(),
			UpdatedAt:       time.Now(),
			Status:          "created",
			CurrentLocation: "Manufacturing Plant A",
			Temperature:     22.5,
			Humidity:        45.0,
			QualityMetrics: map[string]string{
				"voltage":  "12.6V",
				"capacity": "100Ah",
				"weight":   "25kg",
			},
			Certifications: []string{"ISO9001", "UL1973", "UN38.3"},
			SupplyChainSteps: []TrackingEvent{
				{
					ID:          "EVENT001",
					ProductID:   "PROD001",
					EventType:   "manufactured",
					Timestamp:   time.Now(),
					Location:    "Manufacturing Plant A",
					ActorID:     "MANUFACTURER001",
					ActorType:   "manufacturer",
					Data:        map[string]string{"quality_grade": "A+"},
					Temperature: 22.5,
					Humidity:    45.0,
					Verified:    true,
				},
			},
		},
		{
			ID:              "PROD002",
			Name:            "ECU Module",
			Description:     "Electronic Control Unit for automotive systems",
			ManufacturerID:  "MANUFACTURER001",
			BatchID:         "BATCH002",
			CreatedAt:       time.Now(),
			UpdatedAt:       time.Now(),
			Status:          "shipped",
			CurrentLocation: "Logistics Hub B",
			Temperature:     20.0,
			Humidity:        40.0,
			QualityMetrics: map[string]string{
				"firmware_version": "2.1.5",
				"test_cycles":      "10000",
				"error_rate":       "0.001%",
			},
			Certifications: []string{"ISO26262", "FCC", "CE"},
			SupplyChainSteps: []TrackingEvent{
				{
					ID:          "EVENT002",
					ProductID:   "PROD002",
					EventType:   "manufactured",
					Timestamp:   time.Now().Add(-24 * time.Hour),
					Location:    "Manufacturing Plant A",
					ActorID:     "MANUFACTURER001",
					ActorType:   "manufacturer",
					Data:        map[string]string{"quality_grade": "A"},
					Temperature: 22.0,
					Humidity:    42.0,
					Verified:    true,
				},
				{
					ID:          "EVENT003",
					ProductID:   "PROD002",
					EventType:   "shipped",
					Timestamp:   time.Now().Add(-12 * time.Hour),
					Location:    "Logistics Hub B",
					ActorID:     "LOGISTICS001",
					ActorType:   "logistics",
					Data:        map[string]string{"transport_mode": "truck", "carrier": "LogiCorp"},
					Temperature: 20.0,
					Humidity:    40.0,
					Verified:    true,
				},
			},
		},
	}

	for _, product := range products {
		productJSON, err := json.Marshal(product)
		if err != nil {
			return err
		}

		err = ctx.GetStub().PutState(product.ID, productJSON)
		if err != nil {
			return fmt.Errorf("failed to put product %s to world state: %v", product.ID, err)
		}
	}

	return nil
}

// CreateProduct creates a new product in the supply chain
func (s *SupplyChainContract) CreateProduct(ctx contractapi.TransactionContextInterface, id string, name string, description string, manufacturerID string, batchID string) error {
	// Check if product already exists
	exists, err := s.ProductExists(ctx, id)
	if err != nil {
		return err
	}
	if exists {
		return fmt.Errorf("product %s already exists", id)
	}

	// Validate input
	if id == "" || name == "" || manufacturerID == "" {
		return fmt.Errorf("invalid input: id, name, and manufacturerID are required")
	}

	// Get transaction timestamp
	txTimestamp, err := ctx.GetStub().GetTxTimestamp()
	if err != nil {
		return err
	}
	timestamp := time.Unix(txTimestamp.Seconds, int64(txTimestamp.Nanos))

	// Create initial tracking event
	initialEvent := TrackingEvent{
		ID:          fmt.Sprintf("%s_CREATE", id),
		ProductID:   id,
		EventType:   "manufactured",
		Timestamp:   timestamp,
		Location:    "Manufacturing Plant",
		ActorID:     manufacturerID,
		ActorType:   "manufacturer",
		Data:        map[string]string{"creation_method": "automated"},
		Temperature: 22.0,
		Humidity:    45.0,
		Verified:    false, // Will be verified by quality control
	}

	product := Product{
		ID:               id,
		Name:             name,
		Description:      description,
		ManufacturerID:   manufacturerID,
		BatchID:          batchID,
		CreatedAt:        timestamp,
		UpdatedAt:        timestamp,
		Status:           "created",
		CurrentLocation:  "Manufacturing Plant",
		Temperature:      22.0,
		Humidity:         45.0,
		QualityMetrics:   make(map[string]string),
		Certifications:   []string{},
		SupplyChainSteps: []TrackingEvent{initialEvent},
	}

	productJSON, err := json.Marshal(product)
	if err != nil {
		return err
	}

	// Set endorsement policy for this product (requires manufacturer + one other org)
	err = ctx.GetStub().SetStateValidationParameter(id, []byte("OR('ManufacturerMSP.member', AND('SupplierMSP.member', 'LogisticsMSP.member'))"))
	if err != nil {
		return fmt.Errorf("failed to set state validation parameter: %v", err)
	}

	return ctx.GetStub().PutState(id, productJSON)
}

// ReadProduct retrieves a product from the ledger
func (s *SupplyChainContract) ReadProduct(ctx contractapi.TransactionContextInterface, id string) (*Product, error) {
	productJSON, err := ctx.GetStub().GetState(id)
	if err != nil {
		return nil, fmt.Errorf("failed to read product %s from world state: %v", id, err)
	}
	if productJSON == nil {
		return nil, fmt.Errorf("product %s does not exist", id)
	}

	var product Product
	err = json.Unmarshal(productJSON, &product)
	if err != nil {
		return nil, err
	}

	return &product, nil
}

// UpdateProduct updates an existing product
func (s *SupplyChainContract) UpdateProduct(ctx contractapi.TransactionContextInterface, id string, status string, location string, temperature float64, humidity float64) error {
	product, err := s.ReadProduct(ctx, id)
	if err != nil {
		return err
	}

	// Get transaction details
	txTimestamp, err := ctx.GetStub().GetTxTimestamp()
	if err != nil {
		return err
	}
	timestamp := time.Unix(txTimestamp.Seconds, int64(txTimestamp.Nanos))

	// Get client identity
	clientID, err := s.GetSubmittingClientIdentity(ctx)
	if err != nil {
		return err
	}

	// Create tracking event
	updateEvent := TrackingEvent{
		ID:          fmt.Sprintf("%s_UPDATE_%d", id, timestamp.Unix()),
		ProductID:   id,
		EventType:   "status_update",
		Timestamp:   timestamp,
		Location:    location,
		ActorID:     clientID,
		ActorType:   "system",
		Data:        map[string]string{"previous_status": product.Status},
		Temperature: temperature,
		Humidity:    humidity,
		Verified:    true,
	}

	// Update product
	product.Status = status
	product.CurrentLocation = location
	product.Temperature = temperature
	product.Humidity = humidity
	product.UpdatedAt = timestamp
	product.SupplyChainSteps = append(product.SupplyChainSteps, updateEvent)

	productJSON, err := json.Marshal(product)
	if err != nil {
		return err
	}

	// Emit event for off-chain applications
	err = ctx.GetStub().SetEvent("ProductUpdated", productJSON)
	if err != nil {
		return fmt.Errorf("failed to emit event: %v", err)
	}

	return ctx.GetStub().PutState(id, productJSON)
}

// AddTrackingEvent adds a new tracking event to a product
func (s *SupplyChainContract) AddTrackingEvent(ctx contractapi.TransactionContextInterface, productID string, eventType string, location string, data string) error {
	product, err := s.ReadProduct(ctx, productID)
	if err != nil {
		return err
	}

	// Get transaction details
	txTimestamp, err := ctx.GetStub().GetTxTimestamp()
	if err != nil {
		return err
	}
	timestamp := time.Unix(txTimestamp.Seconds, int64(txTimestamp.Nanos))

	// Get client identity
	clientID, err := s.GetSubmittingClientIdentity(ctx)
	if err != nil {
		return err
	}

	// Parse additional data
	var eventData map[string]string
	if data != "" {
		err = json.Unmarshal([]byte(data), &eventData)
		if err != nil {
			return fmt.Errorf("invalid data JSON: %v", err)
		}
	} else {
		eventData = make(map[string]string)
	}

	// Create tracking event
	trackingEvent := TrackingEvent{
		ID:          fmt.Sprintf("%s_%s_%d", productID, eventType, timestamp.Unix()),
		ProductID:   productID,
		EventType:   eventType,
		Timestamp:   timestamp,
		Location:    location,
		ActorID:     clientID,
		ActorType:   "unknown", // Could be enhanced to detect org type
		Data:        eventData,
		Temperature: product.Temperature,
		Humidity:    product.Humidity,
		Verified:    false, // Requires verification
	}

	// Add event to product
	product.SupplyChainSteps = append(product.SupplyChainSteps, trackingEvent)
	product.UpdatedAt = timestamp

	productJSON, err := json.Marshal(product)
	if err != nil {
		return err
	}

	// Emit event
	eventJSON, _ := json.Marshal(trackingEvent)
	err = ctx.GetStub().SetEvent("TrackingEventAdded", eventJSON)
	if err != nil {
		return fmt.Errorf("failed to emit event: %v", err)
	}

	return ctx.GetStub().PutState(productID, productJSON)
}

// DeleteProduct removes a product from the ledger
func (s *SupplyChainContract) DeleteProduct(ctx contractapi.TransactionContextInterface, id string) error {
	exists, err := s.ProductExists(ctx, id)
	if err != nil {
		return err
	}
	if !exists {
		return fmt.Errorf("product %s does not exist", id)
	}

	return ctx.GetStub().DelState(id)
}

// ProductExists checks if a product exists in the ledger
func (s *SupplyChainContract) ProductExists(ctx contractapi.TransactionContextInterface, id string) (bool, error) {
	productJSON, err := ctx.GetStub().GetState(id)
	if err != nil {
		return false, fmt.Errorf("failed to read product %s from world state: %v", id, err)
	}

	return productJSON != nil, nil
}

// GetAllProducts returns all products in the ledger
func (s *SupplyChainContract) GetAllProducts(ctx contractapi.TransactionContextInterface) ([]*Product, error) {
	resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
	if err != nil {
		return nil, err
	}
	defer resultsIterator.Close()

	var products []*Product
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, err
		}

		var product Product
		err = json.Unmarshal(queryResponse.Value, &product)
		if err != nil {
			return nil, err
		}
		products = append(products, &product)
	}

	return products, nil
}

// QueryProductsByManufacturer queries products by manufacturer ID
func (s *SupplyChainContract) QueryProductsByManufacturer(ctx contractapi.TransactionContextInterface, manufacturerID string) ([]*Product, error) {
	queryString := fmt.Sprintf(`{"selector":{"manufacturerId":"%s"}}`, manufacturerID)
	return s.getQueryResultForQueryString(ctx, queryString)
}

// QueryProductsByStatus queries products by status
func (s *SupplyChainContract) QueryProductsByStatus(ctx contractapi.TransactionContextInterface, status string) ([]*Product, error) {
	queryString := fmt.Sprintf(`{"selector":{"status":"%s"}}`, status)
	return s.getQueryResultForQueryString(ctx, queryString)
}

// GetProductHistory returns the history of changes for a product
func (s *SupplyChainContract) GetProductHistory(ctx contractapi.TransactionContextInterface, productID string) ([]HistoryQueryResult, error) {
	resultsIterator, err := ctx.GetStub().GetHistoryForKey(productID)
	if err != nil {
		return nil, err
	}
	defer resultsIterator.Close()

	var records []HistoryQueryResult
	for resultsIterator.HasNext() {
		response, err := resultsIterator.Next()
		if err != nil {
			return nil, err
		}

		var product Product
		if len(response.Value) > 0 {
			err = json.Unmarshal(response.Value, &product)
			if err != nil {
				return nil, err
			}
		}

		timestamp := time.Unix(response.Timestamp.Seconds, int64(response.Timestamp.Nanos))

		record := HistoryQueryResult{
			TxId:      response.TxId,
			Timestamp: timestamp,
			Record:    &product,
			IsDelete:  response.IsDelete,
		}
		records = append(records, record)
	}

	return records, nil
}

// Private Data Functions

// CreatePrivateProductData creates private data for a product
func (s *SupplyChainContract) CreatePrivateProductData(ctx contractapi.TransactionContextInterface, collection string) error {
	// Get private data from transient map
	transientMap, err := ctx.GetStub().GetTransient()
	if err != nil {
		return fmt.Errorf("error getting transient: %v", err)
	}

	privateDataJSON, ok := transientMap["product_private_data"]
	if !ok {
		return fmt.Errorf("product_private_data not found in the transient map")
	}

	var privateData ProductPrivateData
	err = json.Unmarshal(privateDataJSON, &privateData)
	if err != nil {
		return fmt.Errorf("failed to unmarshal private data: %v", err)
	}

	// Verify product exists
	exists, err := s.ProductExists(ctx, privateData.ProductID)
	if err != nil {
		return err
	}
	if !exists {
		return fmt.Errorf("product %s does not exist", privateData.ProductID)
	}

	// Store private data
	return ctx.GetStub().PutPrivateData(collection, privateData.ProductID, privateDataJSON)
}

// ReadPrivateProductData reads private data for a product
func (s *SupplyChainContract) ReadPrivateProductData(ctx contractapi.TransactionContextInterface, collection string, productID string) (*ProductPrivateData, error) {
	privateDataJSON, err := ctx.GetStub().GetPrivateData(collection, productID)
	if err != nil {
		return nil, fmt.Errorf("failed to read private data: %v", err)
	}
	if privateDataJSON == nil {
		return nil, fmt.Errorf("private data for product %s does not exist in collection %s", productID, collection)
	}

	var privateData ProductPrivateData
	err = json.Unmarshal(privateDataJSON, &privateData)
	if err != nil {
		return nil, err
	}

	return &privateData, nil
}

// Utility Functions

// getQueryResultForQueryString executes the passed query string
func (s *SupplyChainContract) getQueryResultForQueryString(ctx contractapi.TransactionContextInterface, queryString string) ([]*Product, error) {
	resultsIterator, err := ctx.GetStub().GetQueryResult(queryString)
	if err != nil {
		return nil, err
	}
	defer resultsIterator.Close()

	var products []*Product
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, err
		}

		var product Product
		err = json.Unmarshal(queryResponse.Value, &product)
		if err != nil {
			return nil, err
		}
		products = append(products, &product)
	}

	return products, nil
}

// GetSubmittingClientIdentity returns the identity of the submitting client
func (s *SupplyChainContract) GetSubmittingClientIdentity(ctx contractapi.TransactionContextInterface) (string, error) {
	id, err := ctx.GetClientIdentity().GetID()
	if err != nil {
		return "", fmt.Errorf("failed to get client identity: %v", err)
	}
	return id, nil
}

// Smart Contract Event Functions

// EmitProductAlert emits an alert for a product (e.g., quality issue, recall)
func (s *SupplyChainContract) EmitProductAlert(ctx contractapi.TransactionContextInterface, productID string, alertType string, message string) error {
	// Verify product exists
	exists, err := s.ProductExists(ctx, productID)
	if err != nil {
		return err
	}
	if !exists {
		return fmt.Errorf("product %s does not exist", productID)
	}

	// Create alert payload
	alert := map[string]interface{}{
		"productId": productID,
		"alertType": alertType,
		"message":   message,
		"timestamp": time.Now(),
		"severity":  "high",
	}

	alertJSON, err := json.Marshal(alert)
	if err != nil {
		return err
	}

	// Emit event
	return ctx.GetStub().SetEvent("ProductAlert", alertJSON)
}

func main() {
	supplyChainContract := new(SupplyChainContract)

	cc, err := contractapi.NewChaincode(supplyChainContract)
	if err != nil {
		log.Panicf("Error creating supply chain chaincode: %v", err)
	}

	if err := cc.Start(); err != nil {
		log.Panicf("Error starting supply chain chaincode: %v", err)
	}
}
