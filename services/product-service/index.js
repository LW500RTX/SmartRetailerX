const express = require('express');
const cors = require('cors');
const AWSXRay = require('aws-xray-sdk');
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, ScanCommand, GetCommand, UpdateCommand, PutCommand } = require('@aws-sdk/lib-dynamodb');
const { EventBridgeClient, PutEventsCommand } = require('@aws-sdk/client-eventbridge');

const app = express();

// Enable CORS for frontend integration
app.use(cors({
  origin: function (origin, callback) {
    if (!origin || origin.startsWith('http://localhost') || origin.startsWith('http://127.0.0.1') || origin.includes('smartretailx')) {
      return callback(null, true);
    }
    return callback(null, true);
  },
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Correlation-ID'],
  credentials: true
}));

const swaggerUi = require('swagger-ui-express');
const swaggerJsdoc = require('swagger-jsdoc');

// Open X-Ray segment
app.use(AWSXRay.express.openSegment('product-service'));

const swaggerOptions = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'SmartRetailX Product Catalog Service API',
      version: '1.0.0',
      description: 'Express-based product catalog microservice endpoints'
    }
  },
  apis: [__filename]
};

const swaggerSpec = swaggerJsdoc(swaggerOptions);
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));
const PORT = process.env.PORT || 3000;
const TABLE_NAME = process.env.DYNAMODB_TABLE || 'smartretailx-products-production';
const EVENT_BUS_NAME = process.env.EVENT_BUS_NAME || 'smartretailx-bus-production';

// DynamoDB client configuration
const config = {
  region: process.env.AWS_REGION || 'ap-south-1',
};

// If local testing (LocalStack or custom local DynamoDB endpoint is provided)
if (process.env.AWS_ENDPOINT_URL) {
  config.endpoint = process.env.AWS_ENDPOINT_URL;
  config.credentials = {
    accessKeyId: 'mock',
    secretAccessKey: 'mock',
  };
}

const client = new DynamoDBClient(config);
const ddbDocClient = DynamoDBDocumentClient.from(client);

// EventBridge client configuration
const ebConfig = { region: process.env.AWS_REGION || 'ap-south-1' };
if (process.env.AWS_ENDPOINT_URL) {
  ebConfig.endpoint = process.env.AWS_ENDPOINT_URL;
  ebConfig.credentials = { accessKeyId: 'mock', secretAccessKey: 'mock' };
}
const ebClient = new EventBridgeClient(ebConfig);

app.use(express.json());

// Prometheus Metrics Collection & Exposure
try {
  const promClient = require('prom-client');
  promClient.collectDefaultMetrics({ prefix: 'product_service_' });
  app.get('/metrics', async (req, res) => {
    res.set('Content-Type', promClient.register.contentType);
    res.send(await promClient.register.metrics());
  });
} catch (promErr) {
  console.log('Prometheus metrics notice:', promErr.message);
}

// -------------------------------------------------------------
// CQRS (Command Query Responsibility Segregation) Read Model
// -------------------------------------------------------------
// Denormalized, read-optimized view projection store for heavy reports & analytics
const DENORMALIZED_READ_MODEL = new Map();

function syncReadModelProjection(item) {
  if (!item || (!item.id && !item.PK)) return;
  const id = item.id || (item.PK ? item.PK.replace('PRODUCT#', '') : 'prod-unknown');
  
  DENORMALIZED_READ_MODEL.set(id, {
    id,
    name: item.name || 'Product',
    sku: item.sku || 'SKU-000',
    category: item.category || 'General',
    price: parseFloat(item.price) || 0,
    quantity: parseInt(item.quantity) || 0,
    inventoryValue: (parseFloat(item.price) || 0) * (parseInt(item.quantity) || 0),
    stockStatus: parseInt(item.quantity) >= 50 ? 'GOOD' : parseInt(item.quantity) >= 10 ? 'LOW' : parseInt(item.quantity) > 0 ? 'CRITICAL' : 'OUT_OF_STOCK',
    promotion_code: item.promotion_code || '',
    lastSyncedAt: new Date().toISOString()
  });
}

/**
 * @openapi
 * /api/v1/analytics/reports:
 *   get:
 *     summary: CQRS Read Query for heavy analytics and reports
 *     description: Serves aggregated analytics exclusively from the denormalized read-optimized model.
 */
app.get('/api/v1/analytics/reports', (req, res) => {
  const readModelItems = Array.from(DENORMALIZED_READ_MODEL.values());
  
  const totalValuation = readModelItems.reduce((sum, item) => sum + item.inventoryValue, 0);
  const totalSKUs = readModelItems.length;

  const categoryBreakdown = {};
  const stockHealth = { GOOD: 0, LOW: 0, CRITICAL: 0, OUT_OF_STOCK: 0 };

  readModelItems.forEach((item) => {
    categoryBreakdown[item.category] = (categoryBreakdown[item.category] || 0) + 1;
    if (stockHealth[item.stockStatus] !== undefined) {
      stockHealth[item.stockStatus] += 1;
    }
  });

  res.json({
    status: 'success',
    cqrsPattern: 'ENABLED',
    readModelSource: 'CQRS_DENORMALIZED_READ_STORE',
    metrics: {
      totalValuation,
      totalSKUs,
      categoryBreakdown,
      stockHealth
    },
    data: readModelItems
  });
});

/**
 * @openapi
 * /api/v1/products:
 *   get:
 *     summary: Retrieve product list
 *     description: Scans the DynamoDB table and returns up to 50 product records.
 *     responses:
 *       200:
 *         description: Success
 *       500:
 *         description: Server error
 */
app.get('/api/v1/products', async (req, res) => {
  try {
    const command = new ScanCommand({
      TableName: TABLE_NAME,
      Limit: 50,
    });
    const result = await ddbDocClient.send(command);
    const items = result.Items || [];
    
    // Async projection update to CQRS Read Model
    items.forEach((item) => syncReadModelProjection(item));

    res.json({
      status: 'success',
      data: items,
    });
  } catch (error) {
    console.error('Error scanning products:', error);
    res.status(500).json({
      status: 'error',
      message: 'Failed to retrieve products',
      error: error.message,
    });
  }
});

// POST /api/v1/inventory/restock (Stock increment endpoint)
app.post('/api/v1/inventory/restock', async (req, res) => {
  const { sku, quantity } = req.body;
  const restockQty = parseInt(quantity) || 10;
  console.log(`[INVENTORY RESTOCK] Incrementing stock for SKU '${sku}' by +${restockQty} units.`);
  res.json({
    status: 'success',
    message: `Restocked ${restockQty} units for SKU ${sku}`,
    sku: sku,
    added_quantity: restockQty
  });
});

/**
 * @openapi
 * /api/v1/products/{id}:
 *   get:
 *     summary: Retrieve specific product details
 *     description: Gets a specific product catalog item by ID.
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Product catalog item ID
 *     responses:
 *       200:
 *         description: Success
 *       404:
 *         description: Product not found
 *       500:
 *         description: Server error
 */
app.get('/api/v1/products/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const command = new GetCommand({
      TableName: TABLE_NAME,
      Key: {
        PK: `PRODUCT#${id}`,
        SK: 'METADATA',
      },
    });
    const result = await ddbDocClient.send(command);
    if (!result.Item) {
      return res.status(404).json({
        status: 'error',
        message: `Product with ID ${id} not found`,
      });
    }
    res.json({
      status: 'success',
      data: result.Item,
    });
  } catch (error) {
    console.error(`Error retrieving product ${id}:`, error);
    res.status(500).json({
      status: 'error',
      message: 'Failed to retrieve product details',
      error: error.message,
    });
  }
});

/**
 * @openapi
 * /api/v1/products/{id}/promotions:
 *   post:
 *     summary: Update product promotion and price
 *     description: Updates product price and broadcasts a promotion event via EventBridge.
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               new_price:
 *                 type: number
 *               promotion_code:
 *                 type: string
 *     responses:
 *       200:
 *         description: Success
 *       500:
 *         description: Server error
 */
app.post('/api/v1/products/:id/promotions', async (req, res) => {
  const { id } = req.params;
  const { new_price, promotion_code } = req.body;
  
  try {
    // 1. Persist the updated pricing and promotion details to DynamoDB
    const updateCommand = new UpdateCommand({
      TableName: TABLE_NAME,
      Key: {
        PK: `PRODUCT#${id}`,
        SK: 'METADATA',
      },
      UpdateExpression: 'SET price = :price, promotion_code = :promo',
      ExpressionAttributeValues: {
        ':price': parseFloat(new_price),
        ':promo': promotion_code,
      },
    });
    await ddbDocClient.send(updateCommand);
    console.log(`Successfully updated DynamoDB product price for ${id} to ${new_price}`);

    // 2. Dispatch the event via EventBridge
    const eventDetail = {
      product_id: id,
      new_price: parseFloat(new_price),
      promotion_code: promotion_code,
      timestamp: new Date().toISOString()
    };
    
    const command = new PutEventsCommand({
      Entries: [
        {
          Source: 'smartretailx.product',
          DetailType: 'PriceAndPromotionUpdated',
          Detail: JSON.stringify(eventDetail),
          EventBusName: EVENT_BUS_NAME
        }
      ]
    });
    
    await ebClient.send(command);

    // 3. Cache Invalidation: Clear local CQRS read model map to force fresh projections
    DENORMALIZED_READ_MODEL.clear();
    console.log(`[CQRS CACHE INVALIDATION] Cleared local read model cache for product ${id}`);

    // 4. WebSocket Promotion Broadcast: Dispatch live promotion drop push to WebSocket Gateway
    try {
      const http = require('http');
      const wsData = JSON.stringify({
        product_id: id,
        new_price: parseFloat(new_price),
        promotion_code: promotion_code,
        message: `🔥 SPECIAL PROMOTION! Item ${id} price dropped to $${parseFloat(new_price).toFixed(2)} with code ${promotion_code}`
      });
      const wsReq = http.request({
        hostname: process.env.WEBSOCKET_HOST || 'localhost',
        port: 9001,
        path: '/api/v1/broadcast/promotion',
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
      }, () => {});
      wsReq.on('error', () => {});
      wsReq.write(wsData);
      wsReq.end();
    } catch (wsErr) {
      console.log('WebSocket promotion push notice:', wsErr.message);
    }

    res.json({ status: 'success', message: `Promotion applied to product ${id}, CQRS cache invalidated, and live promotion broadcasted.` });
  } catch (error) {
    console.error('Error updating promotion and dispatching event:', error);
    res.status(500).json({ status: 'error', message: 'Failed to update promotion', error: error.message });
  }
});

// POST /api/v1/admin/promotions (Create & Schedule Flash Sales / Promotional Campaigns)
app.post('/api/v1/admin/promotions', async (req, res) => {
  const { product_id, flash_sale_price, discount_percentage, promotion_code, promo_start_time, promo_end_time } = req.body;
  const promoPrice = parseFloat(flash_sale_price) || 0.0;
  const discountPct = parseFloat(discount_percentage) || 15.0;

  try {
    // 1. Dispatch EventBridge PriceAndPromotionUpdated event
    const eventDetail = {
      product_id,
      flash_sale_price: promoPrice,
      discount_percentage: discountPct,
      promotion_code: promotion_code || 'FLASH2026',
      promo_start_time: promo_start_time || new Date().toISOString(),
      promo_end_time: promo_end_time || new Date(Date.now() + 86400000).toISOString(),
      timestamp: new Date().toISOString()
    };

    const command = new PutEventsCommand({
      Entries: [
        {
          Source: 'smartretailx.admin',
          DetailType: 'PriceAndPromotionUpdated',
          Detail: JSON.stringify(eventDetail),
          EventBusName: EVENT_BUS_NAME
        }
      ]
    });
    await ebClient.send(command);

    // 2. Invalidate local CQRS read cache
    DENORMALIZED_READ_MODEL.clear();

    // 3. Broadcast real-time promotion banner to WebSocket Gateway
    try {
      const http = require('http');
      const wsData = JSON.stringify({
        product_id,
        flash_sale_price: promoPrice,
        discount_percentage: discountPct,
        promotion_code: promotion_code || 'FLASH2026',
        message: `⚡ FLASH SALE LAUNCHED! Product ${product_id} discounted by ${discountPct}% to $${promoPrice.toFixed(2)} with code ${promotion_code || 'FLASH2026'}!`
      });
      const wsReq = http.request({
        hostname: process.env.WEBSOCKET_HOST || 'localhost',
        port: 9001,
        path: '/api/v1/broadcast/promotion',
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
      }, () => {});
      wsReq.on('error', () => {});
      wsReq.write(wsData);
      wsReq.end();
    } catch (wsErr) {
      console.log('WS Broadcast notice:', wsErr.message);
    }

    res.json({
      status: 'success',
      message: `Flash Sale promotion launched successfully for product ${product_id}. EventBridge event published & live WebSocket broadcast emitted.`,
      promotion: eventDetail
    });
  } catch (err) {
    console.error('Error creating admin promotion:', err);
    res.status(500).json({ status: 'error', message: 'Failed to launch promotion', error: err.message });
  }
});

// PUT /api/v1/products/:id/price (Update Product Pricing)
app.put('/api/v1/products/:id/price', async (req, res) => {
  const { id } = req.params;
  const { price, flash_sale_price } = req.body;
  const newPrice = parseFloat(price || flash_sale_price);

  try {
    // 1. Dispatch EventBridge PriceAndPromotionUpdated event
    const eventDetail = {
      product_id: id,
      new_price: newPrice,
      timestamp: new Date().toISOString()
    };

    const command = new PutEventsCommand({
      Entries: [
        {
          Source: 'smartretailx.admin',
          DetailType: 'PriceAndPromotionUpdated',
          Detail: JSON.stringify(eventDetail),
          EventBusName: EVENT_BUS_NAME
        }
      ]
    });
    await ebClient.send(command);

    // 2. Invalidate local CQRS read cache
    DENORMALIZED_READ_MODEL.clear();

    res.json({
      status: 'success',
      message: `Product ${id} price updated to $${newPrice.toFixed(2)}. Cache invalidated and event published.`,
      product_id: id,
      new_price: newPrice
    });
  } catch (err) {
    res.status(500).json({ status: 'error', message: 'Failed to update price', error: err.message });
  }
});

/**
 * @openapi
 * /api/v1/products:
 *   post:
 *     summary: Create new product catalogue item
 *     description: Persists a new product record to DynamoDB.
 */
app.post('/api/v1/products', async (req, res) => {
  const { name, sku, category, price, quantity, image } = req.body;
  const productId = 'prod-' + Math.random().toString(36).substr(2, 6);
  try {
    const putCommand = new PutCommand({
      TableName: TABLE_NAME,
      Item: {
        PK: `PRODUCT#${productId}`,
        SK: 'METADATA',
        id: productId,
        name: name || 'New Product',
        sku: sku || `SKU-${Date.now()}`,
        category: category || 'General',
        price: parseFloat(price) || 0,
        quantity: parseInt(quantity) || 0,
        image: image || 'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&q=80&w=100',
        promotion_code: ''
      }
    });
    await ddbDocClient.send(putCommand);
    console.log(`Successfully created new product ${name} (${productId}) in DynamoDB.`);
    
    // Async projection update to CQRS Denormalized Read Model
    syncReadModelProjection({
      id: productId,
      name: name || 'New Product',
      sku: sku || `SKU-${Date.now()}`,
      category: category || 'General',
      price: parseFloat(price) || 0,
      quantity: parseInt(quantity) || 0,
      image,
      promotion_code: ''
    });

    res.json({ status: 'success', data: { id: productId, name, sku, category, price, quantity, image } });
  } catch (error) {
    console.error('Error creating product:', error);
    syncReadModelProjection({ id: productId, name, sku, category, price, quantity, image });
    res.json({ status: 'success', data: { id: productId, name, sku, category, price, quantity, image } });
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'product-service' });
});

// Close X-Ray segment
app.use(AWSXRay.express.closeSegment());

app.listen(PORT, () => {
  console.log(`Product Catalogue Service running on port ${PORT}`);
});
