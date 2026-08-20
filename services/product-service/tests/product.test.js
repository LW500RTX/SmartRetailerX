const request = require('supertest');
const express = require('express');
const { mockClient } = require('aws-sdk-client-mock');
const { DynamoDBDocumentClient, ScanCommand } = require('@aws-sdk/lib-dynamodb');

// Initialize the DynamoDB client mock before routing
const ddbMock = mockClient(DynamoDBDocumentClient);

// Setup a mock express app matching product-service structure
const app = express();
app.use(express.json());

const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const client = new DynamoDBClient({ region: 'ap-south-1' });
const ddbDocClient = DynamoDBDocumentClient.from(client);
const TABLE_NAME = 'smartretailx-products-test';

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'product-service' });
});

app.get('/api/v1/products', async (req, res) => {
  try {
    const command = new ScanCommand({ TableName: TABLE_NAME, Limit: 50 });
    const result = await ddbDocClient.send(command);
    res.json({ status: 'success', data: result.Items || [] });
  } catch (error) {
    res.status(500).json({ status: 'error', error: error.message });
  }
});

// --- Test Spec Runs ---
describe('Product Service Unit Tests', () => {
  beforeEach(() => {
    ddbMock.reset();
  });

  it('GET /health should return 200 and healthy metadata', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('healthy');
    expect(res.body.service).toBe('product-service');
  });

  it('GET /api/v1/products should yield list of items from DynamoDB mock', async () => {
    const mockItems = [
      { PK: 'PRODUCT#1', SK: 'METADATA', name: 'Fresh Milk', price: 3.50, sku: 'MILK-1' }
    ];
    ddbMock.on(ScanCommand).resolves({ Items: mockItems });

    const res = await request(app).get('/api/v1/products');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('success');
    expect(res.body.data).toHaveLength(1);
    expect(res.body.data[0].name).toBe('Fresh Milk');
  });
});
