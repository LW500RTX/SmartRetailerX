import http from 'k6/http';
import { check, sleep } from 'k6';

// -------------------------------------------------------------
// k6 Load Test Configuration & Thresholds
// -------------------------------------------------------------
export const options = {
  stages: [
    { duration: '30s', target: 50 }, // Ramp-up to 50 concurrent virtual users over 30s
    { duration: '1m', target: 50 },  // Hold steady load at 50 VUs for 1 minute
    { duration: '30s', target: 0 },  // Ramp-down to 0 VUs over 30s
  ],
  thresholds: {
    // 95% of requests must complete within 250ms
    http_req_duration: ['p(95)<250'],
    // HTTP request error rate must remain below 1%
    http_req_failed: ['rate<0.01'],
  },
};

const BASE_PRODUCT_URL = __ENV.PRODUCT_API_URL || 'http://localhost:3000';
const BASE_ORDER_URL = __ENV.ORDER_API_URL || 'http://localhost:8000';

// Sample product catalog IDs for simulated shopping activity
const SAMPLE_PRODUCTS = [
  { id: 'prod-101', name: 'Whole Milk 2L', price: 3.49 },
  { id: 'prod-102', name: 'Organic Red Apples 1kg', price: 4.99 },
  { id: 'prod-103', name: 'Artisan Sourdough Bread', price: 5.25 },
  { id: 'prod-104', name: 'Greek Yogurt 500g', price: 3.99 },
  { id: 'prod-105', name: 'Sparkling Water 1.5L', price: 1.89 },
];

export default function () {
  // 1. Simulate GET /api/v1/products catalogue browsing
  const productRes = http.get(`${BASE_PRODUCT_URL}/api/v1/products`);
  check(productRes, {
    'product list status is 200': (r) => r.status === 200,
    'product response has body': (r) => r.body.length > 0,
  });

  // Short pause to simulate user think time
  sleep(1);

  // 2. Select random product and simulate POST /api/v1/orders checkout
  const randomProduct = SAMPLE_PRODUCTS[Math.floor(Math.random() * SAMPLE_PRODUCTS.length)];
  const orderPayload = JSON.stringify({
    customer_id: `loadtest-user-${__VU}@smartretailx.internal`,
    product_id: randomProduct.id,
    product_name: randomProduct.name,
    image_url: 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=150',
    payment_method: 'Digital Bank Transfer (Bank of Ceylon / Sampath Bank)',
    quantity: Math.floor(Math.random() * 3) + 1,
    total_amount: randomProduct.price * 2,
  });

  const orderParams = {
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer mock-jwt-token-123',
      'X-Correlation-ID': `k6-corr-${__VU}-${__ITER}`,
    },
  };

  const orderRes = http.post(`${BASE_ORDER_URL}/api/v1/orders`, orderPayload, orderParams);
  check(orderRes, {
    'order status is 201 or 200': (r) => r.status === 201 || r.status === 200,
  });

  // Pacing pause between user actions
  sleep(1);
}
