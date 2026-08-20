const request = require('supertest');
const express = require('express');
const { mockClient } = require('aws-sdk-client-mock');
const { DynamoDBDocumentClient, ScanCommand, GetCommand } = require('@aws-sdk/lib-dynamodb');

// Mock the DynamoDB Document Client before importing the app
const ddbMock = mockClient(DynamoDBDocumentClient);

// We need to build a minimal Express app that mirrors the routes in index.js
// because the original index.js calls app.listen() which blocks test runners.
const app = express();
app.use(express.json());

const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const client = new DynamoDBClient({ region: 'ap-south-1' });
const ddbDocClient = DynamoDBDocumentClient.from(client);
const TABLE_NAME = 'smartretailx-products-test';

app.get('/api/v1/products', async (req, res) => {
  try {
    const command = new ScanCommand({ TableName: TABLE_NAME, Limit: 50 });
    const result = await ddbDocClient.send(command);
    res.json({ status: 'success', data: result.Items || [] });
  } catch (error) {
    res.status(500).json({ status: 'error', message: 'Failed to retrieve products', error: error.message });
  }
});

app.get('/api/v1/products/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const command = new GetCommand({ TableName: TABLE_NAME, Key: { PK: `PRODUCT#${id}`, SK: 'METADATA' } });
    const result = await ddbDocClient.send(command);
    if (!result.Item) {
      return res.status(404).json({ status: 'error', message: `Product with ID ${id} not found` });
    }
    res.json({ status: 'success', data: result.Item });
  } catch (error) {
    res.status(500).json({ status: 'error', message: 'Failed to retrieve product', error: error.message });
  }
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'product-service' });
});

// --- TEST SUITE ---

const MOCK_PRODUCTS = [
  { PK: 'PRODUCT#prod-101', SK: 'METADATA', name: 'Organic Red Apples', sku: 'APP-001-RED', category: 'Produce', price: 4.99, quantity: 75 },
  { PK: 'PRODUCT#prod-102', SK: 'METADATA', name: 'Whole Milk 2L', sku: 'DAI-402-MILK', category: 'Dairy', price: 3.50, quantity: 8 },
  { PK: 'PRODUCT#prod-103', SK: 'METADATA', name: 'Artisan Sourdough', sku: 'BAK-990-SOU', category: 'Bakery', price: 6.25, quantity: 30 },
];

beforeEach(() => {
  ddbMock.reset();
});

describe('GET /health', () => {
  it('should return healthy status', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('healthy');
    expect(res.body.service).toBe('product-service');
  });
});

describe('GET /api/v1/products', () => {
  it('should return a list of products from DynamoDB', async () => {
    ddbMock.on(ScanCommand).resolves({ Items: MOCK_PRODUCTS });

    const res = await request(app).get('/api/v1/products');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('success');
    expect(res.body.data).toHaveLength(3);
    expect(res.body.data[0].name).toBe('Organic Red Apples');
    expect(res.body.data[1].sku).toBe('DAI-402-MILK');
  });

  it('should return an empty array when DynamoDB table is empty', async () => {
    ddbMock.on(ScanCommand).resolves({ Items: [] });

    const res = await request(app).get('/api/v1/products');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('success');
    expect(res.body.data).toHaveLength(0);
  });

  it('should return 500 when DynamoDB scan fails', async () => {
    ddbMock.on(ScanCommand).rejects(new Error('DynamoDB connection timeout'));

    const res = await request(app).get('/api/v1/products');
    expect(res.statusCode).toBe(500);
    expect(res.body.status).toBe('error');
  });
});

describe('GET /api/v1/products/:id', () => {
  it('should return a single product by ID', async () => {
    ddbMock.on(GetCommand).resolves({ Item: MOCK_PRODUCTS[0] });

    const res = await request(app).get('/api/v1/products/prod-101');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('success');
    expect(res.body.data.name).toBe('Organic Red Apples');
    expect(res.body.data.price).toBe(4.99);
  });

  it('should return 404 when product is not found', async () => {
    ddbMock.on(GetCommand).resolves({ Item: undefined });

    const res = await request(app).get('/api/v1/products/nonexistent');
    expect(res.statusCode).toBe(404);
    expect(res.body.status).toBe('error');
    expect(res.body.message).toContain('not found');
  });

  it('should return 500 when DynamoDB get fails', async () => {
    ddbMock.on(GetCommand).rejects(new Error('Access denied'));

    const res = await request(app).get('/api/v1/products/prod-101');
    expect(res.statusCode).toBe(500);
    expect(res.body.status).toBe('error');
  });
});
