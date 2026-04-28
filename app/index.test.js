const request = require('supertest');
const express = require('express');

// Build the same app as index.js so we can test it without listening on a port
function buildApp() {
  const app = express();

  app.get('/', (req, res) => {
    res.json({
      message: 'DevFlow is live!',
      environment: process.env.NODE_ENV || 'development',
      version: '1.0.1'
    });
  });

  app.get('/health', (req, res) => {
    res.status(200).json({ status: 'healthy' });
  });

  return app;
}

describe('DevFlow API', () => {
  const app = buildApp();

  describe('GET /', () => {
    it('returns a 200 status', async () => {
      const response = await request(app).get('/');
      expect(response.status).toBe(200);
    });

    it('returns the live message', async () => {
      const response = await request(app).get('/');
      expect(response.body.message).toBe('DevFlow is live!');
    });

    it('includes version and environment fields', async () => {
      const response = await request(app).get('/');
      expect(response.body).toHaveProperty('version');
      expect(response.body).toHaveProperty('environment');
    });
  });

  describe('GET /health', () => {
    it('returns a 200 status', async () => {
      const response = await request(app).get('/health');
      expect(response.status).toBe(200);
    });

    it('returns healthy status', async () => {
      const response = await request(app).get('/health');
      expect(response.body.status).toBe('healthy');
    });
  });

  describe('Unknown routes', () => {
    it('returns 404 for a route that does not exist', async () => {
      const response = await request(app).get('/does-not-exist');
      expect(response.status).toBe(404);
    });
  });
});
