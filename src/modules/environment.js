/**
 * Environment Validation Module
 * 
 * Validates system prerequisites and environment setup before deployment
 */

import { exec } from 'child_process';
import { promises as fs } from 'fs';
import { promisify } from 'util';
import path from 'path';
import os from 'os';

const execAsync = promisify(exec);

export class EnvironmentValidator {
  constructor() {
    this.requirements = {
      docker: { min: '20.10.0', cmd: 'docker --version' },
      dockerCompose: { min: '2.0.0', cmd: 'docker-compose --version' },
      node: { min: '16.0.0', cmd: 'node --version' },
      npm: { min: '7.0.0', cmd: 'npm --version' },
      git: { min: '2.20.0', cmd: 'git --version' }
    };
    
    this.systemRequirements = {
      minMemory: 4 * 1024 * 1024 * 1024, // 4GB
      minDisk: 10 * 1024 * 1024 * 1024,  // 10GB
      requiredPorts: [7050, 7051, 7052, 7053, 9443, 5984]
    };
  }

  /**
   * Validate all environment prerequisites
   */
  async validateAll() {
    const results = {
      tools: {},
      system: {},
      network: {},
      permissions: {},
      overall: true
    };

    try {
      // Check required tools
      results.tools = await this.checkRequiredTools();
      
      // Check system resources
      results.system = await this.checkSystemResources();
      
      // Check network/ports
      results.network = await this.checkNetworkRequirements();
      
      // Check file permissions
      results.permissions = await this.checkPermissions();
      
      // Determine overall status
      results.overall = this.isEnvironmentReady(results);
      
    } catch (error) {
      results.error = error.message;
      results.overall = false;
    }

    return results;
  }

  /**
   * Check if required tools are installed and meet version requirements
   */
  async checkRequiredTools() {
    const results = {};
    
    for (const [tool, requirement] of Object.entries(this.requirements)) {
      try {
        const { stdout } = await execAsync(requirement.cmd);
        const version = this.extractVersion(stdout);
        const meetsRequirement = this.compareVersions(version, requirement.min) >= 0;
        
        results[tool] = {
          installed: true,
          version,
          required: requirement.min,
          meets: meetsRequirement,
          status: meetsRequirement ? 'ok' : 'outdated'
        };
      } catch (error) {
        results[tool] = {
          installed: false,
          error: error.message,
          required: requirement.min,
          meets: false,
          status: 'missing'
        };
      }
    }
    
    return results;
  }

  /**
   * Check system resources (memory, disk, CPU)
   */
  async checkSystemResources() {
    const results = {};
    
    try {
      // Memory check
      const totalMemory = os.totalmem();
      const freeMemory = os.freemem();
      results.memory = {
        total: totalMemory,
        free: freeMemory,
        required: this.systemRequirements.minMemory,
        meets: totalMemory >= this.systemRequirements.minMemory,
        status: totalMemory >= this.systemRequirements.minMemory ? 'ok' : 'insufficient'
      };

      // Disk space check
      const diskSpace = await this.checkDiskSpace();
      results.disk = {
        available: diskSpace,
        required: this.systemRequirements.minDisk,
        meets: diskSpace >= this.systemRequirements.minDisk,
        status: diskSpace >= this.systemRequirements.minDisk ? 'ok' : 'insufficient'
      };

      // CPU info
      const cpus = os.cpus();
      results.cpu = {
        cores: cpus.length,
        model: cpus[0]?.model || 'Unknown',
        meets: cpus.length >= 2,
        status: cpus.length >= 2 ? 'ok' : 'insufficient'
      };

      // Platform check
      results.platform = {
        type: os.platform(),
        arch: os.arch(),
        supported: ['linux', 'darwin', 'win32'].includes(os.platform()),
        status: ['linux', 'darwin', 'win32'].includes(os.platform()) ? 'ok' : 'unsupported'
      };

    } catch (error) {
      results.error = error.message;
    }
    
    return results;
  }

  /**
   * Check network requirements and port availability
   */
  async checkNetworkRequirements() {
    const results = {
      ports: {},
      docker: {}
    };

    // Check port availability
    for (const port of this.systemRequirements.requiredPorts) {
      try {
        const isAvailable = await this.isPortAvailable(port);
        results.ports[port] = {
          available: isAvailable,
          status: isAvailable ? 'ok' : 'occupied'
        };
      } catch (error) {
        results.ports[port] = {
          available: false,
          error: error.message,
          status: 'error'
        };
      }
    }

    // Check Docker daemon
    try {
      await execAsync('docker info');
      results.docker = {
        running: true,
        status: 'ok'
      };
    } catch (error) {
      results.docker = {
        running: false,
        error: error.message,
        status: 'not-running'
      };
    }

    return results;
  }

  /**
   * Check file system permissions
   */
  async checkPermissions() {
    const results = {};
    const currentDir = process.cwd();

    try {
      // Check write permissions in current directory
      const testFile = path.join(currentDir, '.permission-test');
      await fs.writeFile(testFile, 'test');
      await fs.unlink(testFile);
      
      results.currentDir = {
        writable: true,
        status: 'ok'
      };
    } catch (error) {
      results.currentDir = {
        writable: false,
        error: error.message,
        status: 'no-write'
      };
    }

    // Check Docker socket permissions (Unix only)
    if (os.platform() !== 'win32') {
      try {
        await fs.access('/var/run/docker.sock', fs.constants.R_OK | fs.constants.W_OK);
        results.dockerSocket = {
          accessible: true,
          status: 'ok'
        };
      } catch (error) {
        results.dockerSocket = {
          accessible: false,
          error: 'Docker socket not accessible. You may need to add your user to the docker group.',
          status: 'no-access'
        };
      }
    }

    return results;
  }

  /**
   * Extract version number from command output
   */
  extractVersion(output) {
    const versionMatch = output.match(/(\d+\.\d+\.\d+)/);
    return versionMatch ? versionMatch[1] : '0.0.0';
  }

  /**
   * Compare two version strings
   */
  compareVersions(version1, version2) {
    const v1parts = version1.split('.').map(Number);
    const v2parts = version2.split('.').map(Number);
    
    for (let i = 0; i < Math.max(v1parts.length, v2parts.length); i++) {
      const v1part = v1parts[i] || 0;
      const v2part = v2parts[i] || 0;
      
      if (v1part > v2part) return 1;
      if (v1part < v2part) return -1;
    }
    
    return 0;
  }

  /**
   * Check if a port is available
   */
  async isPortAvailable(port) {
    return new Promise((resolve) => {
      const { createServer } = require('net');
      const server = createServer();
      
      server.listen(port, () => {
        server.once('close', () => resolve(true));
        server.close();
      });
      
      server.on('error', () => resolve(false));
    });
  }

  /**
   * Check available disk space
   */
  async checkDiskSpace() {
    try {
      const stats = await fs.statfs(process.cwd());
      return stats.bavail * stats.bsize;
    } catch (error) {
      // Fallback for systems that don't support statfs
      return 50 * 1024 * 1024 * 1024; // Assume 50GB available
    }
  }

  /**
   * Determine if environment is ready for deployment
   */
  isEnvironmentReady(results) {
    // Check tools
    const toolsReady = Object.values(results.tools).every(tool => tool.meets);
    
    // Check system resources
    const systemReady = Object.values(results.system)
      .filter(check => typeof check === 'object' && check.meets !== undefined)
      .every(check => check.meets);
    
    // Check Docker
    const dockerReady = results.network.docker?.running === true;
    
    // Check critical ports (at least 70% should be available)
    const portChecks = Object.values(results.network.ports);
    const availablePorts = portChecks.filter(port => port.available).length;
    const portsReady = availablePorts / portChecks.length >= 0.7;
    
    // Check permissions
    const permissionsReady = results.permissions.currentDir?.writable === true;
    
    return toolsReady && systemReady && dockerReady && portsReady && permissionsReady;
  }

  /**
   * Get environment setup instructions
   */
  getSetupInstructions(results) {
    const instructions = [];
    
    // Tool installation instructions
    Object.entries(results.tools).forEach(([tool, check]) => {
      if (!check.meets) {
        instructions.push(this.getToolInstallInstruction(tool, check));
      }
    });
    
    // System resource warnings
    Object.entries(results.system).forEach(([resource, check]) => {
      if (check.meets === false) {
        instructions.push(this.getResourceInstruction(resource, check));
      }
    });
    
    // Network instructions
    if (!results.network.docker?.running) {
      instructions.push('Start Docker daemon: sudo systemctl start docker');
    }
    
    // Port conflict resolutions
    Object.entries(results.network.ports).forEach(([port, check]) => {
      if (!check.available) {
        instructions.push(`Port ${port} is occupied. Stop the service using this port or use different ports.`);
      }
    });
    
    return instructions;
  }

  /**
   * Get tool-specific installation instruction
   */
  getToolInstallInstruction(tool, check) {
    const instructions = {
      docker: 'Install Docker: https://docs.docker.com/get-docker/',
      dockerCompose: 'Install Docker Compose: https://docs.docker.com/compose/install/',
      node: 'Install Node.js: https://nodejs.org/en/download/',
      npm: 'Update npm: npm install -g npm@latest',
      git: 'Install Git: https://git-scm.com/downloads'
    };
    
    if (!check.installed) {
      return instructions[tool] || `Install ${tool}`;
    } else {
      return `Update ${tool} from ${check.version} to ${check.required} or higher`;
    }
  }

  /**
   * Get resource-specific instruction
   */
  getResourceInstruction(resource, check) {
    const instructions = {
      memory: `Insufficient memory: ${this.formatBytes(check.total)} available, ${this.formatBytes(check.required)} required`,
      disk: `Insufficient disk space: ${this.formatBytes(check.available)} available, ${this.formatBytes(check.required)} required`,
      cpu: `Insufficient CPU cores: ${check.cores} available, 2+ required`
    };
    
    return instructions[resource] || `${resource} does not meet requirements`;
  }

  /**
   * Format bytes to human-readable string
   */
  formatBytes(bytes) {
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    if (bytes === 0) return '0 B';
    
    const i = Math.floor(Math.log(bytes) / Math.log(1024));
    return `${(bytes / Math.pow(1024, i)).toFixed(1)} ${sizes[i]}`;
  }
}

export default EnvironmentValidator; 