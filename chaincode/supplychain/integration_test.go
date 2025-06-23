package main

import (
	"encoding/json"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestProductSerialization(t *testing.T) {
	product := Product{
		ID:             "PROD001",
		Name:           "Test Product",
		Description:    "Test Description",
		ManufacturerID: "MFG001",
		BatchID:        "BATCH001",
		Status:         "created",
		QualityMetrics: map[string]string{
			"quality": "A+",
			"weight":  "10kg",
		},
		Certifications: []string{"ISO9001", "CE"},
	}

	productJSON, err := json.Marshal(product)
	assert.NoError(t, err)
	assert.NotEmpty(t, productJSON)

	var unmarshalled Product
	err = json.Unmarshal(productJSON, &unmarshalled)
	assert.NoError(t, err)
	assert.Equal(t, product.ID, unmarshalled.ID)
	assert.Equal(t, product.Name, unmarshalled.Name)
	assert.Equal(t, product.Status, unmarshalled.Status)
	assert.Equal(t, len(product.QualityMetrics), len(unmarshalled.QualityMetrics))
	assert.Equal(t, len(product.Certifications), len(unmarshalled.Certifications))
}

func TestTrackingEventSerialization(t *testing.T) {
	event := TrackingEvent{
		ID:        "EVENT001",
		ProductID: "PROD001",
		EventType: "quality_check",
		Location:  "QA Lab",
		ActorID:   "QA001",
		ActorType: "quality_control",
		Data: map[string]string{
			"result": "passed",
			"score":  "95",
		},
		Temperature: 22.5,
		Humidity:    45.0,
		Verified:    true,
	}

	eventJSON, err := json.Marshal(event)
	assert.NoError(t, err)
	assert.NotEmpty(t, eventJSON)

	var unmarshalled TrackingEvent
	err = json.Unmarshal(eventJSON, &unmarshalled)
	assert.NoError(t, err)
	assert.Equal(t, event.ID, unmarshalled.ID)
	assert.Equal(t, event.ProductID, unmarshalled.ProductID)
	assert.Equal(t, event.EventType, unmarshalled.EventType)
	assert.Equal(t, event.Verified, unmarshalled.Verified)
	assert.Equal(t, len(event.Data), len(unmarshalled.Data))
}

func TestProductPrivateDataSerialization(t *testing.T) {
	privateData := ProductPrivateData{
		ProductID:            "PROD001",
		CostPrice:            99.99,
		SupplierID:           "SUPPLIER001",
		ManufacturingDetails: "Manufactured in facility A with process X",
		QualityIssues:        []string{"minor scratch", "color variation"},
	}

	dataJSON, err := json.Marshal(privateData)
	assert.NoError(t, err)
	assert.NotEmpty(t, dataJSON)

	var unmarshalled ProductPrivateData
	err = json.Unmarshal(dataJSON, &unmarshalled)
	assert.NoError(t, err)
	assert.Equal(t, privateData.ProductID, unmarshalled.ProductID)
	assert.Equal(t, privateData.CostPrice, unmarshalled.CostPrice)
	assert.Equal(t, privateData.SupplierID, unmarshalled.SupplierID)
	assert.Equal(t, len(privateData.QualityIssues), len(unmarshalled.QualityIssues))
}

func TestContractInstantiation(t *testing.T) {
	contract := new(SupplyChainContract)
	assert.NotNil(t, contract)
}

func TestConstantsExist(t *testing.T) {
	assert.Equal(t, "productPrivateData", ProductCollection)
	assert.Equal(t, "ProductCreated", EventProductCreated)
	assert.Equal(t, "ProductUpdated", EventProductUpdated)
	assert.Equal(t, "TrackingEventAdded", EventTrackingAdded)
	assert.Equal(t, "ProductAlert", EventProductAlert)
}

func BenchmarkProductSerialization(b *testing.B) {
	product := Product{
		ID:             "PROD001",
		Name:           "Test Product",
		Description:    "Test Description",
		ManufacturerID: "MFG001",
		BatchID:        "BATCH001",
		Status:         "created",
		QualityMetrics: map[string]string{
			"quality": "A+",
			"weight":  "10kg",
		},
		Certifications: []string{"ISO9001", "CE"},
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, err := json.Marshal(product)
		if err != nil {
			b.Fatal(err)
		}
	}
}

func BenchmarkProductDeserialization(b *testing.B) {
	product := Product{
		ID:             "PROD001",
		Name:           "Test Product",
		Description:    "Test Description",
		ManufacturerID: "MFG001",
		BatchID:        "BATCH001",
		Status:         "created",
		QualityMetrics: map[string]string{
			"quality": "A+",
			"weight":  "10kg",
		},
		Certifications: []string{"ISO9001", "CE"},
	}

	productJSON, _ := json.Marshal(product)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		var unmarshalled Product
		err := json.Unmarshal(productJSON, &unmarshalled)
		if err != nil {
			b.Fatal(err)
		}
	}
}
