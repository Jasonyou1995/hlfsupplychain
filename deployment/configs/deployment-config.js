/**
 * Enterprise Supply Chain Platform - Deployment Configuration System
 * 
 * Centralized configuration for all deployment modes and environments.
 * This system allows for easy customization of deployment parameters
 * without modifying core deployment logic.
 */

export const NETWORK_CONFIGS = {
  // Development configuration - minimal setup for local development
  development: {
    metadata: {
      name: 'Development',
      description: 'Lightweight setup for local development and testing',
      estimatedSetupTime: '2-3 minutes',
      resourceRequirements: {
        ram: '4GB',
        storage: '5GB',
        cpu: '2 cores'
      }
    },
    
    network: {
      domain: 'dev.supplychain.local',
      channelName: 'dev-channel',
      tlsEnabled: false,
      monitoring: false,
      persistence: false
    },
    
    organizations: {
      orderer: {
        count: 1,
        resources: { memory: '256MB', cpu: '0.5' }
      },
      peers: {
        manufacturer: { count: 1, ports: { peer: 7051, ca: 7054 } },
        supplier: { count: 1, ports: { peer: 8051, ca: 8054 } }
      }
    },
    
    chaincode: {
      buildTimeout: '2m',
      approvalPolicy: 'OR("ManufacturerMSP.peer","SupplierMSP.peer")',
      initRequired: false
    },
    
    application: {
      apiPort: 3000,
      logLevel: 'debug',
      corsEnabled: true,
      rateLimiting: false,
      jwtSecret: 'dev-secret-key',
      dbType: 'memory'
    }
  },

  // Staging configuration - multi-org testing environment
  staging: {
    metadata: {
      name: 'Staging',
      description: 'Multi-organization environment for integration testing',
      estimatedSetupTime: '5-7 minutes',
      resourceRequirements: {
        ram: '8GB',
        storage: '15GB',
        cpu: '4 cores'
      }
    },
    
    network: {
      domain: 'staging.supplychain.com',
      channelName: 'staging-channel',
      tlsEnabled: true,
      monitoring: true,
      persistence: true
    },
    
    organizations: {
      orderer: {
        count: 2,
        resources: { memory: '512MB', cpu: '1' }
      },
      peers: {
        manufacturer: { count: 2, ports: { peer: 7051, ca: 7054 } },
        supplier: { count: 2, ports: { peer: 8051, ca: 8054 } },
        logistics: { count: 2, ports: { peer: 9051, ca: 9054 } },
        retailer: { count: 2, ports: { peer: 10051, ca: 10054 } }
      }
    },
    
    chaincode: {
      buildTimeout: '5m',
      approvalPolicy: 'AND("ManufacturerMSP.peer","SupplierMSP.peer","LogisticsMSP.peer","RetailerMSP.peer")',
      initRequired: true,
      collections: ['manufacturer', 'supplier', 'logistics', 'retailer']
    },
    
    application: {
      apiPort: 3000,
      logLevel: 'info',
      corsEnabled: true,
      rateLimiting: true,
      jwtSecret: null, // Generated dynamically
      dbType: 'couchdb',
      backupEnabled: false,
      healthCheckInterval: '30s'
    },
    
    monitoring: {
      prometheus: { enabled: true, port: 9090 },
      grafana: { enabled: true, port: 3001 },
      logs: { level: 'info', retention: '7d' }
    }
  },

  // Production configuration - enterprise-grade deployment
  production: {
    metadata: {
      name: 'Production',
      description: 'Enterprise deployment with all organizations and security features',
      estimatedSetupTime: '10-15 minutes',
      resourceRequirements: {
        ram: '16GB',
        storage: '50GB',
        cpu: '8 cores'
      }
    },
    
    network: {
      domain: 'supplychain.com',
      channelName: 'supplychain-main',
      tlsEnabled: true,
      monitoring: true,
      persistence: true,
      highAvailability: true
    },
    
    organizations: {
      orderer: {
        count: 3, // Raft consensus requires odd number
        resources: { memory: '1GB', cpu: '2' },
        placement: ['us-east-1a', 'us-east-1b', 'us-east-1c']
      },
      peers: {
        manufacturer: { count: 2, ports: { peer: 7051, ca: 7054 } },
        supplier: { count: 2, ports: { peer: 8051, ca: 8054 } },
        logistics: { count: 2, ports: { peer: 9051, ca: 9054 } },
        retailer: { count: 2, ports: { peer: 10051, ca: 10054 } },
        auditor: { count: 1, ports: { peer: 11051, ca: 11054 } }
      }
    },
    
    chaincode: {
      buildTimeout: '10m',
      approvalPolicy: 'AND("ManufacturerMSP.peer","SupplierMSP.peer","LogisticsMSP.peer","RetailerMSP.peer","AuditorMSP.peer")',
      initRequired: true,
      collections: ['manufacturer', 'supplier', 'logistics', 'retailer', 'auditor'],
      endorsementPolicy: 'AND("ManufacturerMSP.peer","SupplierMSP.peer")',
      versioningEnabled: true
    },
    
    application: {
      apiPort: 3000,
      logLevel: 'warn',
      corsEnabled: false, // Strict CORS in production
      rateLimiting: true,
      jwtSecret: null, // Must be provided via environment
      dbType: 'couchdb',
      backupEnabled: true,
      backupSchedule: '0 2 * * *', // Daily at 2 AM
      healthCheckInterval: '10s',
      securityHeaders: true,
      encryption: true
    },
    
    monitoring: {
      prometheus: { enabled: true, port: 9090, retention: '30d' },
      grafana: { enabled: true, port: 3001 },
      logs: { level: 'warn', retention: '30d', aggregation: true },
      alerts: {
        enabled: true,
        webhook: process.env.ALERT_WEBHOOK_URL,
        thresholds: {
          cpuUsage: 80,
          memoryUsage: 85,
          diskUsage: 90,
          responseTime: 5000
        }
      }
    },
    
    security: {
      certificateRotation: true,
      rotationInterval: '90d',
      hsm: false, // Hardware Security Module
      auditLogging: true,
      networkPolicies: true,
      firewall: {
        enabled: true,
        allowedPorts: [3000, 7050, 7051, 7054],
        deniedNetworks: ['0.0.0.0/0']
      }
    },
    
    backup: {
      enabled: true,
      schedule: '0 2 * * *',
      retention: '30d',
      encryption: true,
      storage: {
        type: 's3',
        bucket: process.env.BACKUP_S3_BUCKET,
        region: process.env.AWS_REGION
      }
    }
  }
};

// Validation schemas for deployment configurations
export const CONFIG_SCHEMAS = {
  network: {
    required: ['domain', 'channelName', 'tlsEnabled'],
    optional: ['monitoring', 'persistence', 'highAvailability']
  },
  
  organizations: {
    required: ['orderer', 'peers'],
    validation: {
      ordererCountOdd: (config) => config.orderer.count % 2 === 1,
      minPeerCount: (config) => Object.values(config.peers).every(peer => peer.count >= 1)
    }
  },
  
  chaincode: {
    required: ['approvalPolicy'],
    optional: ['buildTimeout', 'initRequired', 'collections', 'endorsementPolicy']
  },
  
  application: {
    required: ['apiPort', 'logLevel'],
    validation: {
      validLogLevel: (config) => ['debug', 'info', 'warn', 'error'].includes(config.logLevel),
      validPort: (config) => config.apiPort >= 1000 && config.apiPort <= 65535
    }
  }
};

// Configuration utilities
export class ConfigValidator {
  static validate(config, schema) {
    const errors = [];
    
    // Check required fields
    if (schema.required) {
      for (const field of schema.required) {
        if (!config[field]) {
          errors.push(`Missing required field: ${field}`);
        }
      }
    }
    
    // Run custom validation functions
    if (schema.validation) {
      for (const [name, validator] of Object.entries(schema.validation)) {
        if (!validator(config)) {
          errors.push(`Validation failed: ${name}`);
        }
      }
    }
    
    return errors;
  }
  
  static validateDeploymentConfig(configName) {
    const config = NETWORK_CONFIGS[configName];
    if (!config) {
      throw new Error(`Unknown configuration: ${configName}`);
    }
    
    const allErrors = [];
    
    // Validate each section
    for (const [section, schema] of Object.entries(CONFIG_SCHEMAS)) {
      if (config[section]) {
        const errors = this.validate(config[section], schema);
        allErrors.push(...errors.map(err => `${section}: ${err}`));
      }
    }
    
    if (allErrors.length > 0) {
      throw new Error(`Configuration validation failed:\n${allErrors.join('\n')}`);
    }
    
    return true;
  }
}

// Configuration merging utilities
export class ConfigMerger {
  static mergeWithDefaults(userConfig, baseConfig) {
    return this.deepMerge(baseConfig, userConfig);
  }
  
  static deepMerge(target, source) {
    const result = { ...target };
    
    for (const key in source) {
      if (source[key] && typeof source[key] === 'object' && !Array.isArray(source[key])) {
        result[key] = this.deepMerge(target[key] || {}, source[key]);
      } else {
        result[key] = source[key];
      }
    }
    
    return result;
  }
  
  static createCustomConfig(baseName, overrides) {
    const baseConfig = NETWORK_CONFIGS[baseName];
    if (!baseConfig) {
      throw new Error(`Base configuration '${baseName}' not found`);
    }
    
    const customConfig = this.mergeWithDefaults(overrides, baseConfig);
    
    // Validate the merged configuration
    ConfigValidator.validateDeploymentConfig(customConfig);
    
    return customConfig;
  }
}

// Environment-specific configuration builders
export class ConfigBuilder {
  static forDockerCompose(config) {
    const services = {};
    
    // Build orderer services
    for (let i = 1; i <= config.organizations.orderer.count; i++) {
      services[`orderer${i}.${config.network.domain}`] = {
        image: 'hyperledger/fabric-orderer:2.5.5',
        environment: this.buildOrdererEnv(config, i),
        ports: [`${7050 + i - 1}:7050`],
        volumes: this.buildOrdererVolumes(config, i),
        networks: ['supplychain-network']
      };
    }
    
    // Build peer services for each organization
    for (const [orgName, orgConfig] of Object.entries(config.organizations.peers)) {
      for (let i = 0; i < orgConfig.count; i++) {
        const peerName = `peer${i}.${orgName}.${config.network.domain}`;
        services[peerName] = {
          image: 'hyperledger/fabric-peer:2.5.5',
          environment: this.buildPeerEnv(config, orgName, i),
          ports: [`${orgConfig.ports.peer + i}:7051`],
          volumes: this.buildPeerVolumes(config, orgName, i),
          networks: ['supplychain-network']
        };
      }
      
      // Add CA service for organization
      services[`ca.${orgName}.${config.network.domain}`] = {
        image: 'hyperledger/fabric-ca:1.5.5',
        environment: this.buildCAEnv(config, orgName),
        ports: [`${orgConfig.ports.ca}:7054`],
        networks: ['supplychain-network']
      };
    }
    
    return {
      version: '3.8',
      services,
      networks: {
        'supplychain-network': {
          driver: 'bridge'
        }
      },
      volumes: this.buildVolumes(config)
    };
  }
  
  static buildOrdererEnv(config, ordererIndex) {
    return {
      FABRIC_LOGGING_SPEC: 'INFO',
      ORDERER_GENERAL_LISTENADDRESS: '0.0.0.0',
      ORDERER_GENERAL_LISTENPORT: '7050',
      ORDERER_GENERAL_LOCALMSPID: 'OrdererMSP',
      ORDERER_GENERAL_TLS_ENABLED: config.network.tlsEnabled.toString(),
      // ... additional orderer environment variables
    };
  }
  
  static buildPeerEnv(config, orgName, peerIndex) {
    const orgMSP = orgName.charAt(0).toUpperCase() + orgName.slice(1) + 'MSP';
    return {
      CORE_PEER_ID: `peer${peerIndex}.${orgName}.${config.network.domain}`,
      CORE_PEER_ADDRESS: `peer${peerIndex}.${orgName}.${config.network.domain}:7051`,
      CORE_PEER_LOCALMSPID: orgMSP,
      CORE_PEER_TLS_ENABLED: config.network.tlsEnabled.toString(),
      CORE_LEDGER_STATE_STATEDATABASE: config.application.dbType === 'couchdb' ? 'CouchDB' : 'goleveldb',
      // ... additional peer environment variables
    };
  }
  
  static buildCAEnv(config, orgName) {
    return {
      FABRIC_CA_HOME: '/etc/hyperledger/fabric-ca-server',
      FABRIC_CA_SERVER_CA_NAME: `ca-${orgName}`,
      FABRIC_CA_SERVER_TLS_ENABLED: config.network.tlsEnabled.toString(),
      // ... additional CA environment variables
    };
  }
  
  static buildOrdererVolumes(config, ordererIndex) {
    return [
      `./organizations/ordererOrganizations/${config.network.domain}/orderers/orderer${ordererIndex}.${config.network.domain}/msp:/var/hyperledger/orderer/msp`,
      `./organizations/ordererOrganizations/${config.network.domain}/orderers/orderer${ordererIndex}.${config.network.domain}/tls:/var/hyperledger/orderer/tls`,
      `orderer${ordererIndex}.${config.network.domain}:/var/hyperledger/production/orderer`
    ];
  }
  
  static buildPeerVolumes(config, orgName, peerIndex) {
    return [
      `./organizations/peerOrganizations/${orgName}.${config.network.domain}/peers/peer${peerIndex}.${orgName}.${config.network.domain}/msp:/etc/hyperledger/fabric/msp`,
      `./organizations/peerOrganizations/${orgName}.${config.network.domain}/peers/peer${peerIndex}.${orgName}.${config.network.domain}/tls:/etc/hyperledger/fabric/tls`,
      `peer${peerIndex}.${orgName}.${config.network.domain}:/var/hyperledger/production`
    ];
  }
  
  static buildVolumes(config) {
    const volumes = {};
    
    // Add orderer volumes
    for (let i = 1; i <= config.organizations.orderer.count; i++) {
      volumes[`orderer${i}.${config.network.domain}`] = null;
    }
    
    // Add peer volumes
    for (const [orgName, orgConfig] of Object.entries(config.organizations.peers)) {
      for (let i = 0; i < orgConfig.count; i++) {
        volumes[`peer${i}.${orgName}.${config.network.domain}`] = null;
      }
    }
    
    return volumes;
  }
}

// Export utility functions
export function getConfig(name = 'development') {
  const config = NETWORK_CONFIGS[name];
  if (!config) {
    throw new Error(`Configuration '${name}' not found. Available: ${Object.keys(NETWORK_CONFIGS).join(', ')}`);
  }
  return config;
}

export function listConfigs() {
  return Object.entries(NETWORK_CONFIGS).map(([name, config]) => ({
    name,
    displayName: config.metadata.name,
    description: config.metadata.description,
    estimatedSetupTime: config.metadata.estimatedSetupTime,
    organizations: Object.keys(config.organizations.peers).length,
    resourceRequirements: config.metadata.resourceRequirements
  }));
}

export function validateConfig(configName) {
  return ConfigValidator.validateDeploymentConfig(configName);
} 