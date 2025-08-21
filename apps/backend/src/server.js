const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const morgan = require("morgan");
const { Pool } = require("pg");
const promClient = require("prom-client");
const winston = require("winston");
require("dotenv").config();

// Initialize Express app
const app = express();
const PORT = process.env.PORT || 3001;

// Configure Winston logger
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || "info",
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      ),
    }),
  ],
});

// Prometheus metrics
const register = promClient.register;
const collectDefaultMetrics = promClient.collectDefaultMetrics;

// Collect default metrics
collectDefaultMetrics({ register });

// Custom metrics
const httpRequestDuration = new promClient.Histogram({
  name: "http_request_duration_seconds",
  help: "Duration of HTTP requests in seconds",
  labelNames: ["method", "route", "status_code"],
  buckets: [0.1, 0.3, 0.5, 0.7, 1, 3, 5, 7, 10],
});

const httpRequestsTotal = new promClient.Counter({
  name: "http_requests_total",
  help: "Total number of HTTP requests",
  labelNames: ["method", "route", "status_code"],
});

const databaseConnectionsActive = new promClient.Gauge({
  name: "database_connections_active",
  help: "Number of active database connections",
});

const databaseQueryDuration = new promClient.Histogram({
  name: "database_query_duration_seconds",
  help: "Duration of database queries in seconds",
  labelNames: ["query_type"],
  buckets: [0.01, 0.05, 0.1, 0.3, 0.5, 1, 3, 5],
});

// Register custom metrics
register.registerMetric(httpRequestDuration);
register.registerMetric(httpRequestsTotal);
register.registerMetric(databaseConnectionsActive);
register.registerMetric(databaseQueryDuration);

// Database connection
const pool = new Pool({
  host: process.env.DATABASE_HOST || "postgres-service",
  port: process.env.DATABASE_PORT || 5432,
  database: process.env.DATABASE_NAME || "appdb",
  user: process.env.DATABASE_USER || "postgres",
  password: process.env.DATABASE_PASSWORD || "postgres",
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Test database connection
pool.on("connect", () => {
  logger.info("Connected to PostgreSQL database");
  databaseConnectionsActive.inc();
});

pool.on("remove", () => {
  databaseConnectionsActive.dec();
});

pool.on("error", (err) => {
  logger.error("PostgreSQL pool error:", err);
});

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true }));

// Custom logging middleware
app.use((req, res, next) => {
  const start = Date.now();

  res.on("finish", () => {
    const duration = (Date.now() - start) / 1000;
    const route = req.route ? req.route.path : req.path;

    // Record metrics
    httpRequestDuration
      .labels(req.method, route, res.statusCode.toString())
      .observe(duration);

    httpRequestsTotal
      .labels(req.method, route, res.statusCode.toString())
      .inc();

    // Log request
    logger.info("HTTP Request", {
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      duration: duration,
      userAgent: req.get("User-Agent"),
      ip: req.ip,
    });
  });

  next();
});

// Morgan for additional HTTP logging
app.use(
  morgan("combined", {
    stream: {
      write: (message) => logger.info(message.trim()),
    },
  })
);

// Initialize database schema
async function initializeDatabase() {
  try {
    const client = await pool.connect();

    // Create users table if it doesn't exist
    await client.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        email VARCHAR(100) UNIQUE NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Create sample data if table is empty
    const result = await client.query("SELECT COUNT(*) FROM users");
    if (parseInt(result.rows[0].count) === 0) {
      await client.query(`
        INSERT INTO users (name, email) VALUES 
        ('John Doe', 'john@example.com'),
        ('Jane Smith', 'jane@example.com'),
        ('Bob Johnson', 'bob@example.com')
      `);
      logger.info("Sample data inserted into users table");
    }

    client.release();
    logger.info("Database initialized successfully");
  } catch (error) {
    logger.error("Database initialization failed:", error);
  }
}

// Routes

// Health check endpoint
app.get("/health", async (req, res) => {
  try {
    // Check database connection
    const client = await pool.connect();
    await client.query("SELECT 1");
    client.release();

    res.status(200).json({
      status: "healthy",
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      version: process.env.npm_package_version || "1.0.0",
      database: "connected",
    });
  } catch (error) {
    logger.error("Health check failed:", error);
    res.status(503).json({
      status: "unhealthy",
      timestamp: new Date().toISOString(),
      error: error.message,
      database: "disconnected",
    });
  }
});

// Readiness probe
app.get("/ready", async (req, res) => {
  try {
    const client = await pool.connect();
    await client.query("SELECT 1");
    client.release();
    res.status(200).json({ status: "ready" });
  } catch (error) {
    res.status(503).json({ status: "not ready", error: error.message });
  }
});

// Liveness probe
app.get("/live", (req, res) => {
  res.status(200).json({ status: "alive" });
});

// Metrics endpoint for Prometheus
app.get("/metrics", async (req, res) => {
  try {
    res.set("Content-Type", register.contentType);
    res.end(await register.metrics());
  } catch (error) {
    logger.error("Metrics endpoint error:", error);
    res.status(500).end(error.message);
  }
});

// API Routes

// Get all users
app.get("/api/users", async (req, res) => {
  const start = Date.now();
  try {
    const client = await pool.connect();
    const result = await client.query(
      "SELECT * FROM users ORDER BY created_at DESC"
    );
    client.release();

    const duration = (Date.now() - start) / 1000;
    databaseQueryDuration.labels("select").observe(duration);

    res.json({
      success: true,
      data: result.rows,
      count: result.rows.length,
    });
  } catch (error) {
    logger.error("Get users error:", error);
    res.status(500).json({
      success: false,
      error: "Failed to fetch users",
    });
  }
});

// Get user by ID
app.get("/api/users/:id", async (req, res) => {
  const start = Date.now();
  try {
    const { id } = req.params;
    const client = await pool.connect();
    const result = await client.query("SELECT * FROM users WHERE id = $1", [
      id,
    ]);
    client.release();

    const duration = (Date.now() - start) / 1000;
    databaseQueryDuration.labels("select").observe(duration);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: "User not found",
      });
    }

    res.json({
      success: true,
      data: result.rows[0],
    });
  } catch (error) {
    logger.error("Get user error:", error);
    res.status(500).json({
      success: false,
      error: "Failed to fetch user",
    });
  }
});

// Create new user
app.post("/api/users", async (req, res) => {
  const start = Date.now();
  try {
    const { name, email } = req.body;

    if (!name || !email) {
      return res.status(400).json({
        success: false,
        error: "Name and email are required",
      });
    }

    const client = await pool.connect();
    const result = await client.query(
      "INSERT INTO users (name, email) VALUES ($1, $2) RETURNING *",
      [name, email]
    );
    client.release();

    const duration = (Date.now() - start) / 1000;
    databaseQueryDuration.labels("insert").observe(duration);

    res.status(201).json({
      success: true,
      data: result.rows[0],
    });
  } catch (error) {
    logger.error("Create user error:", error);
    if (error.code === "23505") {
      // Unique violation
      res.status(409).json({
        success: false,
        error: "Email already exists",
      });
    } else {
      res.status(500).json({
        success: false,
        error: "Failed to create user",
      });
    }
  }
});

// Update user
app.put("/api/users/:id", async (req, res) => {
  const start = Date.now();
  try {
    const { id } = req.params;
    const { name, email } = req.body;

    const client = await pool.connect();
    const result = await client.query(
      "UPDATE users SET name = $1, email = $2, updated_at = CURRENT_TIMESTAMP WHERE id = $3 RETURNING *",
      [name, email, id]
    );
    client.release();

    const duration = (Date.now() - start) / 1000;
    databaseQueryDuration.labels("update").observe(duration);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: "User not found",
      });
    }

    res.json({
      success: true,
      data: result.rows[0],
    });
  } catch (error) {
    logger.error("Update user error:", error);
    res.status(500).json({
      success: false,
      error: "Failed to update user",
    });
  }
});

// Delete user
app.delete("/api/users/:id", async (req, res) => {
  const start = Date.now();
  try {
    const { id } = req.params;

    const client = await pool.connect();
    const result = await client.query(
      "DELETE FROM users WHERE id = $1 RETURNING *",
      [id]
    );
    client.release();

    const duration = (Date.now() - start) / 1000;
    databaseQueryDuration.labels("delete").observe(duration);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: "User not found",
      });
    }

    res.json({
      success: true,
      message: "User deleted successfully",
    });
  } catch (error) {
    logger.error("Delete user error:", error);
    res.status(500).json({
      success: false,
      error: "Failed to delete user",
    });
  }
});

// Error handling middleware
app.use((error, req, res, next) => {
  logger.error("Unhandled error:", error);
  res.status(500).json({
    success: false,
    error: "Internal server error",
  });
});

// 404 handler
app.use("*", (req, res) => {
  res.status(404).json({
    success: false,
    error: "Route not found",
  });
});

// Graceful shutdown
process.on("SIGTERM", async () => {
  logger.info("SIGTERM received, shutting down gracefully");
  await pool.end();
  process.exit(0);
});

process.on("SIGINT", async () => {
  logger.info("SIGINT received, shutting down gracefully");
  await pool.end();
  process.exit(0);
});

// Start server
async function startServer() {
  try {
    await initializeDatabase();

    app.listen(PORT, "0.0.0.0", () => {
      logger.info(`Server running on port ${PORT}`);
      logger.info(`Health check: http://localhost:${PORT}/health`);
      logger.info(`Metrics: http://localhost:${PORT}/metrics`);
      logger.info(`API: http://localhost:${PORT}/api/users`);
    });
  } catch (error) {
    logger.error("Failed to start server:", error);
    process.exit(1);
  }
}

startServer();
