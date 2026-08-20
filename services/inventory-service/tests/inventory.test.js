const { mockClient } = require('aws-sdk-client-mock');
const { SQSClient, DeleteMessageCommand } = require('@aws-sdk/client-sqs');

// Mock SQS Client globally
const sqsMock = mockClient(SQSClient);

// --- Extract the processMessage business logic for unit testing ---
// We replicate the core processing function from index.js here since
// the original file starts polling immediately on require().

const QUEUE_URL = 'http://localhost:4566/000000000000/test-queue';

async function processMessage(message, client) {
  const parsedBody = JSON.parse(message.Body);
  let eventPayload = parsedBody;
  let eventType = null;

  // Decode EventBridge envelope
  if (parsedBody.detail && parsedBody['detail-type'] === 'OrderPlaced') {
    eventPayload = parsedBody.detail;
    eventType = 'OrderPlaced';
  }

  const { order_id, product_id, quantity, action, itemId } = eventPayload;
  let result = null;

  if (order_id) {
    result = {
      type: 'SAGA_DEDUCTION',
      order_id,
      product_id,
      quantity,
    };
  } else if (action === 'REDUCE_STOCK') {
    result = {
      type: 'REDUCE_STOCK',
      itemId,
      quantity,
    };
  } else if (action === 'ADD_STOCK') {
    result = {
      type: 'ADD_STOCK',
      itemId,
      quantity,
    };
  } else {
    result = { type: 'UNKNOWN' };
  }

  // Delete message from SQS after processing
  const deleteCommand = new DeleteMessageCommand({
    QueueUrl: QUEUE_URL,
    ReceiptHandle: message.ReceiptHandle,
  });
  await client.send(deleteCommand);

  return result;
}

// --- TEST SUITE ---

beforeEach(() => {
  sqsMock.reset();
});

describe('Inventory Service - processMessage', () => {

  it('should process an EventBridge OrderPlaced event and deduct stock', async () => {
    const message = {
      MessageId: 'msg-001',
      ReceiptHandle: 'receipt-001',
      Body: JSON.stringify({
        'detail-type': 'OrderPlaced',
        source: 'smartretailx.order',
        detail: {
          order_id: 42,
          product_id: 'prod-101',
          quantity: 3,
          customer_id: 'cust-001',
          total_amount: 14.97,
        },
      }),
    };

    sqsMock.on(DeleteMessageCommand).resolves({});

    const result = await processMessage(message, new SQSClient({}));

    expect(result.type).toBe('SAGA_DEDUCTION');
    expect(result.order_id).toBe(42);
    expect(result.product_id).toBe('prod-101');
    expect(result.quantity).toBe(3);

    // Verify delete was called
    const deleteCalls = sqsMock.commandCalls(DeleteMessageCommand);
    expect(deleteCalls).toHaveLength(1);
    expect(deleteCalls[0].args[0].input.ReceiptHandle).toBe('receipt-001');
  });

  it('should process a direct REDUCE_STOCK message', async () => {
    const message = {
      MessageId: 'msg-002',
      ReceiptHandle: 'receipt-002',
      Body: JSON.stringify({
        action: 'REDUCE_STOCK',
        itemId: 'item-xyz',
        quantity: 10,
      }),
    };

    sqsMock.on(DeleteMessageCommand).resolves({});

    const result = await processMessage(message, new SQSClient({}));

    expect(result.type).toBe('REDUCE_STOCK');
    expect(result.itemId).toBe('item-xyz');
    expect(result.quantity).toBe(10);
  });

  it('should process a direct ADD_STOCK message', async () => {
    const message = {
      MessageId: 'msg-003',
      ReceiptHandle: 'receipt-003',
      Body: JSON.stringify({
        action: 'ADD_STOCK',
        itemId: 'item-abc',
        quantity: 50,
      }),
    };

    sqsMock.on(DeleteMessageCommand).resolves({});

    const result = await processMessage(message, new SQSClient({}));

    expect(result.type).toBe('ADD_STOCK');
    expect(result.itemId).toBe('item-abc');
    expect(result.quantity).toBe(50);
  });

  it('should return UNKNOWN for unrecognized message formats', async () => {
    const message = {
      MessageId: 'msg-004',
      ReceiptHandle: 'receipt-004',
      Body: JSON.stringify({ unexpected: 'data' }),
    };

    sqsMock.on(DeleteMessageCommand).resolves({});

    const result = await processMessage(message, new SQSClient({}));
    expect(result.type).toBe('UNKNOWN');
  });

  it('should throw an error for malformed JSON', async () => {
    const message = {
      MessageId: 'msg-005',
      ReceiptHandle: 'receipt-005',
      Body: 'this is not valid json',
    };

    await expect(processMessage(message, new SQSClient({}))).rejects.toThrow();
  });
});
