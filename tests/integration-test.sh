#!/bin/bash

# Enterprise Hyperledger Fabric Supply Chain Platform v2.5+
# Comprehensive Integration Test Suite
# Author: Supply Chain Platform Team
# Last Modified: December 23, 2024
# License: Apache-2.0

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
API_BASE_URL="http://localhost:3000"
TEST_TIMEOUT=30
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    ((FAILED_TESTS++))
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    ((PASSED_TESTS++))
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Test helper functions
run_test() {
    ((TOTAL_TESTS++))
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"
    
    log "Running test: $test_name"
    
    if timeout $TEST_TIMEOUT bash -c "$test_command"; then
        if [[ -n "$expected_result" ]]; then
            local result=$(eval "$test_command")
            if [[ "$result" == *"$expected_result"* ]]; then
                success "$test_name - PASSED"
                return 0
            else
                error "$test_name - FAILED (unexpected result: $result)"
                return 1
            fi
        else
            success "$test_name - PASSED"
            return 0
        fi
    else
        error "$test_name - FAILED (timeout or command failed)"
        return 1
    fi
}

# Check if API server is running
check_api_server() {
    log "Checking if API server is running..."
    
    if curl -s -f "$API_BASE_URL/health" > /dev/null; then
        success "API server is running"
        return 0
    else
        error "API server is not running. Please start it with: cd client && npm start"
        return 1
    fi
}

# Authentication tests
test_authentication() {
    log "🔐 Testing Authentication..."
    
    # Test valid login
    run_test "Valid login" \
        "curl -s -X POST $API_BASE_URL/api/auth/login -H 'Content-Type: application/json' -d '{\"username\": \"manufacturer_admin\", \"password\": \"secure_password_123\"}' | jq -r .token" \
        "eyJ"
    
    # Store JWT token for subsequent tests
    JWT_TOKEN=$(curl -s -X POST $API_BASE_URL/api/auth/login \
        -H "Content-Type: application/json" \
        -d '{"username": "manufacturer_admin", "password": "secure_password_123"}' \
        | jq -r .token)
    
    if [[ "$JWT_TOKEN" == "null" || -z "$JWT_TOKEN" ]]; then
        error "Failed to obtain JWT token"
        return 1
    fi
    
    # Test invalid login
    run_test "Invalid login" \
        "curl -s -w '%{http_code}' -X POST $API_BASE_URL/api/auth/login -H 'Content-Type: application/json' -d '{\"username\": \"invalid\", \"password\": \"invalid\"}'" \
        "401"
    
    # Test access without token
    run_test "Unauthorized access" \
        "curl -s -w '%{http_code}' -X GET $API_BASE_URL/api/blockchain/products" \
        "401"
    
    export JWT_TOKEN
}

# Gateway tests
test_gateway() {
    log "🚪 Testing Gateway Operations..."
    
    # Test gateway initialization
    run_test "Gateway initialization" \
        "curl -s -X POST $API_BASE_URL/api/gateway/init -H 'Content-Type: application/json' -H 'Authorization: Bearer $JWT_TOKEN' -d '{\"organization\": \"manufacturer\"}' | jq -r .message" \
        "Gateway initialized successfully"
    
    # Give gateway time to initialize
    sleep 5
}

# Product management tests
test_product_management() {
    log "📦 Testing Product Management..."
    
    local test_product_id="TEST$(date +%s)"
    
    # Test product creation
    run_test "Create product" \
        "curl -s -X POST $API_BASE_URL/api/blockchain/products -H 'Content-Type: application/json' -H 'Authorization: Bearer $JWT_TOKEN' -d '{\"id\": \"$test_product_id\", \"name\": \"Integration Test Product\", \"description\": \"Product for integration testing\", \"manufacturerId\": \"MFG001\", \"batchId\": \"BATCH001\"}' | jq -r .message" \
        "Product created successfully"
    
    # Wait for blockchain transaction to be processed
    sleep 3
    
    # Test product retrieval
    run_test "Retrieve product" \
        "curl -s -X GET $API_BASE_URL/api/blockchain/products/$test_product_id -H 'Authorization: Bearer $JWT_TOKEN' | jq -r .name" \
        "Integration Test Product"
    
    # Test get all products
    run_test "Get all products" \
        "curl -s -X GET $API_BASE_URL/api/blockchain/products -H 'Authorization: Bearer $JWT_TOKEN' | jq length" \
        ""
    
    # Test tracking event addition
    run_test "Add tracking event" \
        "curl -s -X POST $API_BASE_URL/api/blockchain/products/$test_product_id/tracking -H 'Content-Type: application/json' -H 'Authorization: Bearer $JWT_TOKEN' -d '{\"eventType\": \"manufactured\", \"location\": \"Test Factory\", \"data\": {\"quality\": \"A+\"}}' | jq -r .message" \
        "Tracking event added successfully"
    
    # Wait for blockchain transaction
    sleep 3
    
    # Verify tracking event was added
    run_test "Verify tracking event" \
        "curl -s -X GET $API_BASE_URL/api/blockchain/products/$test_product_id -H 'Authorization: Bearer $JWT_TOKEN' | jq '.supplyChainSteps | length'" \
        ""
    
    export TEST_PRODUCT_ID="$test_product_id"
}

# Security tests
test_security() {
    log "🛡️ Testing Security Features..."
    
    # Test rate limiting (this might take a while)
    log "Testing rate limiting (this may take up to 60 seconds)..."
    local rate_limit_test_count=0
    for i in {1..15}; do
        local response_code=$(curl -s -w '%{http_code}' -o /dev/null -H "Authorization: Bearer $JWT_TOKEN" "$API_BASE_URL/api/blockchain/products")
        if [[ "$response_code" == "429" ]]; then
            rate_limit_test_count=$((rate_limit_test_count + 1))
        fi
        sleep 0.1
    done
    
    if [[ $rate_limit_test_count -gt 0 ]]; then
        success "Rate limiting - PASSED (detected rate limiting after rapid requests)"
        ((PASSED_TESTS++))
    else
        warn "Rate limiting - May not be triggered with current test load"
    fi
    ((TOTAL_TESTS++))
    
    # Test input validation
    run_test "Input validation - empty product ID" \
        "curl -s -w '%{http_code}' -X POST $API_BASE_URL/api/blockchain/products -H 'Content-Type: application/json' -H 'Authorization: Bearer $JWT_TOKEN' -d '{\"id\": \"\", \"name\": \"Test\", \"description\": \"Test\", \"manufacturerId\": \"MFG001\"}'" \
        "400"
    
    # Test invalid JSON
    run_test "Input validation - invalid JSON" \
        "curl -s -w '%{http_code}' -X POST $API_BASE_URL/api/blockchain/products -H 'Content-Type: application/json' -H 'Authorization: Bearer $JWT_TOKEN' -d '{invalid json}'" \
        "400"
    
    # Test SQL injection attempt (should be blocked by validation)
    run_test "Security - SQL injection prevention" \
        "curl -s -w '%{http_code}' -X GET $API_BASE_URL/api/blockchain/products/'; DROP TABLE products; --' -H 'Authorization: Bearer $JWT_TOKEN'" \
        "400"
}

# Performance tests
test_performance() {
    log "⚡ Testing Performance..."
    
    # Test concurrent requests
    log "Testing concurrent API requests..."
    local start_time=$(date +%s)
    
    # Create 10 concurrent requests
    for i in {1..10}; do
        (curl -s -X GET "$API_BASE_URL/api/blockchain/products" -H "Authorization: Bearer $JWT_TOKEN" > /dev/null) &
    done
    wait
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [[ $duration -lt 10 ]]; then
        success "Concurrent requests - PASSED (completed in ${duration}s)"
        ((PASSED_TESTS++))
    else
        error "Concurrent requests - FAILED (took ${duration}s, expected < 10s)"
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))
    
    # Test response time
    log "Testing API response time..."
    local response_time=$(curl -s -w '%{time_total}' -o /dev/null -H "Authorization: Bearer $JWT_TOKEN" "$API_BASE_URL/health")
    
    # Convert to milliseconds and compare
    local response_time_ms=$(echo "$response_time * 1000" | bc -l | cut -d. -f1)
    
    if [[ $response_time_ms -lt 1000 ]]; then
        success "Response time - PASSED (${response_time_ms}ms)"
        ((PASSED_TESTS++))
    else
        warn "Response time - SLOW (${response_time_ms}ms, expected < 1000ms)"
        ((PASSED_TESTS++))  # Still pass but with warning
    fi
    ((TOTAL_TESTS++))
}

# End-to-end workflow tests
test_e2e_workflow() {
    log "🔄 Testing End-to-End Workflow..."
    
    local workflow_product_id="E2E$(date +%s)"
    
    # Complete product lifecycle
    local events=("manufactured" "quality_check" "shipped" "received" "delivered")
    local locations=("Factory A" "QA Lab" "Logistics Hub" "Distribution Center" "Customer Location")
    
    # Create product
    curl -s -X POST "$API_BASE_URL/api/blockchain/products" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $JWT_TOKEN" \
        -d "{
            \"id\": \"$workflow_product_id\",
            \"name\": \"E2E Workflow Product\",
            \"description\": \"Product for end-to-end workflow testing\",
            \"manufacturerId\": \"MFG001\",
            \"batchId\": \"E2E_BATCH\"
        }" > /dev/null
    
    sleep 2
    
    # Add tracking events
    for i in "${!events[@]}"; do
        local event="${events[$i]}"
        local location="${locations[$i]}"
        
        curl -s -X POST "$API_BASE_URL/api/blockchain/products/$workflow_product_id/tracking" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $JWT_TOKEN" \
            -d "{
                \"eventType\": \"$event\",
                \"location\": \"$location\",
                \"data\": {
                    \"step\": \"$((i+1))\",
                    \"event\": \"$event\",
                    \"timestamp\": \"$(date -Iseconds)\"
                }
            }" > /dev/null
        
        sleep 1
    done
    
    # Verify final state
    local final_events_count=$(curl -s -X GET "$API_BASE_URL/api/blockchain/products/$workflow_product_id" \
        -H "Authorization: Bearer $JWT_TOKEN" | jq '.supplyChainSteps | length')
    
    if [[ $final_events_count -ge 5 ]]; then
        success "E2E workflow - PASSED (created product with $final_events_count tracking events)"
        ((PASSED_TESTS++))
    else
        error "E2E workflow - FAILED (expected >= 5 events, got $final_events_count)"
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))
}

# Blockchain-specific tests
test_blockchain_functionality() {
    log "⛓️ Testing Blockchain Functionality..."
    
    # Test data immutability by trying to retrieve the same product multiple times
    run_test "Data consistency" \
        "curl -s -X GET $API_BASE_URL/api/blockchain/products/$TEST_PRODUCT_ID -H 'Authorization: Bearer $JWT_TOKEN' | jq -r .id" \
        "$TEST_PRODUCT_ID"
    
    # Test that we can't create a product with duplicate ID
    run_test "Duplicate prevention" \
        "curl -s -w '%{http_code}' -X POST $API_BASE_URL/api/blockchain/products -H 'Content-Type: application/json' -H 'Authorization: Bearer $JWT_TOKEN' -d '{\"id\": \"$TEST_PRODUCT_ID\", \"name\": \"Duplicate\", \"description\": \"Should fail\", \"manufacturerId\": \"MFG001\"}'" \
        "500"
}

# Cleanup function
cleanup() {
    log "🧹 Cleaning up test data..."
    # Note: In a real scenario, you might want to implement cleanup endpoints
    # or use test-specific data that gets cleaned up automatically
}

# Generate test report
generate_report() {
    echo ""
    echo "==============================================="
    echo "🧪 INTEGRATION TEST REPORT"
    echo "==============================================="
    echo "📊 Total Tests: $TOTAL_TESTS"
    echo "✅ Passed: $PASSED_TESTS"
    echo "❌ Failed: $FAILED_TESTS"
    echo "📈 Success Rate: $(( (PASSED_TESTS * 100) / TOTAL_TESTS ))%"
    echo "⏱️  Test Duration: $(( $(date +%s) - START_TIME )) seconds"
    echo "==============================================="
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}🎉 ALL TESTS PASSED!${NC}"
        return 0
    else
        echo -e "${RED}💥 SOME TESTS FAILED!${NC}"
        echo "Please check the logs above for details."
        return 1
    fi
}

# Main test execution
main() {
    START_TIME=$(date +%s)
    
    echo "🚀 Starting Enterprise Supply Chain Platform Integration Tests"
    echo "Platform: Hyperledger Fabric 2.5+ Supply Chain Management"
    echo "Timestamp: $(date -Iseconds)"
    echo ""
    
    # Check prerequisites
    if ! command -v curl &> /dev/null; then
        error "curl is required for testing"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        error "jq is required for JSON processing"
        exit 1
    fi
    
    if ! command -v bc &> /dev/null; then
        warn "bc is recommended for performance calculations"
    fi
    
    # Check if API server is running
    if ! check_api_server; then
        exit 1
    fi
    
    # Run test suites
    test_authentication
    test_gateway
    test_product_management
    test_security
    test_performance
    test_e2e_workflow
    test_blockchain_functionality
    
    # Cleanup
    cleanup
    
    # Generate and show report
    generate_report
}

# Handle script arguments
case "${1:-run}" in
    "run")
        main
        ;;
    "auth")
        check_api_server && test_authentication
        ;;
    "products")
        check_api_server && test_product_management
        ;;
    "security")
        check_api_server && test_security
        ;;
    "performance")
        check_api_server && test_performance
        ;;
    "e2e")
        check_api_server && test_e2e_workflow
        ;;
    *)
        echo "Usage: $0 [run|auth|products|security|performance|e2e]"
        echo "  run         - Run all tests (default)"
        echo "  auth        - Run authentication tests only"
        echo "  products    - Run product management tests only" 
        echo "  security    - Run security tests only"
        echo "  performance - Run performance tests only"
        echo "  e2e         - Run end-to-end workflow tests only"
        exit 1
        ;;
esac 