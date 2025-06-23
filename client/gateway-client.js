/**
 * Enterprise Hyperledger Fabric Supply Chain Platform v2.5+
 * Gateway API Client Example
 * Author: Supply Chain Platform Team
 * Last Modified: December 16, 2025
 * License: Apache-2.0
 */

const { Gateway, Wallets, DefaultEventHandlerStrategies, DefaultQueryHandlerStrategies } = require('fabric-network');
const { TextDecoder } = require('util');
const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');

class SupplyChainGatewayClient {
    constructor() {
        this.gateway = null;
        this.network = null;
        this.contract = null;
        this.wallet = null;
        this.channelName = 'supplychain-channel';
        this.chaincodeName = 'supplychain';
        this.orgName = 'manufacturer'; // Default organization
        this.userId = 'appUser';
    }

    /**
     * Initialize the Gateway client with connection profile and wallet
     */
    async initialize(orgName = 'manufacturer', userId = 'appUser') {
        try {
            this.orgName = orgName;
            this.userId = userId;

            console.log(`🚀 Initializing Gateway client for ${orgName} organization...`);

            // Load connection profile
            const connectionProfile = await this.loadConnectionProfile(orgName);
            
            // Create wallet and import user identity
            this.wallet = await this.createWallet();
            await this.importUserIdentity();

            // Create gateway instance with advanced options
            this.gateway = new Gateway();
            
            const gatewayOptions = {
                wallet: this.wallet,
                identity: this.userId,
                discovery: {
                    enabled: true,
                    asLocalhost: true // Set to false in production
                },
                eventHandlerOptions: {
                    commitTimeout: 300, // 5 minutes
                    strategy: DefaultEventHandlerStrategies.PREFER_MSPID_SCOPE_ANYFORTX
                },
                queryHandlerOptions: {
                    timeout: 30, // 30 seconds
                    strategy: DefaultQueryHandlerStrategies.PREFER_MSPID_SCOPE_ROUND_ROBIN
                }
            };

            // Connect to gateway
            await this.gateway.connect(connectionProfile, gatewayOptions);
            console.log('✅ Connected to Fabric Gateway');

            // Get network and contract
            this.network = await this.gateway.getNetwork(this.channelName);
            this.contract = this.network.getContract(this.chaincodeName);

            console.log(`✅ Connected to channel: ${this.channelName}`);
            console.log(`✅ Got contract: ${this.chaincodeName}`);

            // Set up event listeners
            await this.setupEventListeners();

            return true;
        } catch (error) {
            console.error('❌ Failed to initialize Gateway client:', error);
            throw error;
        }
    }

    /**
     * Load connection profile for the specified organization
     */
    async loadConnectionProfile(orgName) {
        const profilePath = path.join(__dirname, '..', 'network', 'connection-profiles', `connection-${orgName}.yaml`);
        
        if (!fs.existsSync(profilePath)) {
            // Create a basic connection profile if it doesn't exist
            await this.createConnectionProfile(orgName);
        }

        const profileData = fs.readFileSync(profilePath, 'utf8');
        return yaml.load(profileData);
    }

    /**
     * Create a connection profile for the organization
     */
    async createConnectionProfile(orgName) {
        const profileDir = path.join(__dirname, '..', 'network', 'connection-profiles');
        if (!fs.existsSync(profileDir)) {
            fs.mkdirSync(profileDir, { recursive: true });
        }

        const orgConfig = this.getOrgConfig(orgName);
        const connectionProfile = {
            name: `${orgName}-network`,
            version: '1.0.0',
            client: {
                organization: orgConfig.mspId,
                connection: {
                    timeout: {
                        peer: {
                            endorser: '300'
                        }
                    }
                }
            },
            organizations: {
                [orgConfig.mspId]: {
                    mspid: orgConfig.mspId,
                    peers: [`peer0.${orgConfig.domain}`],
                    certificateAuthorities: [`ca.${orgConfig.domain}`]
                }
            },
            peers: {
                [`peer0.${orgConfig.domain}`]: {
                    url: `grpcs://localhost:${orgConfig.peerPort}`,
                    tlsCACerts: {
                        path: `../network/organizations/peerOrganizations/${orgConfig.domain}/peers/peer0.${orgConfig.domain}/tls/ca.crt`
                    },
                    grpcOptions: {
                        'ssl-target-name-override': `peer0.${orgConfig.domain}`,
                        'hostnameOverride': `peer0.${orgConfig.domain}`
                    }
                }
            },
            certificateAuthorities: {
                [`ca.${orgConfig.domain}`]: {
                    url: `https://localhost:${orgConfig.caPort}`,
                    caName: `ca.${orgConfig.domain}`,
                    tlsCACerts: {
                        path: `../network/organizations/fabric-ca/${orgName}/tls-cert.pem`
                    },
                    httpOptions: {
                        verify: false
                    }
                }
            }
        };

        const profilePath = path.join(profileDir, `connection-${orgName}.yaml`);
        fs.writeFileSync(profilePath, yaml.dump(connectionProfile));
        console.log(`✅ Created connection profile: ${profilePath}`);
    }

    /**
     * Get organization configuration
     */
    getOrgConfig(orgName) {
        const configs = {
            manufacturer: {
                domain: 'manufacturer.supplychain.com',
                mspId: 'ManufacturerMSP',
                peerPort: 7051,
                caPort: 8054
            },
            supplier: {
                domain: 'supplier.supplychain.com',
                mspId: 'SupplierMSP',
                peerPort: 8051,
                caPort: 9054
            },
            logistics: {
                domain: 'logistics.supplychain.com',
                mspId: 'LogisticsMSP',
                peerPort: 9051,
                caPort: 10054
            },
            retailer: {
                domain: 'retailer.supplychain.com',
                mspId: 'RetailerMSP',
                peerPort: 10051,
                caPort: 11054
            },
            auditor: {
                domain: 'auditor.supplychain.com',
                mspId: 'AuditorMSP',
                peerPort: 11051,
                caPort: 12054
            }
        };

        return configs[orgName] || configs.manufacturer;
    }

    /**
     * Create wallet and import user identity
     */
    async createWallet() {
        const walletPath = path.join(__dirname, 'wallet');
        const wallet = await Wallets.newFileSystemWallet(walletPath);
        console.log(`✅ Wallet path: ${walletPath}`);
        return wallet;
    }

    /**
     * Import user identity into wallet
     */
    async importUserIdentity() {
        const identity = await this.wallet.get(this.userId);
        if (identity) {
            console.log(`✅ Identity ${this.userId} already exists in wallet`);
            return;
        }

        const orgConfig = this.getOrgConfig(this.orgName);
        const credPath = path.join(__dirname, '..', 'network', 'organizations', 'peerOrganizations', orgConfig.domain);
        const certPath = path.join(credPath, 'users', `User1@${orgConfig.domain}`, 'msp', 'signcerts');
        const keyPath = path.join(credPath, 'users', `User1@${orgConfig.domain}`, 'msp', 'keystore');

        // Read certificate and private key
        const certFiles = fs.readdirSync(certPath);
        const keyFiles = fs.readdirSync(keyPath);

        if (certFiles.length === 0 || keyFiles.length === 0) {
            throw new Error(`Certificate or key files not found for ${this.orgName}`);
        }

        const cert = fs.readFileSync(path.join(certPath, certFiles[0])).toString();
        const key = fs.readFileSync(path.join(keyPath, keyFiles[0])).toString();

        const x509Identity = {
            credentials: {
                certificate: cert,
                privateKey: key,
            },
            mspId: orgConfig.mspId,
            type: 'X.509',
        };

        await this.wallet.put(this.userId, x509Identity);
        console.log(`✅ Successfully imported identity ${this.userId} for ${this.orgName}`);
    }

    /**
     * Set up event listeners for chaincode events
     */
    async setupEventListeners() {
        try {
            // Listen for ProductUpdated events
            const productUpdatedListener = async (event) => {
                const payload = JSON.parse(event.payload.toString());
                console.log('📦 Product Updated Event:', {
                    eventName: event.eventName,
                    chaincodeId: event.chaincodeId,
                    txId: event.getTransactionEvent().transactionId,
                    product: payload
                });
            };

            await this.contract.addContractListener(productUpdatedListener, 'ProductUpdated');

            // Listen for TrackingEventAdded events
            const trackingEventListener = async (event) => {
                const payload = JSON.parse(event.payload.toString());
                console.log('📍 Tracking Event Added:', {
                    eventName: event.eventName,
                    chaincodeId: event.chaincodeId,
                    txId: event.getTransactionEvent().transactionId,
                    trackingEvent: payload
                });
            };

            await this.contract.addContractListener(trackingEventListener, 'TrackingEventAdded');

            // Listen for ProductAlert events
            const alertListener = async (event) => {
                const payload = JSON.parse(event.payload.toString());
                console.log('🚨 Product Alert:', {
                    eventName: event.eventName,
                    chaincodeId: event.chaincodeId,
                    txId: event.getTransactionEvent().transactionId,
                    alert: payload
                });
            };

            await this.contract.addContractListener(alertListener, 'ProductAlert');

            console.log('✅ Event listeners set up successfully');
        } catch (error) {
            console.error('❌ Failed to set up event listeners:', error);
        }
    }

    /**
     * Initialize the ledger with sample data
     */
    async initLedger() {
        try {
            console.log('🔄 Initializing ledger...');
            const result = await this.contract.submitTransaction('InitLedger');
            console.log('✅ Ledger initialized successfully');
            return result;
        } catch (error) {
            console.error('❌ Failed to initialize ledger:', error);
            throw error;
        }
    }

    /**
     * Create a new product
     */
    async createProduct(id, name, description, manufacturerId, batchId) {
        try {
            console.log(`🔄 Creating product: ${id}`);
            const result = await this.contract.submitTransaction(
                'CreateProduct',
                id,
                name,
                description,
                manufacturerId,
                batchId
            );
            console.log(`✅ Product ${id} created successfully`);
            return result;
        } catch (error) {
            console.error(`❌ Failed to create product ${id}:`, error);
            throw error;
        }
    }

    /**
     * Read a product by ID
     */
    async readProduct(id) {
        try {
            console.log(`🔄 Reading product: ${id}`);
            const result = await this.contract.evaluateTransaction('ReadProduct', id);
            const product = JSON.parse(result.toString());
            console.log(`✅ Product ${id} retrieved successfully`);
            return product;
        } catch (error) {
            console.error(`❌ Failed to read product ${id}:`, error);
            throw error;
        }
    }

    /**
     * Update a product
     */
    async updateProduct(id, status, location, temperature, humidity) {
        try {
            console.log(`🔄 Updating product: ${id}`);
            const result = await this.contract.submitTransaction(
                'UpdateProduct',
                id,
                status,
                location,
                temperature.toString(),
                humidity.toString()
            );
            console.log(`✅ Product ${id} updated successfully`);
            return result;
        } catch (error) {
            console.error(`❌ Failed to update product ${id}:`, error);
            throw error;
        }
    }

    /**
     * Add a tracking event to a product
     */
    async addTrackingEvent(productId, eventType, location, data = {}) {
        try {
            console.log(`🔄 Adding tracking event to product: ${productId}`);
            const result = await this.contract.submitTransaction(
                'AddTrackingEvent',
                productId,
                eventType,
                location,
                JSON.stringify(data)
            );
            console.log(`✅ Tracking event added to product ${productId}`);
            return result;
        } catch (error) {
            console.error(`❌ Failed to add tracking event to product ${productId}:`, error);
            throw error;
        }
    }

    /**
     * Get all products
     */
    async getAllProducts() {
        try {
            console.log('🔄 Getting all products...');
            const result = await this.contract.evaluateTransaction('GetAllProducts');
            const products = JSON.parse(result.toString());
            console.log(`✅ Retrieved ${products.length} products`);
            return products;
        } catch (error) {
            console.error('❌ Failed to get all products:', error);
            throw error;
        }
    }

    /**
     * Query products by manufacturer
     */
    async queryProductsByManufacturer(manufacturerId) {
        try {
            console.log(`🔄 Querying products by manufacturer: ${manufacturerId}`);
            const result = await this.contract.evaluateTransaction('QueryProductsByManufacturer', manufacturerId);
            const products = JSON.parse(result.toString());
            console.log(`✅ Retrieved ${products.length} products for manufacturer ${manufacturerId}`);
            return products;
        } catch (error) {
            console.error(`❌ Failed to query products by manufacturer ${manufacturerId}:`, error);
            throw error;
        }
    }

    /**
     * Query products by status
     */
    async queryProductsByStatus(status) {
        try {
            console.log(`🔄 Querying products by status: ${status}`);
            const result = await this.contract.evaluateTransaction('QueryProductsByStatus', status);
            const products = JSON.parse(result.toString());
            console.log(`✅ Retrieved ${products.length} products with status ${status}`);
            return products;
        } catch (error) {
            console.error(`❌ Failed to query products by status ${status}:`, error);
            throw error;
        }
    }

    /**
     * Get product history
     */
    async getProductHistory(productId) {
        try {
            console.log(`🔄 Getting history for product: ${productId}`);
            const result = await this.contract.evaluateTransaction('GetProductHistory', productId);
            const history = JSON.parse(result.toString());
            console.log(`✅ Retrieved ${history.length} history records for product ${productId}`);
            return history;
        } catch (error) {
            console.error(`❌ Failed to get product history for ${productId}:`, error);
            throw error;
        }
    }

    /**
     * Emit a product alert
     */
    async emitProductAlert(productId, alertType, message) {
        try {
            console.log(`🔄 Emitting alert for product: ${productId}`);
            const result = await this.contract.submitTransaction(
                'EmitProductAlert',
                productId,
                alertType,
                message
            );
            console.log(`✅ Alert emitted for product ${productId}`);
            return result;
        } catch (error) {
            console.error(`❌ Failed to emit alert for product ${productId}:`, error);
            throw error;
        }
    }

    /**
     * Create private product data
     */
    async createPrivateProductData(collection, privateData) {
        try {
            console.log(`🔄 Creating private data for product: ${privateData.productId}`);
            
            // Create transient data map
            const transientData = {
                product_private_data: Buffer.from(JSON.stringify(privateData))
            };

            const result = await this.contract.createTransaction('CreatePrivateProductData')
                .setTransient(transientData)
                .submit(collection);

            console.log(`✅ Private data created for product ${privateData.productId}`);
            return result;
        } catch (error) {
            console.error(`❌ Failed to create private data:`, error);
            throw error;
        }
    }

    /**
     * Read private product data
     */
    async readPrivateProductData(collection, productId) {
        try {
            console.log(`🔄 Reading private data for product: ${productId}`);
            const result = await this.contract.evaluateTransaction('ReadPrivateProductData', collection, productId);
            const privateData = JSON.parse(result.toString());
            console.log(`✅ Private data retrieved for product ${productId}`);
            return privateData;
        } catch (error) {
            console.error(`❌ Failed to read private data for product ${productId}:`, error);
            throw error;
        }
    }

    /**
     * Disconnect from the gateway
     */
    async disconnect() {
        if (this.gateway) {
            await this.gateway.disconnect();
            console.log('✅ Disconnected from Fabric Gateway');
        }
    }
}

// Example usage and testing
async function main() {
    const client = new SupplyChainGatewayClient();

    try {
        // Initialize client
        await client.initialize('manufacturer', 'appUser');

        // Initialize ledger
        await client.initLedger();

        // Create a new product
        await client.createProduct(
            'PROD003',
            'Smart Sensor',
            'IoT sensor for supply chain monitoring',
            'MANUFACTURER001',
            'BATCH003'
        );

        // Read the product
        const product = await client.readProduct('PROD003');
        console.log('📦 Product details:', JSON.stringify(product, null, 2));

        // Update the product
        await client.updateProduct('PROD003', 'shipped', 'Warehouse A', 25.0, 50.0);

        // Add tracking event
        await client.addTrackingEvent('PROD003', 'quality_check', 'QC Lab', {
            inspector: 'John Doe',
            result: 'passed',
            notes: 'All tests passed successfully'
        });

        // Get all products
        const allProducts = await client.getAllProducts();
        console.log(`📦 Total products: ${allProducts.length}`);

        // Query products by status
        const shippedProducts = await client.queryProductsByStatus('shipped');
        console.log(`📦 Shipped products: ${shippedProducts.length}`);

        // Get product history
        const history = await client.getProductHistory('PROD003');
        console.log(`📜 Product history entries: ${history.length}`);

        // Create private data (example)
        const privateData = {
            productId: 'PROD003',
            costPrice: 150.00,
            supplierId: 'SUPPLIER001',
            manufacturingDetails: 'Confidential manufacturing process',
            qualityIssues: []
        };

        await client.createPrivateProductData('manufacturerPrivateCollection', privateData);

        // Emit an alert
        await client.emitProductAlert('PROD003', 'temperature_warning', 'Temperature exceeded threshold');

        console.log('🎉 All operations completed successfully!');

    } catch (error) {
        console.error('💥 Application error:', error);
        process.exit(1);
    } finally {
        // Disconnect
        await client.disconnect();
    }
}

// Export the class for use in other modules
module.exports = SupplyChainGatewayClient;

// Run the example if this file is executed directly
if (require.main === module) {
    main().catch(console.error);
} 