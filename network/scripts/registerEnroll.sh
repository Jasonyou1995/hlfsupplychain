#!/bin/bash
#
# Enterprise Hyperledger Fabric Supply Chain Platform v2.5+
# Certificate Registration and Enrollment Script
# Author: Supply Chain Platform Team
# Last Modified: December 16, 2024
# License: Apache-2.0

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Organization parameter
ORG_NAME=$1

if [ -z "$ORG_NAME" ]; then
    print_error "Usage: $0 <organization_name>"
    print_info "Available organizations: orderer, manufacturer, supplier, logistics, retailer, auditor"
    exit 1
fi

# Set organization-specific variables
case $ORG_NAME in
    "orderer")
        CA_NAME="ca.orderer.supplychain.com"
        CA_PORT="7054"
        ORG_DOMAIN="orderer.supplychain.com"
        MSP_ID="OrdererMSP"
        ORG_TYPE="orderer"
        ;;
    "manufacturer")
        CA_NAME="ca.manufacturer.supplychain.com"
        CA_PORT="8054"
        ORG_DOMAIN="manufacturer.supplychain.com"
        MSP_ID="ManufacturerMSP"
        ORG_TYPE="peer"
        ;;
    "supplier")
        CA_NAME="ca.supplier.supplychain.com"
        CA_PORT="9054"
        ORG_DOMAIN="supplier.supplychain.com"
        MSP_ID="SupplierMSP"
        ORG_TYPE="peer"
        ;;
    "logistics")
        CA_NAME="ca.logistics.supplychain.com"
        CA_PORT="10054"
        ORG_DOMAIN="logistics.supplychain.com"
        MSP_ID="LogisticsMSP"
        ORG_TYPE="peer"
        ;;
    "retailer")
        CA_NAME="ca.retailer.supplychain.com"
        CA_PORT="11054"
        ORG_DOMAIN="retailer.supplychain.com"
        MSP_ID="RetailerMSP"
        ORG_TYPE="peer"
        ;;
    "auditor")
        CA_NAME="ca.auditor.supplychain.com"
        CA_PORT="12054"
        ORG_DOMAIN="auditor.supplychain.com"
        MSP_ID="AuditorMSP"
        ORG_TYPE="peer"
        ;;
    *)
        print_error "Unknown organization: $ORG_NAME"
        exit 1
        ;;
esac

# Set fabric-ca-client home
export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/${ORG_TYPE}Organizations/${ORG_DOMAIN}

print_info "Registering and enrolling identities for $ORG_NAME organization"
print_info "CA: $CA_NAME:$CA_PORT"
print_info "Domain: $ORG_DOMAIN"
print_info "MSP ID: $MSP_ID"

# Create organization directory structure
mkdir -p ${FABRIC_CA_CLIENT_HOME}

# Wait for CA to be ready
print_info "Waiting for CA $CA_NAME to be ready..."
sleep 5

# Enroll CA admin
print_info "Enrolling CA admin for $ORG_NAME..."
fabric-ca-client enroll -u https://admin:adminpw@localhost:${CA_PORT} --caname ${CA_NAME} --tls.certfiles ${PWD}/organizations/fabric-ca/${ORG_NAME}/tls-cert.pem

# Create config.yaml for the organization
echo "NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/localhost-${CA_PORT}-${CA_NAME}.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/localhost-${CA_PORT}-${CA_NAME}.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/localhost-${CA_PORT}-${CA_NAME}.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/localhost-${CA_PORT}-${CA_NAME}.pem
    OrganizationalUnitIdentifier: orderer" > ${FABRIC_CA_CLIENT_HOME}/msp/config.yaml

if [ "$ORG_TYPE" = "orderer" ]; then
    # Register and enroll orderer nodes
    for i in 1 2 3; do
        print_info "Registering orderer${i}.${ORG_DOMAIN}..."
        fabric-ca-client register --caname ${CA_NAME} --id.name orderer${i} --id.secret ordererpw --id.type orderer --tls.certfiles ${PWD}/organizations/fabric-ca/${ORG_NAME}/tls-cert.pem
        
        print_info "Enrolling orderer${i}.${ORG_DOMAIN}..."
        fabric-ca-client enroll -u https://orderer${i}:ordererpw@localhost:${CA_PORT} --caname ${CA_NAME} -M ${PWD}/organizations/ordererOrganizations/${ORG_DOMAIN}/orderers/orderer${i}.${ORG_DOMAIN}/msp --csr.hosts orderer${i}.${ORG_DOMAIN} --csr.hosts localhost --tls.certfiles ${PWD}/organizations/fabric-ca/${ORG_NAME}/tls-cert.pem
        
        # Copy config.yaml to orderer MSP
        cp ${FABRIC_CA_CLIENT_HOME}/msp/config.yaml ${PWD}/organizations/ordererOrganizations/${ORG_DOMAIN}/orderers/orderer${i}.${ORG_DOMAIN}/msp/config.yaml
        
        # Enroll TLS certificate for orderer
        print_info "Enrolling TLS certificate for orderer${i}.${ORG_DOMAIN}..."
        fabric-ca-client enroll -u https://orderer${i}:ordererpw@localhost:${CA_PORT} --caname ${CA_NAME} -M ${PWD}/organizations/ordererOrganizations/${ORG_DOMAIN}/orderers/orderer${i}.${ORG_DOMAIN}/tls --enrollment.profile tls --csr.hosts orderer${i}.${ORG_DOMAIN} --csr.hosts localhost --tls.certfiles ${PWD}/organizations/fabric-ca/${ORG_NAME}/tls-cert.pem
        
        # Copy TLS certificates to proper locations
        cp ${PWD}/organizations/ordererOrganizations/${ORG_DOMAIN}/orderers/orderer${i}.${ORG_DOMAIN}/tls/tlscacerts/* ${PWD}/organizations/ordererOrganizations/${ORG_DOMAIN}/orderers/orderer${i}.${ORG_DOMAIN}/tls/ca.crt
        cp ${PWD}/organizations/ordererOrganizations/${ORG_DOMAIN}/orderers/orderer${i}.${ORG_DOMAIN}/tls/signcerts/* ${PWD}/organizations/ordererOrganizations/${ORG_DOMAIN}/orderers/orderer${i}.${ORG_DOMAIN}/tls/server.crt
        cp ${PWD}/organizations/ordererOrganizations/${ORG_DOMAIN}/orderers/orderer${i}.${ORG_DOMAIN}/tls/keystore/* ${PWD}/organizations/ordererOrganizations/${ORG_DOMAIN}/orderers/orderer${i}.${ORG_DOMAIN}/tls/server.key
        
        # Create TLS CA cert directory
        mkdir -p ${PWD}/organizations/ordererOrganizations/${ORG_DOMAIN}/orderers/orderer${i}.${ORG_DOMAIN}/msp/tlscacerts
        cp ${PWD}/organizations/ordererOrganizations/${ORG_DOMAIN}/orderers/orderer${i}.${ORG_DOMAIN}/tls/tlscacerts/* ${PWD}/organizations/ordererOrganizations/${ORG_DOMAIN}/orderers/orderer${i}.${ORG_DOMAIN}/msp/tlscacerts/tlsca.${ORG_DOMAIN}-cert.pem
    done
    
    # Register and enroll orderer admin
    print_info "Registering orderer admin..."
    fabric-ca-client register --caname ${CA_NAME} --id.name ordererAdmin --id.secret ordererAdminpw --id.type admin --tls.certfiles ${PWD}/organizations/fabric-ca/${ORG_NAME}/tls-cert.pem
    
    print_info "Enrolling orderer admin..."
    fabric-ca-client enroll -u https://ordererAdmin:ordererAdminpw@localhost:${CA_PORT} --caname ${CA_NAME} -M ${PWD}/organizations/ordererOrganizations/${ORG_DOMAIN}/users/Admin@${ORG_DOMAIN}/msp --tls.certfiles ${PWD}/organizations/fabric-ca/${ORG_NAME}/tls-cert.pem
    
    # Copy config.yaml to admin MSP
    cp ${FABRIC_CA_CLIENT_HOME}/msp/config.yaml ${PWD}/organizations/ordererOrganizations/${ORG_DOMAIN}/users/Admin@${ORG_DOMAIN}/msp/config.yaml

else
    # Register and enroll peer nodes
    for i in 0 1; do
        print_info "Registering peer${i}.${ORG_DOMAIN}..."
        fabric-ca-client register --caname ${CA_NAME} --id.name peer${i} --id.secret peer${i}pw --id.type peer --tls.certfiles ${PWD}/organizations/fabric-ca/${ORG_NAME}/tls-cert.pem
        
        print_info "Enrolling peer${i}.${ORG_DOMAIN}..."
        fabric-ca-client enroll -u https://peer${i}:peer${i}pw@localhost:${CA_PORT} --caname ${CA_NAME} -M ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/peers/peer${i}.${ORG_DOMAIN}/msp --csr.hosts peer${i}.${ORG_DOMAIN} --csr.hosts localhost --tls.certfiles ${PWD}/organizations/fabric-ca/${ORG_NAME}/tls-cert.pem
        
        # Copy config.yaml to peer MSP
        cp ${FABRIC_CA_CLIENT_HOME}/msp/config.yaml ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/peers/peer${i}.${ORG_DOMAIN}/msp/config.yaml
        
        # Enroll TLS certificate for peer
        print_info "Enrolling TLS certificate for peer${i}.${ORG_DOMAIN}..."
        fabric-ca-client enroll -u https://peer${i}:peer${i}pw@localhost:${CA_PORT} --caname ${CA_NAME} -M ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/peers/peer${i}.${ORG_DOMAIN}/tls --enrollment.profile tls --csr.hosts peer${i}.${ORG_DOMAIN} --csr.hosts localhost --tls.certfiles ${PWD}/organizations/fabric-ca/${ORG_NAME}/tls-cert.pem
        
        # Copy TLS certificates to proper locations
        cp ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/peers/peer${i}.${ORG_DOMAIN}/tls/tlscacerts/* ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/peers/peer${i}.${ORG_DOMAIN}/tls/ca.crt
        cp ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/peers/peer${i}.${ORG_DOMAIN}/tls/signcerts/* ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/peers/peer${i}.${ORG_DOMAIN}/tls/server.crt
        cp ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/peers/peer${i}.${ORG_DOMAIN}/tls/keystore/* ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/peers/peer${i}.${ORG_DOMAIN}/tls/server.key
        
        # Create TLS CA cert directory
        mkdir -p ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/peers/peer${i}.${ORG_DOMAIN}/msp/tlscacerts
        cp ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/peers/peer${i}.${ORG_DOMAIN}/tls/tlscacerts/* ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/peers/peer${i}.${ORG_DOMAIN}/msp/tlscacerts/tlsca.${ORG_DOMAIN}-cert.pem
    done
    
    # Register and enroll users
    print_info "Registering user1..."
    fabric-ca-client register --caname ${CA_NAME} --id.name user1 --id.secret user1pw --id.type client --tls.certfiles ${PWD}/organizations/fabric-ca/${ORG_NAME}/tls-cert.pem
    
    print_info "Enrolling user1..."
    fabric-ca-client enroll -u https://user1:user1pw@localhost:${CA_PORT} --caname ${CA_NAME} -M ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/users/User1@${ORG_DOMAIN}/msp --tls.certfiles ${PWD}/organizations/fabric-ca/${ORG_NAME}/tls-cert.pem
    
    # Copy config.yaml to user MSP
    cp ${FABRIC_CA_CLIENT_HOME}/msp/config.yaml ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/users/User1@${ORG_DOMAIN}/msp/config.yaml
    
    # Register and enroll org admin
    print_info "Registering org admin..."
    fabric-ca-client register --caname ${CA_NAME} --id.name org1admin --id.secret org1adminpw --id.type admin --tls.certfiles ${PWD}/organizations/fabric-ca/${ORG_NAME}/tls-cert.pem
    
    print_info "Enrolling org admin..."
    fabric-ca-client enroll -u https://org1admin:org1adminpw@localhost:${CA_PORT} --caname ${CA_NAME} -M ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/users/Admin@${ORG_DOMAIN}/msp --tls.certfiles ${PWD}/organizations/fabric-ca/${ORG_NAME}/tls-cert.pem
    
    # Copy config.yaml to admin MSP
    cp ${FABRIC_CA_CLIENT_HOME}/msp/config.yaml ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/users/Admin@${ORG_DOMAIN}/msp/config.yaml
fi

# Copy CA cert to MSP cacerts
mkdir -p ${FABRIC_CA_CLIENT_HOME}/msp/cacerts
cp ${FABRIC_CA_CLIENT_HOME}/cacerts/localhost-${CA_PORT}-${CA_NAME}.pem ${FABRIC_CA_CLIENT_HOME}/msp/cacerts/

# Copy TLS CA cert to MSP tlscacerts
mkdir -p ${FABRIC_CA_CLIENT_HOME}/msp/tlscacerts
cp ${PWD}/organizations/fabric-ca/${ORG_NAME}/tls-cert.pem ${FABRIC_CA_CLIENT_HOME}/msp/tlscacerts/ca.crt

print_success "Successfully registered and enrolled all identities for $ORG_NAME organization" 