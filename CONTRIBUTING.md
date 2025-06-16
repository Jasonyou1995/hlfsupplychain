# Contributing to Enterprise Hyperledger Fabric Supply Chain Platform

Thank you for your interest in contributing to our enterprise-grade supply chain platform! This guide will help you understand our development processes, standards, and expectations for contributions.

## 🎯 Mission & Values

Our mission is to build the world's most secure, scalable, and compliant supply chain platform on Hyperledger Fabric. We value:

- **Excellence**: Commitment to the highest quality standards
- **Security**: Security-first mindset in all aspects of development
- **Collaboration**: Open communication and knowledge sharing
- **Innovation**: Continuous improvement and learning
- **Compliance**: Adherence to regulatory and industry standards

## 📋 Table of Contents

- [Getting Started](#-getting-started)
- [Development Environment](#-development-environment)
- [Code Standards](#-code-standards)
- [Testing Requirements](#-testing-requirements)
- [Security Guidelines](#-security-guidelines)
- [Contribution Workflow](#-contribution-workflow)
- [Review Process](#-review-process)
- [Documentation Standards](#-documentation-standards)
- [Release Process](#-release-process)
- [Community Guidelines](#-community-guidelines)

## 🚀 Getting Started

### Prerequisites

Before contributing, ensure you have:

```bash
# Required Software
- Git 2.30+
- Docker 20.10+
- Kubernetes 1.25+
- Go 1.19+
- Node.js 18+
- Python 3.9+
- Make 4.0+

# Development Tools
- Visual Studio Code or GoLand
- Docker Desktop
- kubectl
- helm
- terraform
```

### Repository Structure

```
├── .github/                    # GitHub workflows and templates
├── .taskmaster/               # TaskMaster project management
├── charts/                    # Helm charts for deployment
├── cmd/                       # Application entry points
├── configs/                   # Configuration files
├── docs/                      # Documentation
├── pkg/                       # Go packages
├── scripts/                   # Build and utility scripts
├── test/                      # Test files and fixtures
├── web/                       # Web interface
└── Part1-4/                   # Legacy demo code (to be migrated)
```

### First-Time Setup

```bash
# 1. Fork the repository
git clone https://github.com/YOUR-USERNAME/hlfsupplychain.git
cd hlfsupplychain

# 2. Add upstream remote
git remote add upstream https://github.com/enterprise-org/hlfsupplychain.git

# 3. Install dependencies
make install-deps

# 4. Set up development environment
make dev-setup

# 5. Run initial tests
make test

# 6. Start development environment
make dev-up
```

## 🛠️ Development Environment

### Docker Development Setup

```yaml
# docker-compose.dev.yml
version: "3.8"
services:
  fabric-ca:
    image: hyperledger/fabric-ca:2.5
    environment:
      - FABRIC_CA_HOME=/etc/hyperledger/fabric-ca-server
    ports:
      - "7054:7054"

  peer0-org1:
    image: hyperledger/fabric-peer:2.5
    environment:
      - CORE_PEER_ID=peer0.org1.example.com
      - CORE_PEER_ADDRESS=peer0.org1.example.com:7051
    ports:
      - "7051:7051"
      - "7052:7052"

  orderer:
    image: hyperledger/fabric-orderer:2.5
    environment:
      - ORDERER_GENERAL_LOGLEVEL=INFO
      - ORDERER_GENERAL_LISTENADDRESS=0.0.0.0
    ports:
      - "7050:7050"
```

### Local Development Commands

```bash
# Start all services
make dev-up

# Stop all services
make dev-down

# Rebuild and restart
make dev-restart

# View logs
make dev-logs

# Run tests
make test

# Run security scans
make security-scan

# Format code
make format

# Lint code
make lint
```

## 📏 Code Standards

### Language-Specific Standards

#### Go Standards

```go
// Package documentation is required
// Package supplychain provides enterprise-grade supply chain management
// capabilities built on Hyperledger Fabric.
package supplychain

import (
    "context"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
    "github.com/pkg/errors"
)

// Product represents a supply chain product with comprehensive metadata
type Product struct {
    ID              string    `json:"id" validate:"required,uuid"`
    Name            string    `json:"name" validate:"required,max=100"`
    Category        string    `json:"category" validate:"required,oneof=automotive electronics pharma"`
    Manufacturer    string    `json:"manufacturer" validate:"required"`
    CreatedAt       time.Time `json:"created_at"`
    UpdatedAt       time.Time `json:"updated_at"`
}

// CreateProduct creates a new product in the supply chain ledger
func (sc *SmartContract) CreateProduct(ctx contractapi.TransactionContextInterface,
    productJSON string) (*Product, error) {

    // Input validation
    if productJSON == "" {
        return nil, errors.New("product JSON cannot be empty")
    }

    // Business logic implementation
    product := &Product{
        ID:        generateUUID(),
        CreatedAt: time.Now(),
        UpdatedAt: time.Now(),
    }

    // Error handling with context
    if err := ctx.GetStub().PutState(product.ID, productBytes); err != nil {
        return nil, errors.Wrapf(err, "failed to create product %s", product.ID)
    }

    return product, nil
}
```

#### JavaScript/TypeScript Standards

```typescript
/**
 * Supply Chain API Client
 * Provides type-safe access to the supply chain platform
 */
export class SupplyChainClient {
  private readonly baseUrl: string;
  private readonly apiKey: string;

  constructor(config: ClientConfig) {
    this.baseUrl = config.baseUrl;
    this.apiKey = config.apiKey;
  }

  /**
   * Creates a new product in the supply chain
   * @param product - Product data to create
   * @returns Promise<Product> - Created product
   * @throws {ValidationError} - When product data is invalid
   * @throws {ApiError} - When API request fails
   */
  async createProduct(product: CreateProductRequest): Promise<Product> {
    const validation = this.validateProduct(product);
    if (!validation.isValid) {
      throw new ValidationError(validation.errors);
    }

    try {
      const response = await this.httpClient.post("/api/v2/products", product);
      return response.data;
    } catch (error) {
      throw new ApiError(`Failed to create product: ${error.message}`);
    }
  }
}
```

### Code Quality Standards

| Language       | Linter        | Formatter | Coverage | Security   |
| -------------- | ------------- | --------- | -------- | ---------- |
| **Go**         | golangci-lint | gofmt     | 90%+     | gosec      |
| **TypeScript** | ESLint        | Prettier  | 90%+     | npm audit  |
| **Python**     | pylint        | black     | 90%+     | bandit     |
| **YAML**       | yamllint      | -         | -        | kube-score |

### Configuration Files

```yaml
# .golangci.yml
run:
  timeout: 5m

linters:
  enable:
    - errcheck
    - gosimple
    - govet
    - ineffassign
    - staticcheck
    - typecheck
    - unused
    - varcheck
    - gosec
    - misspell
    - gocyclo
    - dupl

linters-settings:
  gocyclo:
    min-complexity: 10
  dupl:
    threshold: 100
  gosec:
    severity: medium
```

## 🧪 Testing Requirements

### Testing Pyramid

```
                    E2E Tests
                  ↗             ↖
            Integration Tests
          ↗                       ↖
    Unit Tests                     Contract Tests
```

### Test Categories

#### Unit Tests (90%+ Coverage)

```go
func TestCreateProduct(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        want    *Product
        wantErr bool
    }{
        {
            name:  "valid product",
            input: `{"name":"Widget","category":"automotive"}`,
            want:  &Product{Name: "Widget", Category: "automotive"},
        },
        {
            name:    "empty input",
            input:   "",
            wantErr: true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := CreateProduct(tt.input)
            if (err != nil) != tt.wantErr {
                t.Errorf("CreateProduct() error = %v, wantErr %v", err, tt.wantErr)
                return
            }
            if !reflect.DeepEqual(got, tt.want) {
                t.Errorf("CreateProduct() = %v, want %v", got, tt.want)
            }
        })
    }
}
```

#### Integration Tests

```go
func TestSupplyChainWorkflow(t *testing.T) {
    // Setup test network
    network := test.NewTestNetwork(t)
    defer network.Cleanup()

    // Deploy chaincode
    chaincode := network.DeployChaincode("supplychain", "./chaincode")

    // Test complete workflow
    t.Run("create_product", func(t *testing.T) {
        product := &Product{Name: "TestWidget"}
        result := chaincode.Invoke("CreateProduct", product)
        assert.NoError(t, result.Error)
        assert.Equal(t, product.Name, result.Payload.Name)
    })
}
```

#### End-to-End Tests

```typescript
describe("Supply Chain E2E", () => {
  let client: SupplyChainClient;

  beforeAll(async () => {
    client = new SupplyChainClient({
      baseUrl: "http://localhost:8080",
      apiKey: process.env.API_KEY,
    });
  });

  test("complete supply chain workflow", async () => {
    // Create product
    const product = await client.createProduct({
      name: "E2E Test Widget",
      category: "automotive",
    });

    // Transfer ownership
    await client.transferProduct(product.id, "manufacturer-1");

    // Verify traceability
    const trace = await client.traceProduct(product.id);
    expect(trace.events).toHaveLength(2);
  });
});
```

### Performance Tests

```go
func BenchmarkCreateProduct(b *testing.B) {
    sc := &SmartContract{}
    ctx := test.NewMockContext()

    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        productJSON := fmt.Sprintf(`{"name":"Product%d","category":"automotive"}`, i)
        _, err := sc.CreateProduct(ctx, productJSON)
        if err != nil {
            b.Fatal(err)
        }
    }
}
```

## 🔒 Security Guidelines

### Security Checklist

Before submitting code, ensure:

- [ ] **Input Validation**: All inputs are validated and sanitized
- [ ] **Error Handling**: Errors don't leak sensitive information
- [ ] **Authentication**: Proper authentication mechanisms
- [ ] **Authorization**: Role-based access controls
- [ ] **Cryptography**: Approved cryptographic libraries
- [ ] **Secrets**: No hardcoded secrets or credentials
- [ ] **Dependencies**: All dependencies are up-to-date and secure
- [ ] **Logging**: Sensitive data is not logged

### Security Scanning

```bash
# Run security scans
make security-scan

# Specific security tools
gosec ./...                    # Go security checker
npm audit                      # Node.js vulnerability scanner
bandit -r ./                   # Python security checker
trivy image myimage:latest     # Container vulnerability scanner
```

### Secure Coding Examples

```go
// ✅ Good: Input validation
func (sc *SmartContract) CreateProduct(ctx contractapi.TransactionContextInterface,
    productJSON string) error {

    // Validate input
    if len(productJSON) == 0 {
        return fmt.Errorf("product JSON cannot be empty")
    }

    if len(productJSON) > 10000 {
        return fmt.Errorf("product JSON too large")
    }

    // Sanitize input
    var product Product
    if err := json.Unmarshal([]byte(productJSON), &product); err != nil {
        return fmt.Errorf("invalid JSON format")
    }

    // Validate business rules
    if err := validateProduct(&product); err != nil {
        return fmt.Errorf("product validation failed: %w", err)
    }

    return nil
}

// ❌ Bad: No input validation
func (sc *SmartContract) CreateProductBad(ctx contractapi.TransactionContextInterface,
    productJSON string) error {

    var product Product
    json.Unmarshal([]byte(productJSON), &product) // No error checking

    // Direct usage without validation
    return ctx.GetStub().PutState(product.ID, []byte(productJSON))
}
```

## 🔄 Contribution Workflow

### 1. Issue Creation

Before starting work, create or find an issue:

```markdown
## Issue Template

**Summary**: Brief description of the issue

**Problem**: What problem does this solve?

**Proposed Solution**: How do you plan to solve it?

**Acceptance Criteria**:

- [ ] Criterion 1
- [ ] Criterion 2

**Definition of Done**:

- [ ] Code implemented
- [ ] Tests written (90%+ coverage)
- [ ] Documentation updated
- [ ] Security review passed
- [ ] Performance benchmarks met
```

### 2. Branch Naming

Use descriptive branch names:

```bash
# Feature branches
feature/HLF-123-add-product-traceability
feature/HLF-456-implement-audit-logging

# Bug fix branches
bugfix/HLF-789-fix-product-validation

# Hotfix branches
hotfix/HLF-999-security-patch
```

### 3. Commit Guidelines

Follow conventional commits:

```bash
# Format: type(scope): description
feat(chaincode): add product traceability functionality
fix(api): resolve authentication token validation
docs(readme): update installation instructions
test(unit): add product validation test cases
refactor(storage): optimize database queries
perf(consensus): improve transaction throughput
```

### 4. Pull Request Process

```markdown
## Pull Request Template

### Description

Brief description of changes made.

### Type of Change

- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

### Testing

- [ ] Unit tests added/updated
- [ ] Integration tests pass
- [ ] End-to-end tests pass
- [ ] Performance tests pass

### Security

- [ ] Security scan passed
- [ ] No sensitive data exposed
- [ ] Authentication/authorization verified

### Checklist

- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] Breaking changes documented
```

## 👥 Review Process

### Review Criteria

All contributions must pass:

1. **Automated Checks**:

   - CI/CD pipeline passes
   - All tests pass (90%+ coverage)
   - Security scans pass
   - Code quality metrics met

2. **Code Review**:

   - At least 2 approvals required
   - One approval from code owner
   - Security review for critical changes

3. **Documentation Review**:
   - Documentation updated
   - API documentation current
   - Breaking changes documented

### Review Checklist

```markdown
#### Code Quality

- [ ] Code is clean and readable
- [ ] No code duplication
- [ ] Proper error handling
- [ ] Performance considerations

#### Testing

- [ ] Adequate test coverage
- [ ] Edge cases covered
- [ ] Integration tests included

#### Security

- [ ] Input validation present
- [ ] No security vulnerabilities
- [ ] Secrets properly managed

#### Documentation

- [ ] Code is well-commented
- [ ] Public APIs documented
- [ ] README updated if needed
```

## 📚 Documentation Standards

### Code Documentation

```go
// Product represents a supply chain product with full lifecycle tracking.
// It contains all necessary metadata for compliance and traceability.
type Product struct {
    // ID is the unique identifier for the product (UUID v4)
    ID string `json:"id" validate:"required,uuid"`

    // Name is the human-readable product name (max 100 characters)
    Name string `json:"name" validate:"required,max=100"`

    // Category defines the product type for compliance rules
    Category ProductCategory `json:"category" validate:"required"`
}

// CreateProduct creates a new product in the supply chain ledger.
// It performs validation, generates a unique ID, and stores the product
// with proper audit trails and event logging.
//
// Parameters:
//   - ctx: Transaction context for blockchain operations
//   - productJSON: JSON representation of the product to create
//
// Returns:
//   - *Product: The created product with generated ID and timestamps
//   - error: Any validation or storage errors
//
// Example:
//   product, err := contract.CreateProduct(ctx, `{"name":"Widget","category":"automotive"}`)
//   if err != nil {
//       return fmt.Errorf("failed to create product: %w", err)
//   }
func (sc *SmartContract) CreateProduct(ctx contractapi.TransactionContextInterface,
    productJSON string) (*Product, error) {
    // Implementation
}
```

### API Documentation

Use OpenAPI 3.0 specification:

```yaml
openapi: 3.0.0
info:
  title: Supply Chain Platform API
  description: Enterprise-grade supply chain management
  version: 2.0.0
  contact:
    name: API Support
    email: api-support@enterprise-supply-chain.com

paths:
  /api/v2/products:
    post:
      summary: Create a new product
      description: Creates a new product in the supply chain with full validation
      operationId: createProduct
      security:
        - BearerAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/CreateProductRequest"
      responses:
        "201":
          description: Product created successfully
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/Product"
        "400":
          description: Invalid request data
        "401":
          description: Authentication required
        "403":
          description: Insufficient permissions
```

## 🚀 Release Process

### Release Branches

```bash
# Create release branch
git checkout -b release/v2.1.0

# Update version numbers
make update-version VERSION=2.1.0

# Run full test suite
make test-all

# Create release PR
gh pr create --title "Release v2.1.0" --body "Release notes..."
```

### Semantic Versioning

We follow [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Release Checklist

- [ ] All tests pass
- [ ] Security scans complete
- [ ] Performance benchmarks met
- [ ] Documentation updated
- [ ] Release notes prepared
- [ ] Deployment tested
- [ ] Rollback plan ready

## 🤝 Community Guidelines

### Code of Conduct

We are committed to providing a welcoming and inclusive environment. All participants must adhere to our [Code of Conduct](CODE_OF_CONDUCT.md).

### Communication Channels

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: General questions and discussions
- **Discord**: Real-time community chat
- **Email**: enterprise-support@your-org.com

### Recognition

We recognize contributors through:

- **Contributor Hall of Fame**: Monthly recognition
- **Maintainer Program**: Path to becoming a maintainer
- **Conference Speaking**: Opportunities to present work
- **Swag and Rewards**: Contributor merchandise

## 📞 Getting Help

### Resources

- **Documentation**: [docs/](./docs/)
- **Examples**: [examples/](./examples/)
- **FAQ**: [FAQ.md](./FAQ.md)
- **Architecture**: [docs/architecture/](./docs/architecture/)

### Support Channels

- **GitHub Issues**: Technical issues and bugs
- **GitHub Discussions**: Questions and feature discussions
- **Discord**: `#contributors` channel for real-time help
- **Email**: developer-support@enterprise-supply-chain.com

### Office Hours

Join our weekly office hours:

- **When**: Wednesdays 2:00 PM UTC
- **Where**: Discord voice channel
- **What**: Q&A, code review, architecture discussions

---

Thank you for contributing to the future of supply chain management! Together, we're building a platform that will transform how global supply chains operate. 🌟

**Happy Coding!** 🚀
