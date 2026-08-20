const { SQSClient, ReceiveMessageCommand, DeleteMessageCommand } = require('@aws-sdk/client-sqs');

const QUEUE_URL = process.env.SQS_QUEUE_URL || 'http://localhost:4566/000000000000/smartretailx-inventory-processing-queue';
const POLL_INTERVAL_MS = 5000;

// In-memory stock state tracking matching App.jsx baseline
const INVENTORY_STATE = {
  'prod-101': 75,
  'prod-102': 8,
  'prod-103': 30,
  'prod-104': 90,
  'prod-105': 0
};

// SQS Client configuration
const config = {
  region: process.env.AWS_REGION || 'ap-south-1',
};

// If local testing (LocalStack or custom local SQS endpoint is provided)
if (process.env.AWS_ENDPOINT_URL) {
  config.endpoint = process.env.AWS_ENDPOINT_URL;
  config.credentials = {
    accessKeyId: 'mock',
    secretAccessKey: 'mock',
  };
}

const client = new SQSClient(config);

async function pollQueue() {
  console.log(`Polling SQS queue: ${QUEUE_URL}...`);
  try {
    const receiveParams = {
      QueueUrl: QUEUE_URL,
      MaxNumberOfMessages: 5,
      WaitTimeSeconds: 10, // Long polling
    };

    const command = new ReceiveMessageCommand(receiveParams);
    const data = await client.send(command);

    if (data.Messages && data.Messages.length > 0) {
      console.log(`Received ${data.Messages.length} messages from SQS.`);
      for (const message of data.Messages) {
        await processMessage(message);
      }
    } else {
      console.log('No messages in queue.');
    }
  } catch (error) {
    console.error('Error polling SQS queue:', error.message);
  } finally {
    // Schedule next poll
    setTimeout(pollQueue, POLL_INTERVAL_MS);
  }
}

async function processMessage(message) {
  console.log(`Processing message ID: ${message.MessageId}`);
  try {
    const parsedBody = JSON.parse(message.Body);
    let eventPayload = parsedBody;

    // Check if message arrived via EventBridge rule (which nests the payload in the 'detail' attribute)
    if (parsedBody.detail && parsedBody['detail-type'] === 'OrderPlaced') {
      eventPayload = parsedBody.detail;
      console.log(`[INVENTORY WORKER] EventBridge Event 'OrderPlaced' envelope decoded.`);
    }

    const { order_id, product_id, quantity, action, itemId } = eventPayload;

    if (order_id) {
      // Saga stock deduction step triggered by EventBridge
      const qty = parseInt(quantity || 0, 10);
      if (INVENTORY_STATE[product_id] !== undefined) {
        INVENTORY_STATE[product_id] = Math.max(0, INVENTORY_STATE[product_id] - qty);
      } else {
        // Fallback for new product IDs
        INVENTORY_STATE[product_id] = Math.max(0, 100 - qty);
      }
      console.log(`[INVENTORY SAGA] Transaction Successful - Deducted ${qty} units of product ${product_id} for Order #${order_id}. Remaining Stock: ${INVENTORY_STATE[product_id]}`);
    } else if (action) {
      // Handle legacy direct SQS messages
      const qty = parseInt(quantity || 0, 10);
      const targetId = itemId || product_id;
      if (action === 'REDUCE_STOCK') {
        if (INVENTORY_STATE[targetId] !== undefined) {
          INVENTORY_STATE[targetId] = Math.max(0, INVENTORY_STATE[targetId] - qty);
        } else {
          INVENTORY_STATE[targetId] = Math.max(0, 100 - qty);
        }
        console.log(`[INVENTORY DIRECT] Reduced stock for item ${targetId} by ${qty} units. Remaining Stock: ${INVENTORY_STATE[targetId]}`);
      } else if (action === 'ADD_STOCK') {
        if (INVENTORY_STATE[targetId] !== undefined) {
          INVENTORY_STATE[targetId] += qty;
        } else {
          INVENTORY_STATE[targetId] = 100 + qty;
        }
        console.log(`[INVENTORY DIRECT] Replenished stock for item ${targetId} by ${qty} units. Remaining Stock: ${INVENTORY_STATE[targetId]}`);
      }
    } else {
      console.log(`[INVENTORY WORKER] Unknown message format:`, eventPayload);
    }

    // Delete message from SQS upon successful processing
    const deleteParams = {
      QueueUrl: QUEUE_URL,
      ReceiptHandle: message.ReceiptHandle,
    };
    const deleteCommand = new DeleteMessageCommand(deleteParams);
    await client.send(deleteCommand);
    console.log(`Successfully deleted message ${message.MessageId} from queue.`);
  } catch (error) {
    console.error(`Failed to process or parse message ${message.MessageId}:`, error.message);
  }
}

// Start polling
console.log('Starting Inventory Management background worker...');
pollQueue();
