import React, { useState, useEffect } from 'react';

export default function SystemHealthView({ sreMetrics }) {
  const [autoRefresh, setAutoRefresh] = useState(true);
  const [lastRefreshed, setLastRefreshed] = useState(new Date().toLocaleTimeString());

  const services = [
    {
      id: 'user-service',
      name: 'User Management Service',
      port: '8001',
      stack: 'Python 3.11 / FastAPI',
      persistence: 'MySQL (customers table)',
      status: 'HEALTHY',
      latency: '12ms',
      endpoint: '/api/v1/users',
      icon: 'ph-user-gear',
    },
    {
      id: 'product-service',
      name: 'Product Catalogue Service',
      port: '3000',
      stack: 'Node.js / Express',
      persistence: 'Amazon DynamoDB',
      status: 'HEALTHY',
      latency: '18ms',
      endpoint: '/api/v1/products',
      icon: 'ph-package',
    },
    {
      id: 'order-service',
      name: 'Order Processing Service',
      port: '8000',
      stack: 'Python 3.11 / FastAPI',
      persistence: 'SQLite (orders.db) & SMTP',
      status: 'HEALTHY',
      latency: '14ms',
      endpoint: '/api/v1/orders',
      icon: 'ph-shopping-cart',
    },
    {
      id: 'payment-service',
      name: 'Payment Service',
      port: '8002',
      stack: 'Python 3.11 / FastAPI',
      persistence: 'EventBridge Publisher',
      status: 'HEALTHY',
      latency: '22ms',
      endpoint: '/api/v1/payments',
      icon: 'ph-credit-card',
    },
    {
      id: 'inventory-service',
      name: 'Inventory Management Service',
      port: 'Worker',
      stack: 'Node.js / AWS SQS Client',
      persistence: 'In-Memory Catalog Sync',
      status: 'ACTIVE',
      latency: '8ms',
      endpoint: 'SQS Sagas Poller',
      icon: 'ph-boxes',
    },
    {
      id: 'notification-service',
      name: 'Notification Service',
      port: '9000',
      stack: 'Node.js / Opossum Circuit Breaker',
      persistence: 'Audit Log & SQS Queue',
      status: 'HEALTHY',
      latency: '10ms',
      endpoint: 'smartretailx-notification-queue',
      icon: 'ph-bell-ringing',
    },
  ];

  const recentEvents = [
    {
      id: 'evt-101',
      type: 'OrderPlaced',
      source: 'smartretailx.order',
      target: 'smartretailx-inventory-processing-queue',
      status: 'DELIVERED',
      time: '10s ago',
      correlationId: 'corr-8F92A10B',
    },
    {
      id: 'evt-102',
      type: 'PaymentProcessed',
      source: 'smartretailx.payment',
      target: 'smartretailx-notification-queue',
      status: 'APPROVED',
      time: '24s ago',
      correlationId: 'corr-3C19F94D',
    },
    {
      id: 'evt-103',
      type: 'PriceAndPromotionUpdated',
      source: 'smartretailx.product',
      target: 'smartretailx-bus',
      status: 'DISPATCHED',
      time: '1m ago',
      correlationId: 'corr-7A44E190',
    },
    {
      id: 'evt-104',
      type: 'DeliveryStatusUpdated',
      source: 'smartretailx.order',
      target: 'smartretailx-bus',
      status: 'SYNCED',
      time: '3m ago',
      correlationId: 'corr-2D881B5E',
    },
  ];

  useEffect(() => {
    if (!autoRefresh) return;
    const interval = setInterval(() => {
      setLastRefreshed(new Date().toLocaleTimeString());
    }, 5000);
    return () => clearInterval(interval);
  }, [autoRefresh]);

  return (
    <div className="w-full text-left space-y-6 max-w-[1440px] mx-auto px-lg py-lg">
      {/* Header Panel */}
      <div className="bg-surface-container-lowest p-6 rounded-xl border border-surface-variant/30 shadow-sm flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h2 className="text-headline-md text-on-surface font-semibold flex items-center gap-2">
            <i className="ph ph-cpu text-primary text-xl"></i>
            System Infrastructure &amp; Health Telemetry
          </h2>
          <p className="text-xs text-on-surface-variant mt-0.5">
            Real-time status monitoring across all 6 core microservices, API Gateway endpoints, and EventBridge SQS messaging queues.
          </p>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={() => setAutoRefresh(!autoRefresh)}
            className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-colors flex items-center gap-1.5 cursor-pointer ${
              autoRefresh ? 'bg-primary/10 text-primary border border-primary/20' : 'bg-surface-variant text-on-surface-variant'
            }`}
          >
            <span className={`w-2 h-2 rounded-full ${autoRefresh ? 'bg-primary animate-pulse' : 'bg-outline'}`}></span>
            <span>{autoRefresh ? 'Live Polling (5s)' : 'Polling Paused'}</span>
          </button>
          <span className="text-[11px] text-on-surface-variant font-mono">Refreshed: {lastRefreshed}</span>
        </div>
      </div>

      {/* SRE Summary Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-surface-container-lowest p-5 rounded-xl border border-surface-variant/30 shadow-sm flex flex-col justify-between">
          <span className="text-[11px] font-bold text-on-surface-variant uppercase tracking-wider">Cluster Health</span>
          <div className="text-2xl font-bold text-primary mt-2 flex items-center gap-2">
            <span>6/6 Services</span>
            <span className="w-2.5 h-2.5 rounded-full bg-primary animate-ping"></span>
          </div>
          <p className="text-[11px] text-on-surface-variant mt-1">100% Microservices Operational</p>
        </div>

        <div className="bg-surface-container-lowest p-5 rounded-xl border border-surface-variant/30 shadow-sm flex flex-col justify-between">
          <span className="text-[11px] font-bold text-on-surface-variant uppercase tracking-wider">API Gateway Latency</span>
          <div className="text-2xl font-bold text-on-surface mt-2 font-mono">{sreMetrics?.apiLatency || '38ms'}</div>
          <p className="text-[11px] text-primary font-bold mt-1">Nominal Sub-50ms Threshold</p>
        </div>

        <div className="bg-surface-container-lowest p-5 rounded-xl border border-surface-variant/30 shadow-sm flex flex-col justify-between">
          <span className="text-[11px] font-bold text-on-surface-variant uppercase tracking-wider">Event Messaging Bus</span>
          <div className="text-2xl font-bold text-on-surface mt-2 font-mono">smartretailx-bus</div>
          <p className="text-[11px] text-on-surface-variant mt-1">Amazon EventBridge Active</p>
        </div>

        <div className="bg-surface-container-lowest p-5 rounded-xl border border-surface-variant/30 shadow-sm flex flex-col justify-between">
          <span className="text-[11px] font-bold text-on-surface-variant uppercase tracking-wider">Authentication Guard</span>
          <div className="text-2xl font-bold text-on-surface mt-2 flex items-center gap-1.5">
            <i className="ph ph-shield-check text-primary text-xl"></i>
            <span>Cognito RBAC</span>
          </div>
          <p className="text-[11px] text-on-surface-variant mt-1">JWT Bearer Authorization On</p>
        </div>
      </div>

      {/* Microservices Status Grid (6 Core Services) */}
      <div>
        <h3 className="text-headline-md font-semibold text-on-surface mb-3 flex items-center gap-2">
          <i className="ph ph-squares-four text-primary"></i>
          Microservices Node Grid (6 Services)
        </h3>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {services.map((svc) => (
            <div
              key={svc.id}
              className="bg-surface-container-lowest p-5 rounded-xl border border-surface-variant/30 shadow-sm hover:border-primary/40 transition-all flex flex-col justify-between"
            >
              <div>
                <div className="flex items-center justify-between mb-3">
                  <div className="flex items-center space-x-2.5">
                    <div className="w-9 h-9 rounded-lg bg-primary/10 flex items-center justify-center text-primary">
                      <i className={`ph ${svc.icon} text-lg`}></i>
                    </div>
                    <div>
                      <h4 className="font-bold text-xs text-on-surface">{svc.name}</h4>
                      <span className="text-[10px] text-on-surface-variant font-mono">Port: {svc.port}</span>
                    </div>
                  </div>
                  <span className="px-2.5 py-1 rounded text-[10px] font-bold bg-primary/10 text-primary uppercase tracking-wider">
                    {svc.status}
                  </span>
                </div>

                <div className="space-y-1.5 text-xs text-on-surface-variant bg-surface-container p-3 rounded-lg border border-surface-variant/30">
                  <div className="flex justify-between items-center">
                    <span>Tech Stack:</span>
                    <span className="font-medium text-on-surface text-[11px]">{svc.stack}</span>
                  </div>
                  <div className="flex justify-between items-center">
                    <span>Persistence:</span>
                    <span className="font-medium text-on-surface text-[11px]">{svc.persistence}</span>
                  </div>
                  <div className="flex justify-between items-center">
                    <span>Endpoint Route:</span>
                    <span className="font-mono text-primary text-[10px] font-bold">{svc.endpoint}</span>
                  </div>
                </div>
              </div>

              <div className="mt-4 pt-3 border-t border-surface-variant/30 flex justify-between items-center text-[11px]">
                <span className="text-on-surface-variant">Response Latency</span>
                <span className="font-mono font-bold text-primary">{svc.latency}</span>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Event-Driven Message Queue & Tracing Section */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* SQS & EventBridge Telemetry Log */}
        <div className="col-span-1 lg:col-span-8 bg-surface-container-lowest rounded-xl border border-outline-variant/30 shadow-sm p-5 flex flex-col">
          <div className="flex justify-between items-center mb-4">
            <h3 className="font-headline-md text-on-surface font-semibold flex items-center gap-2">
              <i className="ph ph-tray text-primary"></i>
              EventBridge &amp; SQS Message Flow Audit Log
            </h3>
            <span className="text-[10px] font-bold uppercase bg-secondary-container text-on-secondary-container px-2.5 py-1 rounded">
              Sagas Active
            </span>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="border-b border-surface-variant text-[11px] uppercase font-bold text-on-surface-variant bg-surface-container">
                  <th className="py-2.5 px-3">Event Type</th>
                  <th className="py-2.5 px-3">Event Source</th>
                  <th className="py-2.5 px-3">Target SQS Queue</th>
                  <th className="py-2.5 px-3">Correlation ID</th>
                  <th className="py-2.5 px-3 text-right">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-surface-variant/40 text-xs">
                {recentEvents.map((evt) => (
                  <tr key={evt.id} className="hover:bg-surface-container-low/50">
                    <td className="py-3 px-3 font-semibold text-on-surface flex items-center gap-1.5">
                      <span className="w-1.5 h-1.5 rounded-full bg-primary"></span>
                      {evt.type}
                    </td>
                    <td className="py-3 px-3 font-mono text-[11px] text-on-surface-variant">{evt.source}</td>
                    <td className="py-3 px-3 text-[11px] text-on-surface-variant">{evt.target}</td>
                    <td className="py-3 px-3 font-mono text-[10px] text-primary">{evt.correlationId}</td>
                    <td className="py-3 px-3 text-right">
                      <span className="px-2 py-0.5 bg-primary/10 text-primary font-bold text-[10px] rounded uppercase">
                        {evt.status}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        {/* API Gateway & Security Panel */}
        <div className="col-span-1 lg:col-span-4 bg-surface-container-lowest rounded-xl border border-outline-variant/30 shadow-sm p-5 flex flex-col justify-between space-y-4">
          <div>
            <h3 className="font-headline-md text-on-surface font-semibold flex items-center gap-2 mb-3">
              <i className="ph ph-shield-check text-primary"></i>
              API Gateway &amp; Security Guard
            </h3>
            <div className="space-y-3">
              <div className="p-3 border border-surface-variant/40 rounded-lg bg-surface-container space-y-1">
                <span className="text-[11px] font-bold text-on-surface block">REST API Versioning</span>
                <p className="text-[11px] text-on-surface-variant">All endpoints enforcing <strong>/api/v1/...</strong> path specification.</p>
              </div>

              <div className="p-3 border border-surface-variant/40 rounded-lg bg-surface-container space-y-1">
                <span className="text-[11px] font-bold text-on-surface block">Cognito IDP Verification</span>
                <p className="text-[11px] text-on-surface-variant">User Pool <strong>ap-south-1_L1YUt2PBl</strong> active with RSA JWKS validation.</p>
              </div>

              <div className="p-3 border border-surface-variant/40 rounded-lg bg-surface-container space-y-1">
                <span className="text-[11px] font-bold text-on-surface block">AWS X-Ray Distributed Traces</span>
                <p className="text-[11px] text-on-surface-variant">Cross-microservice traces tagged with <strong>X-Correlation-ID</strong> header.</p>
              </div>
            </div>
          </div>

          <div className="p-3 bg-primary/10 border border-primary/20 rounded-lg text-center">
            <span className="text-xs font-bold text-primary">All Security Policies Nominal</span>
          </div>
        </div>
      </div>
    </div>
  );
}
