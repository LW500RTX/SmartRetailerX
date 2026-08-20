import React from 'react';

export default function AnalyticsView({ products }) {
  // Compute some insights dynamically
  const totalSku = products.length;
  const criticalSku = products.filter((p) => (parseInt(p.quantity) || 0) < 10).length;
  const lowSku = products.filter((p) => (parseInt(p.quantity) || 0) >= 10 && (parseInt(p.quantity) || 0) < 50).length;

  return (
    <div className="space-y-6 max-w-7xl mx-auto w-full text-left">
      {/* Page Title Header */}
      <div className="bg-surface-container-lowest p-6 rounded-xl border border-surface-variant/30 shadow-sm flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h2 className="text-headline-md text-on-surface font-semibold">Deliveries & Reports Analytics</h2>
          <p className="text-xs text-on-surface-variant mt-0.5">SRE metrics, inventory analytics, and distribution summaries</p>
        </div>
        <span className="px-3 py-1 bg-primary/10 text-primary text-xs font-bold rounded-full uppercase tracking-wider">
          Node Cluster nominal
        </span>
      </div>

      {/* Bento Grid */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* KPI 1: SKU Breakdown */}
        <div className="bg-surface rounded-xl p-6 shadow-sm border border-surface-variant flex flex-col justify-between">
          <div>
            <span className="text-xs text-on-surface-variant font-bold uppercase tracking-wider">SKU Catalog Status</span>
            <div className="text-display-lg text-on-surface font-bold mt-2">{totalSku} Active SKUs</div>
          </div>
          <div className="mt-4 space-y-2 text-xs">
            <div className="flex justify-between items-center text-on-surface-variant">
              <span>Healthy Status (50+)</span>
              <span className="font-bold text-primary">{totalSku - criticalSku - lowSku} items</span>
            </div>
            <div className="flex justify-between items-center text-on-surface-variant">
              <span>Low Level (10-49)</span>
              <span className="font-bold text-warning-600">{lowSku} items</span>
            </div>
            <div className="flex justify-between items-center text-on-surface-variant">
              <span>Critical Level (1-9)</span>
              <span className="font-bold text-red-600">{criticalSku} items</span>
            </div>
          </div>
        </div>

        {/* KPI 2: Inventory Flow Summary */}
        <div className="bg-surface rounded-xl p-6 shadow-sm border border-surface-variant flex flex-col justify-between">
          <div>
            <span className="text-xs text-on-surface-variant font-bold uppercase tracking-wider">Weekly Shelf Turnover</span>
            <div className="text-display-lg text-primary font-bold mt-2">2.4 Days</div>
          </div>
          <p className="text-xs text-on-surface-variant mt-2 leading-relaxed">
            Shelf products are restocked and consumed at an average of 2.4 days intervals, maintaining freshness metrics well below the regional distribution centers' thresholds.
          </p>
        </div>

        {/* KPI 3: Message Queuing Telemetry */}
        <div className="bg-surface rounded-xl p-6 shadow-sm border border-surface-variant flex flex-col justify-between">
          <div>
            <span className="text-xs text-on-surface-variant font-bold uppercase tracking-wider">SQS Sagas Ingestion Log</span>
            <div className="text-display-lg text-on-surface font-bold mt-2">0.02s Lag</div>
          </div>
          <div className="mt-4 space-y-2 text-xs">
            <div className="flex justify-between items-center text-on-surface-variant">
              <span>Inventory Queue Age</span>
              <span className="font-semibold text-on-surface font-mono">&lt; 1.2s</span>
            </div>
            <div className="flex justify-between items-center text-on-surface-variant">
              <span>Notifications Queue Age</span>
              <span className="font-semibold text-on-surface font-mono">&lt; 0.8s</span>
            </div>
            <div className="flex justify-between items-center text-on-surface-variant">
              <span>Dead Letter Queues (DLQs)</span>
              <span className="font-bold text-primary font-mono">0 messages</span>
            </div>
          </div>
        </div>
      </div>

      {/* Analytics Reports & Logs Details */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Distribution Centers Routing Map */}
        <div className="bg-surface rounded-xl shadow-sm border border-surface-variant overflow-hidden flex flex-col">
          <div className="px-6 py-4 border-b border-surface-variant bg-surface-container-lowest">
            <h2 className="text-headline-md text-on-surface flex items-center gap-2 font-semibold">
              <i className="ph ph-map-pin text-primary"></i>
              Distribution Center Routing
            </h2>
          </div>
          <div className="p-6 space-y-4">
            <p className="text-xs text-on-surface-variant">Orders placed by this node are routed based on regional logistics:</p>
            <div className="space-y-3">
              <div className="p-3 border border-surface-variant rounded-lg bg-surface-container-lowest flex justify-between items-center">
                <div>
                  <span className="text-xs font-bold text-on-surface">Regional DC 02 (Primary)</span>
                  <p className="text-[10px] text-on-surface-variant mt-0.5">Route: ap-south-1a (Zone Ingress)</p>
                </div>
                <span className="px-2.5 py-1 bg-secondary-container text-on-secondary-container text-[10px] font-bold rounded">
                  ACTIVE ROUTE
                </span>
              </div>
              <div className="p-3 border border-surface-variant rounded-lg bg-surface-container flex justify-between items-center opacity-65">
                <div>
                  <span className="text-xs font-bold text-on-surface-variant">Frankfurt Standby DC 04 (DR fallback)</span>
                  <p className="text-[10px] text-on-surface-variant mt-0.5">Route: eu-central-1a (Global Table)</p>
                </div>
                <span className="px-2.5 py-1 bg-surface-variant text-on-surface-variant/75 text-[10px] font-bold rounded">
                  STANDBY
                </span>
              </div>
            </div>
          </div>
        </div>

        {/* Security & Access Logs Audit */}
        <div className="bg-surface rounded-xl shadow-sm border border-surface-variant overflow-hidden flex flex-col">
          <div className="px-6 py-4 border-b border-surface-variant bg-surface-container-lowest">
            <h2 className="text-headline-md text-on-surface flex items-center gap-2 font-semibold">
              <i className="ph ph-shield-check text-primary"></i>
              Identity & Access Security Logs
            </h2>
          </div>
          <div className="p-6 space-y-4">
            <p className="text-xs text-on-surface-variant">Active user role mapping and recent session tokens audited by Cognito:</p>
            <div className="space-y-3 font-mono text-[11px] text-on-surface-variant bg-surface-container p-4 rounded-lg border border-surface-variant/30">
              <div>[COGNITO IDP] Session initialized for role: <span className="text-primary font-bold">store_manager</span></div>
              <div>[COGNITO IDP] ID Token verified at API Gateway edge proxy</div>
              <div>[AWS SEC] Secrets Manager database password decrypted successfully</div>
              <div>[X-RAY TRACE] Inbound routing mapped: api.smartretailx.internal --&gt; ALB Ingress</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
