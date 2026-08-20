import http from 'k6/http';
import { check, sleep } from 'k6';

// k6 Options: Ramp up to 50 concurrent virtual users over 1 minute
export const options = {
  stages: [
    { duration: '30s', target: 50 }, // Ramp up
    { duration: '30s', target: 50 }, // Maintain load
  ],
  thresholds: {
    // Assert that 95% of request durations are under 500ms
    http_req_duration: ['p(95)<500'],
  },
};

export default function () {
  // Parameterize base URL to accept Environment Variable
  const baseUrl = __ENV.API_URL || 'http://localhost';

  // 1. GET Request to Product Catalogue API
  const productsRes = http.get(`${baseUrl}/api/v1/products`);
  check(productsRes, {
    'GET products status is 200': (r) => r.status === 200,
    'GET products latency is < 500ms': (r) => r.timings.duration < 500,
  });

  sleep(0.5);

  // 2. POST Request (with mock payload) to Order Processing API
  const orderPayload = JSON.stringify({
    customer_id: 'cust-9988',
    product_id: 'product-item-001',
    quantity: 3,
    total_amount: 149.99
  });

  const orderParams = {
    headers: {
      'Content-Type': 'application/json'
    }
  };

  const ordersRes = http.post(`${baseUrl}/api/v1/orders`, orderPayload, orderParams);
  check(ordersRes, {
    'POST orders status is 201': (r) => r.status === 201,
    'POST orders latency is < 500ms': (r) => r.timings.duration < 500,
  });

  sleep(0.5);
}
