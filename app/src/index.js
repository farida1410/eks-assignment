const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Readiness check endpoint
app.get('/ready', (req, res) => {
  res.status(200).json({
    status: 'ready',
    timestamp: new Date().toISOString()
  });
});

// Main endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Hello from EKS Assignment! CI/CD is working!',
    version: '1.1.0',
    environment: process.env.NODE_ENV || 'development',
    hostname: require('os').hostname(),
    timestamp: new Date().toISOString()
  });
});

// API endpoint
app.get('/api/info', (req, res) => {
  res.json({
    application: 'EKS Assignment Application',
    description: 'A production-ready Node.js application deployed on Amazon EKS',
    features: [
      'AWS EKS Deployment',
      'AWS Load Balancer Controller',
      'IRSA (IAM Roles for Service Accounts)',
      'Network Policies',
      'CI/CD with GitHub Actions',
      'Observability with Prometheus & Grafana'
    ],
    platform: {
      node: process.version,
      platform: process.platform,
      architecture: process.arch
    }
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    error: 'Something went wrong!',
    message: err.message
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM signal received: closing HTTP server');
  server.close(() => {
    console.log('HTTP server closed');
  });
});
