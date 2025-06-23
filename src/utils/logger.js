/**
 * Logger Utility Module
 * 
 * Provides structured logging with colors and different log levels
 */

import chalk from 'chalk';
import winston from 'winston';

export class Logger {
  constructor() {
    this.winston = winston.createLogger({
      level: process.env.LOG_LEVEL || 'info',
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.printf(({ timestamp, level, message, stack }) => {
          return `${timestamp} [${level.toUpperCase()}]: ${stack || message}`;
        })
      ),
      transports: [
        new winston.transports.File({ 
          filename: 'deployment.log',
          level: 'debug'
        })
      ]
    });
  }

  /**
   * Log info message with icon
   */
  info(message, icon = 'ℹ️') {
    const formatted = `${icon} ${message}`;
    console.log(chalk.blue(formatted));
    this.winston.info(message);
  }

  /**
   * Log success message with icon
   */
  success(message, icon = '✅') {
    const formatted = `${icon} ${message}`;
    console.log(chalk.green(formatted));
    this.winston.info(message);
  }

  /**
   * Log warning message with icon
   */
  warn(message, icon = '⚠️') {
    const formatted = `${icon} ${message}`;
    console.log(chalk.yellow(formatted));
    this.winston.warn(message);
  }

  /**
   * Log error message with icon
   */
  error(message, icon = '❌') {
    const formatted = `${icon} ${message}`;
    console.log(chalk.red(formatted));
    this.winston.error(message);
  }

  /**
   * Log debug message (only in debug mode)
   */
  debug(message) {
    if (process.env.DEBUG === 'true') {
      console.log(chalk.gray(`🔍 DEBUG: ${message}`));
    }
    this.winston.debug(message);
  }

  /**
   * Log step with numbering
   */
  step(step, total, message) {
    const stepInfo = chalk.cyan(`[${step}/${total}]`);
    const formatted = `${stepInfo} ${message}`;
    console.log(formatted);
    this.winston.info(`Step ${step}/${total}: ${message}`);
  }

  /**
   * Log header with decorative borders
   */
  header(title) {
    const border = '='.repeat(50);
    console.log(chalk.cyan(border));
    console.log(chalk.cyan.bold(`  ${title}`));
    console.log(chalk.cyan(border));
    this.winston.info(`=== ${title} ===`);
  }

  /**
   * Log section with decorative line
   */
  section(title) {
    const line = '-'.repeat(30);
    console.log(chalk.magenta(`\n${line}`));
    console.log(chalk.magenta.bold(title));
    console.log(chalk.magenta(line));
    this.winston.info(`--- ${title} ---`);
  }

  /**
   * Log configuration details
   */
  config(key, value) {
    const formatted = `${chalk.gray('CONFIG')} ${chalk.cyan(key)}: ${chalk.white(value)}`;
    console.log(formatted);
    this.winston.info(`CONFIG ${key}: ${value}`);
  }

  /**
   * Log command execution
   */
  command(cmd) {
    const formatted = `${chalk.gray('$')} ${chalk.yellow(cmd)}`;
    console.log(formatted);
    this.winston.info(`COMMAND: ${cmd}`);
  }

  /**
   * Log time taken for an operation
   */
  timing(operation, startTime) {
    const duration = Date.now() - startTime;
    const timeStr = duration > 1000 ? `${(duration/1000).toFixed(1)}s` : `${duration}ms`;
    const formatted = `⏱️  ${operation} completed in ${chalk.cyan(timeStr)}`;
    console.log(formatted);
    this.winston.info(`${operation} completed in ${timeStr}`);
  }

  /**
   * Log progress update
   */
  progress(message, percentage) {
    if (percentage !== undefined) {
      const formatted = `🔄 ${message} (${percentage}%)`;
      console.log(formatted);
    } else {
      const formatted = `🔄 ${message}`;
      console.log(formatted);
    }
    this.winston.info(message);
  }

  /**
   * Create a new line for spacing
   */
  newLine() {
    console.log('');
  }

  /**
   * Log table data
   */
  table(title, data) {
    this.section(title);
    console.table(data);
    this.winston.info(`TABLE ${title}: ${JSON.stringify(data)}`);
  }

  /**
   * Log deployment summary
   */
  summary(data) {
    this.header('Deployment Summary');
    Object.entries(data).forEach(([key, value]) => {
      this.config(key, value);
    });
    this.newLine();
  }

  /**
   * Start a spinner-like operation
   */
  startOperation(message) {
    this.info(`${message}...`);
    return Date.now();
  }

  /**
   * End a spinner-like operation
   */
  endOperation(message, startTime) {
    this.timing(message, startTime);
  }
}

// Export singleton instance
export const logger = new Logger();
export default logger; 