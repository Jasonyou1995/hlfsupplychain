# Enterprise Hyperledger Fabric Supply Chain Platform v2.5+

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Hyperledger Fabric](https://img.shields.io/badge/Hyperledger%20Fabric-2.5.5-orange)](https://hyperledger-fabric.readthedocs.io/)
[![Node.js](https://img.shields.io/badge/Node.js-18+-green)](https://nodejs.org/)
[![Go](https://img.shields.io/badge/Go-1.19+-blue)](https://golang.org/)
[![Docker](https://img.shields.io/badge/Docker-20.10+-blue)](https://www.docker.com/)

A production-ready, enterprise-grade supply chain management platform built on Hyperledger Fabric with comprehensive security features, real-time traceability, and multi-organization support.

## 🚀 Key Features

### Core Functionality

- **Product Lifecycle Management**: Complete product traceability from manufacturing to delivery
- **Multi-Organization Support**: Manufacturer, Supplier, Logistics, Retailer, and Auditor roles
- **Real-time Tracking**: Live updates on product location, status, and quality metrics
- **Quality Assurance**: Integrated quality checks and certifications management
- **Audit Trail**: Immutable blockchain-based audit trails for compliance

### Security & Enterprise Features

- **JWT Authentication**: Secure API access with role-based permissions
- **Rate Limiting**: Advanced rate limiting for API and blockchain operations
- **Input Validation**: Comprehensive input sanitization and validation
- **TLS Encryption**: End-to-end encrypted communications
- **Audit Logging**: Detailed security and operational logging
- **CORS Protection**: Configurable cross-origin resource sharing
- **Security Headers**: Comprehensive HTTP security headers via Helmet.js

### Modern Architecture

- **Hyperledger Fabric 2.5+**: Latest enterprise blockchain technology
- **ES Modules**: Modern JavaScript with full ES module support
- **Docker Compose**: Container orchestration for easy deployment
- **Gateway API**: Latest Fabric Gateway SDK implementation
- **RESTful APIs**: Production-ready REST API with OpenAPI documentation
- **Microservices Ready**: Scalable architecture for enterprise deployment

## 📋 Prerequisites

### Required Software

- **Docker**: v20.10+ and Docker Compose v2.0+
- **Node.js**: v18.0+ with npm v8.0+
- **Go**: v1.19+ for chaincode compilation
- **Git**: For version control
- **curl/jq**: For API testing (optional but recommended)

### System Requirements

- **RAM**: Minimum 8GB, Recommended 16GB
- **Storage**: Minimum 20GB free space
- **OS**: Linux, macOS, or Windows with WSL2
- **Network**: Open ports 3000, 7050-7054, 8050-8054, 9050-9054, 10050-10054, 11050-11054

## 🛠 Installation & Setup

### Quick Start (Production Deployment)

1. **Clone the repository:**

   ```bash
   git clone https://github.com/enterprise-supply-chain/hlf-supply-chain-platform.git
   cd hlf-supply-chain-platform
   ```

2. **Run the automated deployment:**

   ```bash
   ./scripts/deploy.sh
   ```

3. **Verify the deployment:**
   ```bash
   ./scripts/deploy.sh verify
   ```

### Manual Step-by-Step Setup

1. **Prerequisites Check:**

   ```bash
   # Check Docker
   docker --version && docker-compose --version

   # Check Node.js
   node --version && npm --version

   # Check Go
   go version
   ```

2. **Generate Crypto Material:**

   ```bash
   cd network
   ./scripts/registerEnroll.sh
   cd ..
   ```

3. **Start the Network:**

   ```bash
   cd network
   docker-compose up -d
   cd ..
   ```

4. **Deploy Chaincode:**

   ```bash
   cd network
   # Package chaincode
   peer lifecycle chaincode package supplychain.tar.gz --path ../chaincode/supplychain --lang golang --label supplychain_1.0.0

   # Install on peers (repeat for each organization)
   peer lifecycle chaincode install supplychain.tar.gz

   # Approve and commit (follow full process in deploy.sh)
   cd ..
   ```

5. **Setup Client Environment:**
   ```bash
   cd client
   npm install
   cp .env.example .env
   # Edit .env with your configuration
   npm start
   ```

## 🧪 Testing Guide

### 1. Network Health Tests

#### Test Docker Containers

```bash
# Check all containers are running
docker-compose -f network/docker-compose.yaml ps

# Expected: All containers should show "Up" status
# Services: CAs, Orderers, Peers for all 5 organizations
```

#### Test Blockchain Network

```bash
cd network

# Set environment for manufacturer
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="ManufacturerMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/manufacturer.supplychain.com/peers/peer0.manufacturer.supplychain.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/manufacturer.supplychain.com/users/Admin@manufacturer.supplychain.com/msp
export CORE_PEER_ADDRESS=localhost:7051

# Test chaincode query
peer chaincode query -C supplychain-channel -n supplychain -c '{"function":"GetAllProducts","Args":[]}'

# Expected: JSON array with sample products (PROD001, PROD002, etc.)
```

### 2. Chaincode Unit Tests

```bash
cd chaincode/supplychain

# Run Go tests
go test -v

# Expected output:
# === RUN   TestProductSerialization
# --- PASS: TestProductSerialization (0.00s)
# === RUN   TestTrackingEventSerialization
# --- PASS: TestTrackingEventSerialization (0.00s)
# === RUN   TestBusinessLogicValidation
# --- PASS: TestBusinessLogicValidation (0.00s)
# PASS
```

### 3. Client API Tests

#### Start the API Server

```bash
cd client
npm start

# Expected output:
# 🚀 Secure Supply Chain API Server running on port 3000
# 📊 Health check available at http://localhost:3000/health
# 🔒 Security features: Rate limiting, JWT auth, input validation, CORS, Helmet
```

#### Test Health Endpoint

```bash
curl -X GET http://localhost:3000/health

# Expected response:
# {
#   "status": "healthy",
#   "timestamp": "2024-12-23T10:30:00.000Z",
#   "version": "1.0.0"
# }
```

#### Test Authentication

```bash
# Login to get JWT token
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "manufacturer_admin",
    "password": "secure_password_123"
  }'

# Expected response:
# {
#   "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
#   "expiresIn": "24h"
# }

# Export token for subsequent tests
export JWT_TOKEN="<your-token-here>"
```

#### Test Gateway Initialization

```bash
curl -X POST http://localhost:3000/api/gateway/init \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -d '{
    "organization": "manufacturer"
  }'

# Expected response:
# {
#   "message": "Gateway initialized successfully",
#   "organization": "manufacturer"
# }
```

### 4. Product Management Tests

#### Create a New Product

```bash
curl -X POST http://localhost:3000/api/blockchain/products \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -d '{
    "id": "TEST001",
    "name": "Test Product",
    "description": "A product for testing purposes",
    "manufacturerId": "MFG001",
    "batchId": "BATCH001"
  }'

# Expected response:
# {
#   "message": "Product created successfully",
#   "result": "..."
# }
```

#### Retrieve Product Information

```bash
curl -X GET http://localhost:3000/api/blockchain/products/TEST001 \
  -H "Authorization: Bearer $JWT_TOKEN"

# Expected response:
# {
#   "id": "TEST001",
#   "name": "Test Product",
#   "description": "A product for testing purposes",
#   "manufacturerId": "MFG001",
#   "batchId": "BATCH001",
#   "status": "created",
#   "createdAt": "2024-12-23T10:30:00.000Z",
#   "trackingEvents": [],
#   "qualityMetrics": {},
#   "certifications": []
# }
```

#### Add Tracking Event

```bash
curl -X POST http://localhost:3000/api/blockchain/products/TEST001/tracking \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -d '{
    "eventType": "shipped",
    "location": "Manufacturing Facility A",
    "data": {
      "temperature": "22°C",
      "humidity": "45%",
      "carrier": "Express Logistics"
    }
  }'

# Expected response:
# {
#   "message": "Tracking event added successfully",
#   "result": "..."
# }
```

#### Get All Products

```bash
curl -X GET http://localhost:3000/api/blockchain/products \
  -H "Authorization: Bearer $JWT_TOKEN"

# Expected response:
# [
#   {
#     "id": "PROD001",
#     "name": "Sample Product 1",
#     ...
#   },
#   {
#     "id": "TEST001",
#     "name": "Test Product",
#     ...
#   }
# ]
```

### 5. Security Tests

#### Test Rate Limiting

```bash
# Send multiple rapid requests (should be rate limited after 100 requests/minute)
for i in {1..105}; do
  curl -s -o /dev/null -w "%{http_code}\n" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    http://localhost:3000/api/blockchain/products
done

# Expected: First 100 should return 200, subsequent should return 429
```

#### Test Invalid Authentication

```bash
curl -X GET http://localhost:3000/api/blockchain/products \
  -H "Authorization: Bearer invalid-token"

# Expected response:
# {
#   "error": "Invalid or expired token"
# }
```

#### Test Input Validation

```bash
curl -X POST http://localhost:3000/api/blockchain/products \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -d '{
    "id": "",
    "name": "",
    "description": "Valid description",
    "manufacturerId": "invalid@id!",
    "batchId": "valid"
  }'

# Expected response:
# {
#   "error": "Validation failed",
#   "details": [
#     {
#       "msg": "Invalid value",
#       "param": "id",
#       "location": "body"
#     },
#     ...
#   ]
# }
```

### 6. Performance Tests

#### Load Testing with curl

```bash
# Test concurrent requests
seq 1 50 | xargs -n1 -P10 -I{} curl -s -o /dev/null -w "%{time_total}\n" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  http://localhost:3000/api/blockchain/products

# Expected: All requests should complete within 2-5 seconds
```

#### Memory and CPU Monitoring

```bash
# Monitor API server performance
top -p $(pgrep -f "node.*api-server")

# Monitor Docker containers
docker stats

# Expected: Reasonable CPU and memory usage under load
```

### 7. Integration Tests

#### End-to-End Product Lifecycle Test

```bash
#!/bin/bash
# Complete product lifecycle test script

JWT_TOKEN=$(curl -s -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "manufacturer_admin", "password": "secure_password_123"}' \
  | jq -r .token)

# Initialize gateway
curl -s -X POST http://localhost:3000/api/gateway/init \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -d '{"organization": "manufacturer"}'

# Create product
PRODUCT_ID="E2E$(date +%s)"
curl -s -X POST http://localhost:3000/api/blockchain/products \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -d "{
    \"id\": \"$PRODUCT_ID\",
    \"name\": \"E2E Test Product\",
    \"description\": \"End-to-end test product\",
    \"manufacturerId\": \"MFG001\",
    \"batchId\": \"E2E_BATCH\"
  }"

# Add tracking events
for event in "manufactured" "shipped" "received" "quality_check" "delivered"; do
  curl -s -X POST http://localhost:3000/api/blockchain/products/$PRODUCT_ID/tracking \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    -d "{
      \"eventType\": \"$event\",
      \"location\": \"Test Location\",
      \"data\": {\"step\": \"$event\"}
    }"
  sleep 2
done

# Verify final product state
curl -s -X GET http://localhost:3000/api/blockchain/products/$PRODUCT_ID \
  -H "Authorization: Bearer $JWT_TOKEN" \
  | jq .

echo "E2E test completed for product: $PRODUCT_ID"
```

### 8. Automated Test Suite

#### Run All Tests

```bash
# Chaincode tests
cd chaincode/supplychain && go test -v

# Client tests
cd ../../client && npm test

# Integration tests
cd .. && ./tests/integration-test.sh

# Security audit
cd client && npm audit --audit-level moderate
```

## 🛡️ Security Best Practices Implementation

### 1. Authentication & Authorization

- **JWT Tokens**: 24-hour expiration with secure secret generation
- **Role-based Access**: Organization-based permissions
- **Password Security**: bcrypt hashing with salt rounds
- **Session Management**: Stateless JWT implementation

### 2. Input Validation & Sanitization

- **express-validator**: Comprehensive input validation
- **XSS Protection**: Input sanitization and escaping
- **SQL Injection Prevention**: Parameterized queries (where applicable)
- **Path Traversal Protection**: Filename validation

### 3. Rate Limiting & DDoS Protection

- **Global Rate Limiting**: 1000 requests per 15 minutes per IP
- **API Rate Limiting**: 100 requests per minute per IP
- **Blockchain Rate Limiting**: 10 operations per minute per IP
- **Adaptive Throttling**: Configurable limits based on load

### 4. Network Security

- **TLS Encryption**: All network communications encrypted
- **Certificate Management**: Proper CA and certificate handling
- **CORS Configuration**: Configurable allowed origins
- **Security Headers**: Comprehensive HTTP security headers

### 5. Monitoring & Logging

- **Structured Logging**: JSON-formatted logs with correlation IDs
- **Security Event Logging**: Authentication failures and security events
- **Performance Monitoring**: Request timing and resource usage
- **Error Tracking**: Comprehensive error reporting

## 🚀 Production Deployment

### Docker Production Setup

```bash
# Build production images
docker build -t supply-chain-api:latest -f client/Dockerfile client/
docker build -t supply-chain-chaincode:latest -f chaincode/Dockerfile chaincode/

# Deploy with production compose
docker-compose -f docker-compose.prod.yml up -d
```

### Environment Configuration

```bash
# Production .env settings
NODE_ENV=production
LOG_LEVEL=warn
JWT_SECRET=<strong-random-secret>
ALLOWED_ORIGINS=https://your-domain.com
TLS_ENABLED=true
RATE_LIMIT_ENABLED=true
```

### SSL/TLS Setup

```bash
# Generate production certificates
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout network/tls/server.key \
  -out network/tls/server.crt

# Update docker-compose for HTTPS
# Configure reverse proxy (nginx/Apache)
```

## 📊 Monitoring & Maintenance

### Health Monitoring

- **Health Endpoints**: `/health` for service status
- **Metrics Collection**: Prometheus-compatible metrics
- **Log Aggregation**: Centralized logging with ELK stack
- **Alerting**: Automated alerts for failures

### Performance Tuning

- **Database Optimization**: CouchDB/LevelDB tuning
- **Caching Strategy**: Redis/in-memory caching
- **Load Balancing**: Multiple API server instances
- **Resource Scaling**: Horizontal scaling configuration

## 🐛 Troubleshooting

### Common Issues

#### Chaincode Deployment Fails

```bash
# Check peer logs
docker logs peer0.manufacturer.supplychain.com

# Verify package installation
peer lifecycle chaincode queryinstalled

# Check commit readiness
peer lifecycle chaincode checkcommitreadiness --channelID supplychain-channel --name supplychain --version 1.0.0 --sequence 1
```

#### API Server Won't Start

```bash
# Check environment variables
cat client/.env

# Verify dependencies
cd client && npm audit

# Check port availability
netstat -tulpn | grep :3000
```

#### Network Connectivity Issues

```bash
# Check container networking
docker network ls
docker network inspect supplychain-network

# Verify service discovery
docker exec peer0.manufacturer.supplychain.com ping orderer1.supplychain.com
```

### Debug Mode

```bash
# Enable debug logging
export LOG_LEVEL=debug

# Start with verbose output
npm run dev
```

## 📝 API Documentation

### Authentication Endpoints

- `POST /api/auth/login` - Authenticate user and get JWT token

### Gateway Management

- `POST /api/gateway/init` - Initialize Fabric Gateway connection

### Product Management

- `POST /api/blockchain/products` - Create new product
- `GET /api/blockchain/products` - Get all products
- `GET /api/blockchain/products/:id` - Get specific product
- `POST /api/blockchain/products/:id/tracking` - Add tracking event

### System Endpoints

- `GET /health` - System health check

For detailed API documentation, see `/docs/api.md` after deployment.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- [Hyperledger Fabric Documentation](https://hyperledger-fabric.readthedocs.io/)
- [Enterprise Supply Chain Best Practices](https://www.ibm.com/blockchain/supply-chain/)
- [Security Guidelines](https://hyperledger-fabric.readthedocs.io/en/latest/secured_asset_transfer/secured_private_asset_transfer_tutorial.html)

## 📞 Support

For support and questions:

- Create an issue in this repository
- Contact the development team
- Check the troubleshooting section above

---

**Built with ❤️ using Hyperledger Fabric 2.5+ for enterprise supply chain management**
