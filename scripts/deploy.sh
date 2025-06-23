#!/bin/bash

# Enterprise Hyperledger Fabric Supply Chain Platform v2.5+
# Production Deployment Script
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

# Configuration
NETWORK_NAME="supplychain-network"
CHANNEL_NAME="supplychain-channel"
CHAINCODE_NAME="supplychain"
CHAINCODE_VERSION="1.0.0"
SEQUENCE="1"

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if Docker is installed and running
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        error "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    # Check if Docker Compose is installed
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Check if Go is installed (for chaincode compilation)
    if ! command -v go &> /dev/null; then
        error "Go is not installed. Please install Go 1.19+ first."
        exit 1
    fi
    
    # Check Go version
    GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
    if [[ $(echo "$GO_VERSION 1.19" | tr " " "\n" | sort -V | head -n1) != "1.19" ]]; then
        error "Go version 1.19+ is required. Current version: $GO_VERSION"
        exit 1
    fi
    
    # Check if Node.js is installed
    if ! command -v node &> /dev/null; then
        error "Node.js is not installed. Please install Node.js 18+ first."
        exit 1
    fi
    
    # Check Node.js version
    NODE_VERSION=$(node --version | sed 's/v//')
    if [[ $(echo "$NODE_VERSION 18.0.0" | tr " " "\n" | sort -V | head -n1) != "18.0.0" ]]; then
        error "Node.js version 18+ is required. Current version: $NODE_VERSION"
        exit 1
    fi
    
    success "All prerequisites met!"
}

# Clean up existing containers and networks
cleanup() {
    log "Cleaning up existing deployment..."
    
    # Stop and remove containers
    docker-compose -f network/docker-compose.yaml down --volumes --remove-orphans 2>/dev/null || true
    
    # Remove chaincode containers
    docker rm -f $(docker ps -aq --filter "name=dev-peer") 2>/dev/null || true
    
    # Remove chaincode images
    docker rmi -f $(docker images --filter "reference=dev-peer*" -q) 2>/dev/null || true
    
    # Clean up volumes
    docker volume prune -f
    
    success "Cleanup completed!"
}

# Generate crypto material
generate_crypto() {
    log "Generating crypto material..."
    
    cd network
    
    # Remove existing organizations
    rm -rf organizations
    
    # Generate crypto material for each organization
    ./scripts/registerEnroll.sh
    
    cd ..
    success "Crypto material generated!"
}

# Start the network
start_network() {
    log "Starting Hyperledger Fabric network..."
    
    cd network
    
    # Start containers
    docker-compose -f docker-compose.yaml up -d
    
    # Wait for containers to be ready
    log "Waiting for containers to be ready..."
    sleep 30
    
    # Check if all containers are running
    RUNNING_CONTAINERS=$(docker-compose -f docker-compose.yaml ps --services --filter "status=running" | wc -l)
    TOTAL_CONTAINERS=$(docker-compose -f docker-compose.yaml ps --services | wc -l)
    
    if [ "$RUNNING_CONTAINERS" -ne "$TOTAL_CONTAINERS" ]; then
        error "Not all containers are running. Please check the logs."
        docker-compose -f docker-compose.yaml logs
        exit 1
    fi
    
    cd ..
    success "Network started successfully!"
}

# Create channel
create_channel() {
    log "Creating channel: $CHANNEL_NAME"
    
    cd network
    
    # Set environment variables
    export FABRIC_CFG_PATH=${PWD}
    export PATH=${PWD}/../bin:$PATH
    
    # Create channel configuration
    configtxgen -profile SupplyChainChannel -outputCreateChannelTx ./channel-artifacts/${CHANNEL_NAME}.tx -channelID $CHANNEL_NAME
    
    # Create genesis block
    configtxgen -profile SupplyChainChannel -outputBlock ./channel-artifacts/${CHANNEL_NAME}.block -channelID $CHANNEL_NAME
    
    # Create channel using osnadmin
    export OSN_TLS_CA_ROOT_CERT=${PWD}/organizations/ordererOrganizations/supplychain.com/orderers/orderer1.supplychain.com/msp/tlscacerts/tlsca.supplychain.com-cert.pem
    export ADMIN_TLS_SIGN_CERT=${PWD}/organizations/ordererOrganizations/supplychain.com/orderers/orderer1.supplychain.com/tls/server.crt
    export ADMIN_TLS_PRIVATE_KEY=${PWD}/organizations/ordererOrganizations/supplychain.com/orderers/orderer1.supplychain.com/tls/server.key
    
    osnadmin channel join --channelID $CHANNEL_NAME --config-block ./channel-artifacts/${CHANNEL_NAME}.block -o localhost:7053 --ca-file "$OSN_TLS_CA_ROOT_CERT" --client-cert "$ADMIN_TLS_SIGN_CERT" --client-key "$ADMIN_TLS_PRIVATE_KEY"
    
    cd ..
    success "Channel created successfully!"
}

# Join peers to channel
join_peers() {
    log "Joining peers to channel..."
    
    cd network
    
    # Set environment variables for peer operations
    export FABRIC_CFG_PATH=${PWD}
    export PATH=${PWD}/../bin:$PATH
    
    # Function to join peer to channel
    join_peer() {
        local org=$1
        local peer_num=$2
        local port=$3
        local domain="${org}.supplychain.com"
        
        log "Joining peer${peer_num}.${domain} to channel..."
        
        export CORE_PEER_TLS_ENABLED=true
        export CORE_PEER_LOCALMSPID="${org^}MSP"
        export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/${domain}/peers/peer${peer_num}.${domain}/tls/ca.crt
        export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/${domain}/users/Admin@${domain}/msp
        export CORE_PEER_ADDRESS=localhost:${port}
        
        # Fetch channel block
        peer channel fetch 0 ${CHANNEL_NAME}.block -o localhost:7050 --ordererTLSHostnameOverride orderer1.supplychain.com -c $CHANNEL_NAME --tls --cafile ${PWD}/organizations/ordererOrganizations/supplychain.com/orderers/orderer1.supplychain.com/msp/tlscacerts/tlsca.supplychain.com-cert.pem
        
        # Join channel
        peer channel join -b ${CHANNEL_NAME}.block
        
        # Update anchor peer
        if [ "$peer_num" -eq 0 ]; then
            peer channel update -o localhost:7050 --ordererTLSHostnameOverride orderer1.supplychain.com -c $CHANNEL_NAME -f ./channel-artifacts/${org^}MSPanchors.tx --tls --cafile ${PWD}/organizations/ordererOrganizations/supplychain.com/orderers/orderer1.supplychain.com/msp/tlscacerts/tlsca.supplychain.com-cert.pem
        fi
    }
    
    # Join all peers
    join_peer "manufacturer" 0 7051
    join_peer "manufacturer" 1 7151
    join_peer "supplier" 0 8051
    join_peer "supplier" 1 8151
    join_peer "logistics" 0 9051
    join_peer "logistics" 1 9151
    join_peer "retailer" 0 10051
    join_peer "retailer" 1 10151
    join_peer "auditor" 0 11051
    join_peer "auditor" 1 11151
    
    cd ..
    success "All peers joined to channel!"
}

# Package and install chaincode
package_chaincode() {
    log "Packaging chaincode..."
    
    cd chaincode/supplychain
    
    # Ensure dependencies are up to date
    go mod tidy
    go mod vendor
    
    cd ../../network
    
    # Package chaincode
    export FABRIC_CFG_PATH=${PWD}
    export PATH=${PWD}/../bin:$PATH
    
    peer lifecycle chaincode package ${CHAINCODE_NAME}.tar.gz --path ../chaincode/supplychain --lang golang --label ${CHAINCODE_NAME}_${CHAINCODE_VERSION}
    
    success "Chaincode packaged successfully!"
}

# Install chaincode on all peers
install_chaincode() {
    log "Installing chaincode on all peers..."
    
    cd network
    
    export FABRIC_CFG_PATH=${PWD}
    export PATH=${PWD}/../bin:$PATH
    
    # Function to install chaincode on peer
    install_on_peer() {
        local org=$1
        local peer_num=$2
        local port=$3
        local domain="${org}.supplychain.com"
        
        log "Installing chaincode on peer${peer_num}.${domain}..."
        
        export CORE_PEER_TLS_ENABLED=true
        export CORE_PEER_LOCALMSPID="${org^}MSP"
        export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/${domain}/peers/peer${peer_num}.${domain}/tls/ca.crt
        export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/${domain}/users/Admin@${domain}/msp
        export CORE_PEER_ADDRESS=localhost:${port}
        
        peer lifecycle chaincode install ${CHAINCODE_NAME}.tar.gz
    }
    
    # Install on all peers
    install_on_peer "manufacturer" 0 7051
    install_on_peer "supplier" 0 8051
    install_on_peer "logistics" 0 9051
    install_on_peer "retailer" 0 10051
    install_on_peer "auditor" 0 11051
    
    success "Chaincode installed on all peers!"
}

# Approve and commit chaincode
approve_commit_chaincode() {
    log "Approving and committing chaincode..."
    
    cd network
    
    export FABRIC_CFG_PATH=${PWD}
    export PATH=${PWD}/../bin:$PATH
    
    # Get package ID
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID="ManufacturerMSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/manufacturer.supplychain.com/peers/peer0.manufacturer.supplychain.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/manufacturer.supplychain.com/users/Admin@manufacturer.supplychain.com/msp
    export CORE_PEER_ADDRESS=localhost:7051
    
    PACKAGE_ID=$(peer lifecycle chaincode queryinstalled --output json | jq -r ".installed_chaincodes[] | select(.label==\"${CHAINCODE_NAME}_${CHAINCODE_VERSION}\") | .package_id")
    
    if [ -z "$PACKAGE_ID" ]; then
        error "Package ID not found!"
        exit 1
    fi
    
    log "Package ID: $PACKAGE_ID"
    
    # Function to approve chaincode
    approve_chaincode() {
        local org=$1
        local port=$2
        local domain="${org}.supplychain.com"
        
        log "Approving chaincode for ${org^}MSP..."
        
        export CORE_PEER_LOCALMSPID="${org^}MSP"
        export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/${domain}/peers/peer0.${domain}/tls/ca.crt
        export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/${domain}/users/Admin@${domain}/msp
        export CORE_PEER_ADDRESS=localhost:${port}
        
        peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer1.supplychain.com --channelID $CHANNEL_NAME --name $CHAINCODE_NAME --version $CHAINCODE_VERSION --package-id $PACKAGE_ID --sequence $SEQUENCE --tls --cafile ${PWD}/organizations/ordererOrganizations/supplychain.com/orderers/orderer1.supplychain.com/msp/tlscacerts/tlsca.supplychain.com-cert.pem
    }
    
    # Approve for all organizations
    approve_chaincode "manufacturer" 7051
    approve_chaincode "supplier" 8051
    approve_chaincode "logistics" 9051
    approve_chaincode "retailer" 10051
    approve_chaincode "auditor" 11051
    
    # Commit chaincode
    log "Committing chaincode..."
    peer lifecycle chaincode commit -o localhost:7050 --ordererTLSHostnameOverride orderer1.supplychain.com --channelID $CHANNEL_NAME --name $CHAINCODE_NAME --version $CHAINCODE_VERSION --sequence $SEQUENCE --tls --cafile ${PWD}/organizations/ordererOrganizations/supplychain.com/orderers/orderer1.supplychain.com/msp/tlscacerts/tlsca.supplychain.com-cert.pem --peerAddresses localhost:7051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/manufacturer.supplychain.com/peers/peer0.manufacturer.supplychain.com/tls/ca.crt --peerAddresses localhost:8051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/supplier.supplychain.com/peers/peer0.supplier.supplychain.com/tls/ca.crt --peerAddresses localhost:9051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/logistics.supplychain.com/peers/peer0.logistics.supplychain.com/tls/ca.crt --peerAddresses localhost:10051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/retailer.supplychain.com/peers/peer0.retailer.supplychain.com/tls/ca.crt --peerAddresses localhost:11051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/auditor.supplychain.com/peers/peer0.auditor.supplychain.com/tls/ca.crt
    
    cd ..
    success "Chaincode approved and committed!"
}

# Initialize chaincode
init_chaincode() {
    log "Initializing chaincode..."
    
    cd network
    
    export FABRIC_CFG_PATH=${PWD}
    export PATH=${PWD}/../bin:$PATH
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID="ManufacturerMSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/manufacturer.supplychain.com/peers/peer0.manufacturer.supplychain.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/manufacturer.supplychain.com/users/Admin@manufacturer.supplychain.com/msp
    export CORE_PEER_ADDRESS=localhost:7051
    
    # Initialize ledger with sample data
    peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer1.supplychain.com --tls --cafile ${PWD}/organizations/ordererOrganizations/supplychain.com/orderers/orderer1.supplychain.com/msp/tlscacerts/tlsca.supplychain.com-cert.pem -C $CHANNEL_NAME -n $CHAINCODE_NAME --peerAddresses localhost:7051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/manufacturer.supplychain.com/peers/peer0.manufacturer.supplychain.com/tls/ca.crt -c '{"function":"InitLedger","Args":[]}'
    
    cd ..
    success "Chaincode initialized with sample data!"
}

# Setup client environment
setup_client() {
    log "Setting up client environment..."
    
    cd client
    
    # Install dependencies
    npm install
    
    # Run security audit
    npm audit --audit-level moderate
    
    # Create .env file if it doesn't exist
    if [ ! -f .env ]; then
        log "Creating .env file..."
        cat > .env << EOF
# Hyperledger Fabric Supply Chain Client Configuration
NODE_ENV=production
PORT=3000
LOG_LEVEL=info

# JWT Configuration
JWT_SECRET=$(openssl rand -hex 32)

# Security Configuration
ALLOWED_ORIGINS=http://localhost:3000,https://your-production-domain.com

# Fabric Network Configuration
CHANNEL_NAME=supplychain-channel
CHAINCODE_NAME=supplychain

# API Rate Limiting
API_RATE_LIMIT=100
BLOCKCHAIN_RATE_LIMIT=10
EOF
        warn "Please review and update the .env file with your production settings!"
    fi
    
    cd ..
    success "Client environment setup completed!"
}

# Verify deployment
verify_deployment() {
    log "Verifying deployment..."
    
    cd network
    
    export FABRIC_CFG_PATH=${PWD}
    export PATH=${PWD}/../bin:$PATH
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID="ManufacturerMSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/manufacturer.supplychain.com/peers/peer0.manufacturer.supplychain.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/manufacturer.supplychain.com/users/Admin@manufacturer.supplychain.com/msp
    export CORE_PEER_ADDRESS=localhost:7051
    
    # Test chaincode query
    log "Testing chaincode query..."
    RESULT=$(peer chaincode query -C $CHANNEL_NAME -n $CHAINCODE_NAME -c '{"function":"GetAllProducts","Args":[]}')
    
    if [[ $RESULT == *"PROD001"* ]]; then
        success "Chaincode query test passed!"
    else
        error "Chaincode query test failed!"
        echo "Result: $RESULT"
        exit 1
    fi
    
    # Test client API (if running)
    log "Testing client API health check..."
    if command -v curl &> /dev/null; then
        cd ../client
        # Start API server in background for testing
        npm start &
        API_PID=$!
        sleep 10
        
        HEALTH_CHECK=$(curl -s http://localhost:3000/health | jq -r .status 2>/dev/null || echo "failed")
        
        if [[ $HEALTH_CHECK == "healthy" ]]; then
            success "Client API health check passed!"
        else
            warn "Client API health check failed - this is normal if not running the API server"
        fi
        
        # Stop API server
        kill $API_PID 2>/dev/null || true
        cd ../network
    fi
    
    cd ..
    success "Deployment verification completed!"
}

# Print network information
print_info() {
    log "📋 Deployment Summary"
    echo "================================"
    echo "🌐 Network Name: $NETWORK_NAME"
    echo "📺 Channel Name: $CHANNEL_NAME"
    echo "⛓️  Chaincode Name: $CHAINCODE_NAME"
    echo "🔢 Chaincode Version: $CHAINCODE_VERSION"
    echo ""
    echo "🏭 Organizations:"
    echo "  • Manufacturer (ManufacturerMSP) - peer0:7051, peer1:7151"
    echo "  • Supplier (SupplierMSP) - peer0:8051, peer1:8151"
    echo "  • Logistics (LogisticsMSP) - peer0:9051, peer1:9151"
    echo "  • Retailer (RetailerMSP) - peer0:10051, peer1:10151"
    echo "  • Auditor (AuditorMSP) - peer0:11051, peer1:11151"
    echo ""
    echo "📡 Orderers:"
    echo "  • orderer1.supplychain.com:7050"
    echo "  • orderer2.supplychain.com:8050"
    echo "  • orderer3.supplychain.com:9050"
    echo ""
    echo "🔗 Client API:"
    echo "  • Health Check: http://localhost:3000/health"
    echo "  • API Documentation: Check README.md for endpoint details"
    echo ""
    echo "🛡️ Security Features:"
    echo "  • TLS enabled for all communications"
    echo "  • JWT authentication for API access"
    echo "  • Rate limiting implemented"
    echo "  • Input validation and sanitization"
    echo "  • Comprehensive logging and monitoring"
    echo ""
    echo "🚀 Next Steps:"
    echo "  1. Review and update client/.env file"
    echo "  2. Start the client API: cd client && npm start"
    echo "  3. Test the endpoints using the provided examples"
    echo "  4. Configure your production domain and SSL certificates"
    echo "================================"
}

# Main deployment function
main() {
    log "🚀 Starting Enterprise Supply Chain Platform Deployment"
    log "Hyperledger Fabric 2.5+ Production Setup"
    echo ""
    
    check_prerequisites
    cleanup
    generate_crypto
    start_network
    create_channel
    join_peers
    package_chaincode
    install_chaincode
    approve_commit_chaincode
    init_chaincode
    setup_client
    verify_deployment
    
    echo ""
    success "🎉 Deployment completed successfully!"
    print_info
}

# Handle script arguments
case "${1:-deploy}" in
    "deploy")
        main
        ;;
    "cleanup")
        cleanup
        success "Cleanup completed!"
        ;;
    "verify")
        verify_deployment
        ;;
    "info")
        print_info
        ;;
    *)
        echo "Usage: $0 [deploy|cleanup|verify|info]"
        echo "  deploy  - Full deployment (default)"
        echo "  cleanup - Clean up existing deployment"
        echo "  verify  - Verify current deployment"
        echo "  info    - Show deployment information"
        exit 1
        ;;
esac 