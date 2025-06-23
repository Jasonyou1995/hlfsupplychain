#!/bin/bash
#
# Enterprise Hyperledger Fabric Supply Chain Platform v2.5+
# Network Bootstrap Script
# Author: Supply Chain Platform Team
# Last Modified: December 16, 2025
# License: Apache-2.0

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Network configuration
COMPOSE_FILE=docker-compose.yaml
CHANNEL_NAME="supplychain-channel"
CC_NAME="supplychain"
CC_VERSION="1.0"
CC_SEQUENCE="1"
ORDERER_CA="organizations/ordererOrganizations/supplychain.com/orderers/orderer1.supplychain.com/msp/tlscacerts/tlsca.supplychain.com-cert.pem"
PEER_CONN_PARMS=""

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "$1 could not be found. Please install it first."
        exit 1
    fi
}

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    check_command "docker"
    check_command "docker-compose"
    check_command "peer"
    check_command "configtxgen"
    check_command "cryptogen"
    
    # Check Fabric version
    FABRIC_VERSION=$(peer version | grep Version | awk '{print $2}')
    if [[ ! $FABRIC_VERSION =~ ^2\.[5-9] ]]; then
        print_error "This script requires Hyperledger Fabric v2.5+. Current version: $FABRIC_VERSION"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to generate crypto material
generate_certificates() {
    print_info "Generating certificates using fabric-ca..."
    
    # Remove existing crypto material
    rm -rf organizations/
    
    # Start CA containers
    docker-compose -f $COMPOSE_FILE up -d ca.orderer.supplychain.com \
        ca.manufacturer.supplychain.com \
        ca.supplier.supplychain.com \
        ca.logistics.supplychain.com \
        ca.retailer.supplychain.com \
        ca.auditor.supplychain.com
    
    # Wait for CAs to start
    sleep 10
    
    # Register and enroll users for each organization
    print_info "Enrolling CA admins and generating MSP..."
    
    # Create organizations directory structure
    mkdir -p organizations/{ordererOrganizations,peerOrganizations}
    
    # Generate orderer organization
    print_info "Creating Orderer Organization certificates..."
    ./scripts/registerEnroll.sh orderer
    
    # Generate peer organizations
    for org in manufacturer supplier logistics retailer auditor; do
        print_info "Creating $org Organization certificates..."
        ./scripts/registerEnroll.sh $org
    done
    
    print_success "Certificate generation completed"
}

# Function to generate genesis block
generate_genesis() {
    print_info "Generating genesis block..."
    
    mkdir -p system-genesis-block
    
    configtxgen -profile SupplyChainGenesis \
        -configPath . \
        -channelID system-channel \
        -outputBlock ./system-genesis-block/genesis.block
    
    if [ ! -f "./system-genesis-block/genesis.block" ]; then
        print_error "Failed to generate genesis block"
        exit 1
    fi
    
    print_success "Genesis block generated"
}

# Function to start network
start_network() {
    print_info "Starting Fabric network..."
    
    # Start orderers
    docker-compose -f $COMPOSE_FILE up -d orderer1.supplychain.com \
        orderer2.supplychain.com \
        orderer3.supplychain.com
    
    # Wait for orderers to start
    sleep 15
    
    # Start peers
    docker-compose -f $COMPOSE_FILE up -d peer0.manufacturer.supplychain.com \
        gateway.manufacturer.supplychain.com \
        couchdb.manufacturer \
        cli
    
    # Wait for peers to start
    sleep 10
    
    print_success "Network started successfully"
}

# Function to create channel
create_channel() {
    print_info "Creating application channel: $CHANNEL_NAME"
    
    # Generate channel configuration transaction
    mkdir -p channel-artifacts
    
    configtxgen -profile SupplyChainChannel \
        -configPath . \
        -outputCreateChannelTx ./channel-artifacts/${CHANNEL_NAME}.tx \
        -channelID $CHANNEL_NAME
    
    # Create the channel using osnadmin CLI (v2.3+ method)
    export ORDERER_ADMIN_TLS_SIGN_CERT=$(pwd)/organizations/ordererOrganizations/supplychain.com/orderers/orderer1.supplychain.com/tls/server.crt
    export ORDERER_ADMIN_TLS_PRIVATE_KEY=$(pwd)/organizations/ordererOrganizations/supplychain.com/orderers/orderer1.supplychain.com/tls/server.key
    
    osnadmin channel join \
        --channelID $CHANNEL_NAME \
        --config-block ./channel-artifacts/${CHANNEL_NAME}.block \
        -o localhost:7053 \
        --ca-file "$ORDERER_CA" \
        --client-cert "$ORDERER_ADMIN_TLS_SIGN_CERT" \
        --client-key "$ORDERER_ADMIN_TLS_PRIVATE_KEY"
    
    print_success "Channel $CHANNEL_NAME created"
}

# Function to join peers to channel
join_channel() {
    print_info "Joining peers to channel: $CHANNEL_NAME"
    
    # Set environment for manufacturer peer
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID="ManufacturerMSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$(pwd)/organizations/peerOrganizations/manufacturer.supplychain.com/peers/peer0.manufacturer.supplychain.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=$(pwd)/organizations/peerOrganizations/manufacturer.supplychain.com/users/Admin@manufacturer.supplychain.com/msp
    export CORE_PEER_ADDRESS=localhost:7051
    
    # Fetch channel block
    peer channel fetch 0 ./channel-artifacts/${CHANNEL_NAME}.block \
        -o localhost:7050 \
        --ordererTLSHostnameOverride orderer1.supplychain.com \
        -c $CHANNEL_NAME \
        --tls \
        --cafile "$ORDERER_CA"
    
    # Join manufacturer peer to channel
    peer channel join -b ./channel-artifacts/${CHANNEL_NAME}.block
    
    print_success "Peer joined to channel $CHANNEL_NAME"
}

# Function to update anchor peers
update_anchor_peers() {
    print_info "Updating anchor peers..."
    
    # Generate anchor peer update for manufacturer
    configtxgen -profile SupplyChainChannel \
        -configPath . \
        -outputAnchorPeersUpdate ./channel-artifacts/ManufacturerMSPanchors.tx \
        -channelID $CHANNEL_NAME \
        -asOrg ManufacturerMSP
    
    # Update anchor peer
    peer channel update \
        -o localhost:7050 \
        --ordererTLSHostnameOverride orderer1.supplychain.com \
        -c $CHANNEL_NAME \
        -f ./channel-artifacts/ManufacturerMSPanchors.tx \
        --tls \
        --cafile "$ORDERER_CA"
    
    print_success "Anchor peers updated"
}

# Function to package chaincode
package_chaincode() {
    print_info "Packaging chaincode: $CC_NAME"
    
    # Package chaincode using new lifecycle
    peer lifecycle chaincode package ${CC_NAME}.tar.gz \
        --path ../chaincode/supplychain \
        --lang golang \
        --label ${CC_NAME}_${CC_VERSION}
    
    print_success "Chaincode packaged: ${CC_NAME}.tar.gz"
}

# Function to install chaincode
install_chaincode() {
    print_info "Installing chaincode on peers..."
    
    # Install on manufacturer peer
    peer lifecycle chaincode install ${CC_NAME}.tar.gz
    
    # Query to get package ID
    CC_PACKAGE_ID=$(peer lifecycle chaincode queryinstalled --output json | jq -r '.installed_chaincodes[] | select(.label=="'${CC_NAME}_${CC_VERSION}'") | .package_id')
    
    if [ -z "$CC_PACKAGE_ID" ]; then
        print_error "Failed to get chaincode package ID"
        exit 1
    fi
    
    print_success "Chaincode installed. Package ID: $CC_PACKAGE_ID"
    
    # Export for use in other functions
    export CC_PACKAGE_ID
}

# Function to approve chaincode definition
approve_chaincode() {
    print_info "Approving chaincode definition..."
    
    # Approve chaincode definition for manufacturer
    peer lifecycle chaincode approveformyorg \
        -o localhost:7050 \
        --ordererTLSHostnameOverride orderer1.supplychain.com \
        --channelID $CHANNEL_NAME \
        --name $CC_NAME \
        --version $CC_VERSION \
        --package-id $CC_PACKAGE_ID \
        --sequence $CC_SEQUENCE \
        --tls \
        --cafile "$ORDERER_CA"
    
    print_success "Chaincode definition approved"
}

# Function to check commit readiness
check_commit_readiness() {
    print_info "Checking commit readiness..."
    
    peer lifecycle chaincode checkcommitreadiness \
        --channelID $CHANNEL_NAME \
        --name $CC_NAME \
        --version $CC_VERSION \
        --sequence $CC_SEQUENCE \
        --tls \
        --cafile "$ORDERER_CA" \
        --output json
}

# Function to commit chaincode
commit_chaincode() {
    print_info "Committing chaincode definition..."
    
    peer lifecycle chaincode commit \
        -o localhost:7050 \
        --ordererTLSHostnameOverride orderer1.supplychain.com \
        --channelID $CHANNEL_NAME \
        --name $CC_NAME \
        --version $CC_VERSION \
        --sequence $CC_SEQUENCE \
        --tls \
        --cafile "$ORDERER_CA" \
        --peerAddresses localhost:7051 \
        --tlsRootCertFiles $(pwd)/organizations/peerOrganizations/manufacturer.supplychain.com/peers/peer0.manufacturer.supplychain.com/tls/ca.crt
    
    print_success "Chaincode committed successfully"
}

# Function to test chaincode
test_chaincode() {
    print_info "Testing chaincode deployment..."
    
    # Initialize ledger
    peer chaincode invoke \
        -o localhost:7050 \
        --ordererTLSHostnameOverride orderer1.supplychain.com \
        --tls \
        --cafile "$ORDERER_CA" \
        -C $CHANNEL_NAME \
        -n $CC_NAME \
        --peerAddresses localhost:7051 \
        --tlsRootCertFiles $(pwd)/organizations/peerOrganizations/manufacturer.supplychain.com/peers/peer0.manufacturer.supplychain.com/tls/ca.crt \
        -c '{"function":"InitLedger","Args":[]}'
    
    sleep 5
    
    # Query all products
    peer chaincode query \
        -C $CHANNEL_NAME \
        -n $CC_NAME \
        -c '{"function":"GetAllProducts","Args":[]}'
    
    print_success "Chaincode test completed"
}

# Function to deploy monitoring
deploy_monitoring() {
    print_info "Deploying monitoring stack..."
    
    # Create monitoring configurations
    mkdir -p monitoring/grafana/{dashboards,provisioning/dashboards,provisioning/datasources}
    
    # Start monitoring services
    docker-compose -f $COMPOSE_FILE up -d prometheus grafana
    
    print_success "Monitoring stack deployed. Access Grafana at http://localhost:3000 (admin/admin)"
}

# Function to stop network
stop_network() {
    print_info "Stopping Fabric network..."
    docker-compose -f $COMPOSE_FILE down --volumes --remove-orphans
    docker volume prune -f
    print_success "Network stopped and cleaned up"
}

# Function to clean up
cleanup() {
    print_info "Cleaning up..."
    stop_network
    rm -rf organizations/ system-genesis-block/ channel-artifacts/ *.tar.gz
    print_success "Cleanup completed"
}

# Function to display network status
network_status() {
    print_info "Network Status:"
    docker-compose -f $COMPOSE_FILE ps
    
    echo ""
    print_info "Service URLs:"
    echo "  - Orderer Admin: https://localhost:7053"
    echo "  - Peer Gateway: https://localhost:7051"
    echo "  - Fabric Gateway: https://localhost:7052"
    echo "  - Prometheus: http://localhost:9090"
    echo "  - Grafana: http://localhost:3000"
    echo "  - CouchDB: http://localhost:5984"
}

# Main execution logic
case "${1:-''}" in
    up|start)
        print_info "Starting Enterprise Supply Chain Network v2.5+"
        check_prerequisites
        generate_certificates
        generate_genesis
        start_network
        create_channel
        join_channel
        update_anchor_peers
        package_chaincode
        install_chaincode
        approve_chaincode
        commit_chaincode
        test_chaincode
        deploy_monitoring
        network_status
        print_success "Network deployment completed successfully!"
        ;;
    down|stop)
        stop_network
        ;;
    clean|cleanup)
        cleanup
        ;;
    restart)
        cleanup
        $0 up
        ;;
    status)
        network_status
        ;;
    test)
        test_chaincode
        ;;
    *)
        echo "Enterprise Hyperledger Fabric Supply Chain Platform v2.5+"
        echo ""
        echo "Usage: $0 {up|down|restart|clean|status|test}"
        echo ""
        echo "Commands:"
        echo "  up       - Start the complete network"
        echo "  down     - Stop the network"
        echo "  restart  - Clean and restart the network"
        echo "  clean    - Remove all containers, volumes, and generated files"
        echo "  status   - Show network status and service URLs"
        echo "  test     - Test chaincode functionality"
        echo ""
        echo "Examples:"
        echo "  $0 up              # Start the network"
        echo "  $0 status          # Check network status"
        echo "  $0 down            # Stop the network"
        echo ""
        exit 1
        ;;
esac 