const { Kafka } = require('kafkajs');

const KAFKA_BROKER = process.env.KAFKA_BROKER || 'localhost:9092';
const TOPIC_NAME = process.env.KAFKA_TOPIC || 'smartretailx-stream-events';
const GROUP_ID = process.env.KAFKA_GROUP_ID || 'smartretailx-telemetry-group';

const kafka = new Kafka({
  clientId: 'smartretailx-consumer-worker',
  brokers: [KAFKA_BROKER],
  retry: {
    initialRetryTime: 1000,
    retries: 10
  }
});

const consumer = kafka.consumer({ groupId: GROUP_ID });

async function startConsumer() {
  console.log(`[KAFKA CONSUMER] Connecting to Kafka Broker: ${KAFKA_BROKER}...`);
  try {
    await consumer.connect();
    console.log(`[KAFKA CONSUMER] Successfully connected to Kafka Broker.`);
    await consumer.subscribe({ topic: TOPIC_NAME, fromBeginning: true });
    console.log(`[KAFKA CONSUMER] Subscribed to topic: '${TOPIC_NAME}' (Group: ${GROUP_ID})`);

    await consumer.run({
      eachMessage: async ({ topic, partition, message }) => {
        const payloadStr = message.value.toString();
        let payload = payloadStr;
        try {
          payload = JSON.parse(payloadStr);
        } catch (e) {}

        console.log(`[KAFKA STREAM EVENT] Received from topic '${topic}' [Partition ${partition}]:`, {
          key: message.key ? message.key.toString() : null,
          offset: message.offset,
          payload
        });
      },
    });
  } catch (err) {
    console.error(`[KAFKA CONSUMER ERROR] Connection error: ${err.message}. Retrying in 5 seconds...`);
    setTimeout(startConsumer, 5000);
  }
}

startConsumer();
