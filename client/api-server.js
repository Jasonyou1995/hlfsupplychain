/**
 * Enterprise Hyperledger Fabric Supply Chain Platform v2.5+
 * Secure REST API Server
 * Author: Supply Chain Platform Team
 * Last Modified: December 23, 2024
 * License: Apache-2.0
 */

import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import { RateLimiterMemory } from 'rate-limiter-flexible';
import { body, param, validationResult } from 'express-validator';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import crypto from 'crypto-js';
import NodeCache from 'node-cache';
import winston from 'winston';
import dotenv from 'dotenv';
import { SupplyChainGatewayClient } from './gateway-client.js';

dotenv.config();

// Enhanced logging configuration
const logger = winston.createLogger({
    level: process.env.LOG_LEVEL || 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json()
    ),
    defaultMeta: { service: 'supply-chain-api' },
    transports: [
        new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
        new winston.transports.File({ filename: 'logs/combined.log' }),
        new winston.transports.Console({
            format: winston.format.simple()
        })
    ]
});

class SecureSupplyChainAPI {
    constructor() {
        this.app = express();
        this.port = process.env.PORT || 3000;
        this.jwtSecret = process.env.JWT_SECRET || crypto.lib.WordArray.random(32).toString();
        this.cache = new NodeCache({ stdTTL: 600 }); // 10 minutes cache
        this.gatewayClient = new SupplyChainGatewayClient();
        
        this.setupSecurity();
        this.setupMiddleware();
        this.setupRateLimiting();
        this.setupRoutes();
        this.setupErrorHandling();
    }

    /**
     * Configure comprehensive security measures
     */
    setupSecurity() {
        // Security headers
        this.app.use(helmet({
            contentSecurityPolicy: {
                directives: {
                    defaultSrc: ["'self'"],
                    styleSrc: ["'self'", "'unsafe-inline'"],
                    scriptSrc: ["'self'"],
                    imgSrc: ["'self'", "data:", "https:"]
                }
            },
            hsts: {
                maxAge: 31536000,
                includeSubDomains: true,
                preload: true
            }
        }));

        // CORS configuration
        this.app.use(cors({
            origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
            credentials: true,
            optionsSuccessStatus: 200
        }));

        // Trust proxy if behind reverse proxy
        this.app.set('trust proxy', 1);
    }

    /**
     * Setup middleware stack
     */
    setupMiddleware() {
        this.app.use(express.json({ limit: '10mb' }));
        this.app.use(express.urlencoded({ extended: true, limit: '10mb' }));
        
        // Enhanced request logging
        this.app.use(morgan('combined', {
            stream: { write: message => logger.info(message.trim()) }
        }));

        // Request ID middleware
        this.app.use((req, res, next) => {
            req.id = crypto.lib.WordArray.random(16).toString();
            res.setHeader('X-Request-ID', req.id);
            next();
        });
    }

    /**
     * Configure advanced rate limiting
     */
    setupRateLimiting() {
        // Global rate limiter
        const globalLimiter = rateLimit({
            windowMs: 15 * 60 * 1000, // 15 minutes
            max: 1000, // Limit each IP to 1000 requests per windowMs
            message: 'Too many requests from this IP, please try again later.',
            standardHeaders: true,
            legacyHeaders: false
        });

        // API rate limiter
        const apiLimiter = new RateLimiterMemory({
            keyGenerator: (req) => req.ip,
            points: 100, // Number of requests
            duration: 60, // Per 60 seconds
        });

        // Blockchain operation limiter (more restrictive)
        const blockchainLimiter = new RateLimiterMemory({
            keyGenerator: (req) => req.ip,
            points: 10, // Number of blockchain operations
            duration: 60, // Per 60 seconds
        });

        this.app.use(globalLimiter);
        
        this.app.use('/api/', async (req, res, next) => {
            try {
                await apiLimiter.consume(req.ip);
                next();
            } catch (rejRes) {
                res.status(429).json({
                    error: 'Rate limit exceeded',
                    retryAfter: Math.round(rejRes.msBeforeNext / 1000) || 1,
                });
            }
        });

        this.app.use('/api/blockchain/', async (req, res, next) => {
            try {
                await blockchainLimiter.consume(req.ip);
                next();
            } catch (rejRes) {
                res.status(429).json({
                    error: 'Blockchain operation rate limit exceeded',
                    retryAfter: Math.round(rejRes.msBeforeNext / 1000) || 1,
                });
            }
        });
    }

    /**
     * JWT Authentication middleware
     */
    authenticateToken(req, res, next) {
        const authHeader = req.headers['authorization'];
        const token = authHeader && authHeader.split(' ')[1];

        if (!token) {
            return res.status(401).json({ error: 'Access token required' });
        }

        jwt.verify(token, this.jwtSecret, (err, user) => {
            if (err) {
                logger.warn(`Authentication failed for IP ${req.ip}: ${err.message}`);
                return res.status(403).json({ error: 'Invalid or expired token' });
            }
            req.user = user;
            next();
        });
    }

    /**
     * Input validation middleware
     */
    validateInput(validations) {
        return async (req, res, next) => {
            await Promise.all(validations.map(validation => validation.run(req)));

            const errors = validationResult(req);
            if (!errors.isEmpty()) {
                return res.status(400).json({
                    error: 'Validation failed',
                    details: errors.array()
                });
            }
            next();
        };
    }

    /**
     * Setup API routes with comprehensive validation
     */
    setupRoutes() {
        // Health check endpoint
        this.app.get('/health', (req, res) => {
            res.json({
                status: 'healthy',
                timestamp: new Date().toISOString(),
                version: '1.0.0'
            });
        });

        // Authentication endpoint
        this.app.post('/api/auth/login', 
            this.validateInput([
                body('username').isLength({ min: 3 }).trim().escape(),
                body('password').isLength({ min: 6 })
            ]),
            async (req, res) => {
                try {
                    const { username, password } = req.body;
                    
                    // In production, validate against your user store
                    const validCredentials = await this.validateCredentials(username, password);
                    
                    if (!validCredentials) {
                        logger.warn(`Failed login attempt for user ${username} from IP ${req.ip}`);
                        return res.status(401).json({ error: 'Invalid credentials' });
                    }

                    const token = jwt.sign(
                        { username, organization: validCredentials.organization },
                        this.jwtSecret,
                        { expiresIn: '24h' }
                    );

                    logger.info(`Successful login for user ${username} from IP ${req.ip}`);
                    res.json({ token, expiresIn: '24h' });
                } catch (error) {
                    logger.error('Login error:', error);
                    res.status(500).json({ error: 'Authentication service unavailable' });
                }
            }
        );

        // Initialize Gateway
        this.app.post('/api/gateway/init',
            this.authenticateToken.bind(this),
            this.validateInput([
                body('organization').isIn(['manufacturer', 'supplier', 'logistics', 'retailer', 'auditor'])
            ]),
            async (req, res) => {
                try {
                    const { organization } = req.body;
                    await this.gatewayClient.initialize(organization, req.user.username);
                    
                    logger.info(`Gateway initialized for ${organization} by ${req.user.username}`);
                    res.json({ message: 'Gateway initialized successfully', organization });
                } catch (error) {
                    logger.error('Gateway initialization error:', error);
                    res.status(500).json({ error: 'Failed to initialize gateway' });
                }
            }
        );

        // Product management endpoints with caching
        this.app.post('/api/blockchain/products',
            this.authenticateToken.bind(this),
            this.validateInput([
                body('id').isAlphanumeric().isLength({ min: 1, max: 50 }),
                body('name').isLength({ min: 1, max: 100 }).trim().escape(),
                body('description').isLength({ max: 500 }).trim().escape(),
                body('manufacturerId').isAlphanumeric().isLength({ min: 1, max: 50 }),
                body('batchId').optional().isAlphanumeric().isLength({ max: 50 })
            ]),
            async (req, res) => {
                try {
                    const { id, name, description, manufacturerId, batchId } = req.body;
                    
                    const result = await this.gatewayClient.createProduct(
                        id, name, description, manufacturerId, batchId || ''
                    );

                    // Invalidate cache
                    this.cache.del(`product_${id}`);
                    this.cache.del('all_products');

                    logger.info(`Product ${id} created by ${req.user.username}`);
                    res.status(201).json({ message: 'Product created successfully', result });
                } catch (error) {
                    logger.error('Product creation error:', error);
                    res.status(500).json({ error: 'Failed to create product' });
                }
            }
        );

        this.app.get('/api/blockchain/products/:id',
            this.authenticateToken.bind(this),
            this.validateInput([
                param('id').isAlphanumeric().isLength({ min: 1, max: 50 })
            ]),
            async (req, res) => {
                try {
                    const { id } = req.params;
                    const cacheKey = `product_${id}`;
                    
                    // Check cache first
                    let product = this.cache.get(cacheKey);
                    if (!product) {
                        product = await this.gatewayClient.readProduct(id);
                        this.cache.set(cacheKey, product);
                    }

                    res.json(product);
                } catch (error) {
                    logger.error('Product retrieval error:', error);
                    if (error.message.includes('does not exist')) {
                        res.status(404).json({ error: 'Product not found' });
                    } else {
                        res.status(500).json({ error: 'Failed to retrieve product' });
                    }
                }
            }
        );

        this.app.get('/api/blockchain/products',
            this.authenticateToken.bind(this),
            async (req, res) => {
                try {
                    const cacheKey = 'all_products';
                    
                    // Check cache first
                    let products = this.cache.get(cacheKey);
                    if (!products) {
                        products = await this.gatewayClient.getAllProducts();
                        this.cache.set(cacheKey, products);
                    }

                    res.json(products);
                } catch (error) {
                    logger.error('Products retrieval error:', error);
                    res.status(500).json({ error: 'Failed to retrieve products' });
                }
            }
        );

        // Additional endpoints for tracking, history, etc.
        this.app.post('/api/blockchain/products/:id/tracking',
            this.authenticateToken.bind(this),
            this.validateInput([
                param('id').isAlphanumeric().isLength({ min: 1, max: 50 }),
                body('eventType').isIn(['manufactured', 'shipped', 'received', 'quality_check', 'delivered']),
                body('location').isLength({ min: 1, max: 100 }).trim().escape(),
                body('data').optional().isObject()
            ]),
            async (req, res) => {
                try {
                    const { id } = req.params;
                    const { eventType, location, data } = req.body;
                    
                    const result = await this.gatewayClient.addTrackingEvent(
                        id, eventType, location, JSON.stringify(data || {})
                    );

                    // Invalidate cache
                    this.cache.del(`product_${id}`);

                    logger.info(`Tracking event added to product ${id} by ${req.user.username}`);
                    res.json({ message: 'Tracking event added successfully', result });
                } catch (error) {
                    logger.error('Tracking event error:', error);
                    res.status(500).json({ error: 'Failed to add tracking event' });
                }
            }
        );
    }

    /**
     * Validate user credentials (implement with your user store)
     */
    async validateCredentials(username, password) {
        // This is a simplified example - implement with your actual user store
        const users = {
            'manufacturer_admin': {
                password: await bcrypt.hash('secure_password_123', 10),
                organization: 'manufacturer'
            },
            'supplier_admin': {
                password: await bcrypt.hash('secure_password_456', 10),
                organization: 'supplier'
            }
        };

        const user = users[username];
        if (user && await bcrypt.compare(password, user.password)) {
            return { organization: user.organization };
        }
        return null;
    }

    /**
     * Setup error handling middleware
     */
    setupErrorHandling() {
        // 404 handler
        this.app.use((req, res) => {
            res.status(404).json({ error: 'Endpoint not found' });
        });

        // Global error handler
        this.app.use((err, req, res, next) => {
            logger.error('Unhandled error:', err);
            
            if (res.headersSent) {
                return next(err);
            }

            res.status(500).json({
                error: 'Internal server error',
                requestId: req.id
            });
        });
    }

    /**
     * Start the secure API server
     */
    async start() {
        try {
            // Ensure logs directory exists
            const fs = await import('fs');
            if (!fs.existsSync('logs')) {
                fs.mkdirSync('logs');
            }

            this.app.listen(this.port, () => {
                logger.info(`🚀 Secure Supply Chain API Server running on port ${this.port}`);
                logger.info(`📊 Health check available at http://localhost:${this.port}/health`);
                logger.info(`🔒 Security features: Rate limiting, JWT auth, input validation, CORS, Helmet`);
            });
        } catch (error) {
            logger.error('Failed to start server:', error);
            process.exit(1);
        }
    }

    /**
     * Graceful shutdown
     */
    async shutdown() {
        logger.info('Shutting down server...');
        await this.gatewayClient.disconnect();
        process.exit(0);
    }
}

// Start the server
const server = new SecureSupplyChainAPI();
server.start();

// Graceful shutdown handlers
process.on('SIGTERM', () => server.shutdown());
process.on('SIGINT', () => server.shutdown());

export { SecureSupplyChainAPI }; 