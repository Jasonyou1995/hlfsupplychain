/**
 * Progress Tracking Utility Module
 * 
 * Provides visual progress bars and step tracking for deployment operations
 */

import cliProgress from 'cli-progress';
import chalk from 'chalk';

export class ProgressTracker {
  constructor() {
    this.bars = new Map();
    this.currentStep = 0;
    this.totalSteps = 0;
  }

  /**
   * Initialize progress tracking with total steps
   */
  init(totalSteps, title = 'Deployment Progress') {
    this.totalSteps = totalSteps;
    this.currentStep = 0;
    
    console.log(chalk.cyan.bold(`\n🚀 ${title}`));
    console.log(chalk.gray(`Total steps: ${totalSteps}\n`));
  }

  /**
   * Create a new progress bar
   */
  createBar(name, total, format) {
    const defaultFormat = `${name} |${chalk.cyan('{bar}')}| {percentage}% | {value}/{total} | ETA: {eta}s`;
    
    const bar = new cliProgress.SingleBar({
      format: format || defaultFormat,
      barCompleteChar: '█',
      barIncompleteChar: '░',
      hideCursor: true,
      barsize: 30
    }, cliProgress.Presets.shades_classic);

    bar.start(total, 0);
    this.bars.set(name, bar);
    return bar;
  }

  /**
   * Update progress bar
   */
  updateBar(name, value, payload = {}) {
    const bar = this.bars.get(name);
    if (bar) {
      bar.update(value, payload);
    }
  }

  /**
   * Complete and stop a progress bar
   */
  completeBar(name) {
    const bar = this.bars.get(name);
    if (bar) {
      bar.stop();
      this.bars.delete(name);
    }
  }

  /**
   * Complete all progress bars
   */
  completeAll() {
    this.bars.forEach((bar, name) => {
      bar.stop();
    });
    this.bars.clear();
  }

  /**
   * Step through the main deployment process
   */
  nextStep(description) {
    this.currentStep++;
    const stepIndicator = chalk.cyan(`[${this.currentStep}/${this.totalSteps}]`);
    const status = this.currentStep <= this.totalSteps ? '🔄' : '✅';
    
    console.log(`\n${status} ${stepIndicator} ${description}`);
    
    // Show overall progress
    if (this.totalSteps > 0) {
      const percentage = Math.round((this.currentStep / this.totalSteps) * 100);
      const progressBar = this.createProgressBar(percentage, 20);
      console.log(`   ${progressBar} ${percentage}%`);
    }
  }

  /**
   * Create a simple text-based progress bar
   */
  createProgressBar(percentage, width = 20) {
    const filled = Math.round((percentage / 100) * width);
    const empty = width - filled;
    
    const filledBar = chalk.green('█'.repeat(filled));
    const emptyBar = chalk.gray('░'.repeat(empty));
    
    return `[${filledBar}${emptyBar}]`;
  }

  /**
   * Show deployment phase
   */
  phase(title, description) {
    console.log(chalk.magenta.bold(`\n🔧 ${title}`));
    if (description) {
      console.log(chalk.gray(`   ${description}`));
    }
  }

  /**
   * Show validation step
   */
  validation(check, status, details = '') {
    const icon = status ? '✅' : '❌';
    const color = status ? chalk.green : chalk.red;
    
    console.log(`   ${icon} ${color(check)} ${details ? chalk.gray(details) : ''}`);
  }

  /**
   * Show service status
   */
  service(name, status, port = null) {
    const statusIcon = {
      'starting': '🔄',
      'running': '✅',
      'stopped': '⏹️',
      'error': '❌'
    };
    
    const statusColor = {
      'starting': chalk.yellow,
      'running': chalk.green,
      'stopped': chalk.gray,
      'error': chalk.red
    };
    
    const icon = statusIcon[status] || '❓';
    const color = statusColor[status] || chalk.white;
    const portInfo = port ? chalk.gray(`:${port}`) : '';
    
    console.log(`   ${icon} ${color(name)}${portInfo} - ${color(status)}`);
  }

  /**
   * Show timer for long operations
   */
  timer(operation, startTime) {
    const elapsed = Date.now() - startTime;
    const seconds = Math.round(elapsed / 1000);
    const timeStr = seconds > 60 ? 
      `${Math.floor(seconds / 60)}m ${seconds % 60}s` : 
      `${seconds}s`;
    
    console.log(`   ⏱️  ${operation}: ${chalk.cyan(timeStr)}`);
  }

  /**
   * Show resource usage
   */
  resources(cpu, memory, disk) {
    console.log(chalk.gray('\n📊 Resource Usage:'));
    if (cpu !== undefined) console.log(`   CPU: ${this.formatPercentage(cpu)}`);
    if (memory !== undefined) console.log(`   Memory: ${this.formatBytes(memory)}`);
    if (disk !== undefined) console.log(`   Disk: ${this.formatBytes(disk)}`);
  }

  /**
   * Format percentage with color coding
   */
  formatPercentage(percentage) {
    const color = percentage > 80 ? chalk.red : 
                  percentage > 60 ? chalk.yellow : 
                  chalk.green;
    return color(`${percentage}%`);
  }

  /**
   * Format bytes to human readable
   */
  formatBytes(bytes) {
    const sizes = ['B', 'KB', 'MB', 'GB'];
    if (bytes === 0) return '0 B';
    
    const i = Math.floor(Math.log(bytes) / Math.log(1024));
    const value = (bytes / Math.pow(1024, i)).toFixed(1);
    
    return chalk.cyan(`${value} ${sizes[i]}`);
  }

  /**
   * Show completion summary
   */
  complete(summary) {
    this.completeAll();
    
    console.log(chalk.green.bold('\n🎉 Deployment Complete!\n'));
    
    if (summary) {
      Object.entries(summary).forEach(([key, value]) => {
        console.log(`   ${chalk.cyan(key)}: ${chalk.white(value)}`);
      });
    }
    
    console.log('');
  }

  /**
   * Show error summary
   */
  error(error, suggestions = []) {
    this.completeAll();
    
    console.log(chalk.red.bold('\n❌ Deployment Failed!\n'));
    console.log(chalk.red(`   Error: ${error.message}`));
    
    if (suggestions.length > 0) {
      console.log(chalk.yellow('\n💡 Suggestions:'));
      suggestions.forEach(suggestion => {
        console.log(chalk.yellow(`   • ${suggestion}`));
      });
    }
    
    console.log('');
  }

  /**
   * Show warning with suggestions
   */
  warning(message, suggestions = []) {
    console.log(chalk.yellow(`\n⚠️  ${message}`));
    
    if (suggestions.length > 0) {
      suggestions.forEach(suggestion => {
        console.log(chalk.yellow(`   • ${suggestion}`));
      });
    }
  }
}

// Export singleton instance
export const progressTracker = new ProgressTracker();
export default progressTracker; 