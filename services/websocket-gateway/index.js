const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 9001;

app.use(cors());
app.use(express.json());

const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

let activeClients = 0;

io.on('connection', (socket) => {
  activeClients++;
  console.log(`[WS GATEWAY] Client connected: ${socket.id} (Total: ${activeClients})`);

  socket.emit('connection_ack', {
    status: 'connected',
    socketId: socket.id,
    timestamp: new Date().toISOString()
  });

  socket.on('disconnect', () => {
    activeClients = Math.max(0, activeClients - 1);
    console.log(`[WS GATEWAY] Client disconnected: ${socket.id} (Total: ${activeClients})`);
  });
});

// Endpoint for backend services (Order Service, Inventory Service) to broadcast events
app.post('/events', (req, res) => {
  const { event, data } = req.body;
  if (!event) {
    return res.status(400).json({ error: 'Event name is required' });
  }

  console.log(`[WS GATEWAY] Broadcasting event '${event}' to ${activeClients} connected clients.`);
  io.emit(event, data);

  res.json({
    status: 'success',
    broadcastEvent: event,
    activeClients
  });
});

// Endpoint for Product Service to broadcast live promotions to React SPA sessions
app.post('/api/v1/broadcast/promotion', (req, res) => {
  const promoData = req.body;
  console.log(`[WS GATEWAY] Broadcasting live promotion for item ${promoData.product_id} ($${promoData.new_price}).`);
  io.emit('promotion_updated', promoData);
  res.json({ status: 'success', event: 'promotion_updated', activeClients });
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'websocket-gateway',
    activeClients,
    port: PORT
  });
});

server.listen(PORT, () => {
  console.log(`WebSocket Gateway Service running on port ${PORT}`);
});
