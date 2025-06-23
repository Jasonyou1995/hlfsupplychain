/**
 * Configuration Management Module
 * 
 * Handles loading, validation, and management of deployment configurations
 */

import { promises as fs } from 'fs';
import path from 'path';
import yaml from 'js-yaml';

export const DEPLOYMENT_MODES = {
  dev: {
    name: 'Development',
    description: 'Quick setup for local development with minimal organizations',
    orgs: ['manufacturer', 'supplier'],
    peers: 1,
    orderers: 1,
    persistence: false,
    monitoring: false,
    ssl: false,
    estimatedTime: '2-3 minutes'
  },
  staging: {
    name: 'Staging',
    description: 'Multi-org setup for testing with monitoring',
    orgs: ['manufacturer', 'supplier', 'logistics', 'retailer'],
    peers: 2,
    orderers: 2,
    persistence: true,
    monitoring: true,
    ssl: true,
    estimatedTime: '5-7 minutes'
  },
  prod: {
    name: 'Production',
    description: 'Full enterprise deployment with all organizations',
    orgs: ['manufacturer', 'supplier', 'logistics', 'retailer', 'auditor'],
    peers: 2,
    orderers: 3,
    persistence: true,
    monitoring: true,
    ssl: true,
    backup: true,
    estimatedTime: '10-15 minutes'
  }
};

export class ConfigurationManager {
  constructor() {
    this.deploymentConfigPath = path.join(process.cwd(), 'deployment', 'configs', 'deployment-config.js');
  }

  /**
   * Load deployment configuration from external file
   */
  async loadDeploymentConfig() {
    try {
      // Check if deployment config exists
      await fs.access(this.deploymentConfigPath);
      
      // Dynamic import of the configuration
      const configModule = await import(this.deploymentConfigPath);
      return configModule.default || configModule;
    } catch (error) {
      console.warn(`Warning: Could not load deployment config from ${this.deploymentConfigPath}`);
      return null;
    }
  }

  /**
   * Get deployment mode configuration
   */
  getDeploymentMode(mode) {
    if (!DEPLOYMENT_MODES[mode]) {
      throw new Error(`Invalid deployment mode: ${mode}. Available modes: ${Object.keys(DEPLOYMENT_MODES).join(', ')}`);
    }
    return DEPLOYMENT_MODES[mode];
  }

  /**
   * Validate deployment configuration
   */
  validateConfig(config) {
    const required = ['orgs', 'peers', 'orderers'];
    const missing = required.filter(field => !config[field]);
    
    if (missing.length > 0) {
      throw new Error(`Missing required configuration fields: ${missing.join(', ')}`);
    }

    // Validate organization count
    if (!Array.isArray(config.orgs) || config.orgs.length === 0) {
      throw new Error('At least one organization must be specified');
    }

    // Validate peer count
    if (typeof config.peers !== 'number' || config.peers < 1) {
      throw new Error('Peer count must be a positive number');
    }

    // Validate orderer count
    if (typeof config.orderers !== 'number' || config.orderers < 1) {
      throw new Error('Orderer count must be a positive number');
    }

    return true;
  }

  /**
   * Generate Docker Compose configuration
   */
  generateDockerComposeConfig(mode) {
    const config = this.getDeploymentMode(mode);
    this.validateConfig(config);

    return {
      version: '3.8',
      services: this.generateServices(config),
      networks: this.generateNetworks(config),
      volumes: this.generateVolumes(config)
    };
  }

  /**
   * Generate services configuration for Docker Compose
   */
  generateServices(config) {
    const services = {};

    // Generate orderer services
    for (let i = 0; i < config.orderers; i++) {
      services[`orderer${i}.example.com`] = {
        image: 'hyperledger/fabric-orderer:2.5',
        environment: [
          'FABRIC_LOGGING_SPEC=INFO',
          'ORDERER_GENERAL_LISTENADDRESS=0.0.0.0',
          'ORDERER_GENERAL_BOOTSTRAPMETHOD=file',
          'ORDERER_GENERAL_BOOTSTRAPFILE=/var/hyperledger/orderer/orderer.genesis.block',
          'ORDERER_GENERAL_LOCALMSPID=OrdererMSP'
        ],
        working_dir: '/opt/gopath/src/github.com/hyperledger/fabric',
        command: 'orderer',
        volumes: [
          './network/channel-artifacts/genesis.block:/var/hyperledger/orderer/orderer.genesis.block',
          './network/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp:/var/hyperledger/orderer/msp'
        ],
        ports: [`${7050 + i}:7050`],
        networks: ['supply-chain-network']
      };
    }

    // Generate peer services for each organization
    config.orgs.forEach((org, orgIndex) => {
      for (let i = 0; i < config.peers; i++) {
        const peerName = `peer${i}.${org}.example.com`;
        services[peerName] = {
          image: 'hyperledger/fabric-peer:2.5',
          environment: [
            'CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock',
            'CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=supply-chain-network',
            'FABRIC_LOGGING_SPEC=INFO',
            `CORE_PEER_ID=${peerName}`,
            `CORE_PEER_ADDRESS=${peerName}:7051`,
            `CORE_PEER_LOCALMSPID=${org}MSP`,
            'CORE_PEER_TLS_ENABLED=true',
            `CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/${org}.example.com/peers/${peerName}/tls/server.crt`,
            `CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/${org}.example.com/peers/${peerName}/tls/server.key`,
            `CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/${org}.example.com/peers/${peerName}/tls/ca.crt`
          ],
          working_dir: '/opt/gopath/src/github.com/hyperledger/fabric/peer',
          command: 'peer node start',
          volumes: [
            '/var/run/:/host/var/run/',
            `./network/crypto-config/peerOrganizations/${org}.example.com/peers/${peerName}/msp:/opt/gopath/src/github.com/hyperledger/fabric/peer/msp`,
            `./network/crypto-config/peerOrganizations/${org}.example.com/peers/${peerName}/tls:/opt/gopath/src/github.com/hyperledger/fabric/peer/tls`,
            `${peerName}:/var/hyperledger/production`
          ],
          ports: [`${7051 + (orgIndex * 1000) + i}:7051`],
          networks: ['supply-chain-network']
        };
      }
    });

    return services;
  }

  /**
   * Generate networks configuration
   */
  generateNetworks(config) {
    return {
      'supply-chain-network': {
        driver: 'bridge'
      }
    };
  }

  /**
   * Generate volumes configuration
   */
  generateVolumes(config) {
    const volumes = {};
    
    config.orgs.forEach(org => {
      for (let i = 0; i < config.peers; i++) {
        volumes[`peer${i}.${org}.example.com`] = {};
      }
    });

    return volumes;
  }

  /**
   * Save configuration to file
   */
  async saveConfig(config, filePath) {
    try {
      const configData = typeof config === 'object' ? 
        JSON.stringify(config, null, 2) : 
        config;
      
      await fs.writeFile(filePath, configData, 'utf8');
      return true;
    } catch (error) {
      throw new Error(`Failed to save configuration: ${error.message}`);
    }
  }
}

export default ConfigurationManager; 