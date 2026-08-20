import React from 'react';

export default function SreTelemetry({ isBreakerTripped, onToggleOutage, sreMetrics }) {
  const servicesList = [
    { name: 'User Management', status: 'HEALTHY' },
    { name: 'Product Catalogue', status: 'HEALTHY' },
    { name: 'Order Processing', status: 'HEALTHY' },
    { name: 'Payment Gateway', status: 'HEALTHY' },
    { name: 'Inventory Engine', status: 'HEALTHY' },
    { name: 'Notification Service', status: isBreakerTripped ? 'TRIPPED' : 'HEALTHY' },
  ];

  return (
    <section className="bg-surface rounded-xl shadow-sm border border-surface-variant p-6 space-y-4">
      <div className="flex justify-between items-center pb-2 border-b border-surface-variant/20">
        <h3 className="text-headline-md text-on-surface flex items-center gap-2 font-semibold">
          <i className="ph ph-chart-line-up text-primary text-xl"></i>
          AWS EKS & SRE Telemetry Cockpit
        </h3>
        <div className="flex items-center gap-2 bg-surface-container-high px-3 py-1.5 rounded-full border border-surface-variant/30">
          <span className={`w-2.5 h-2.5 rounded-full ${isBreakerTripped ? 'bg-red-500 animate-pulse' : 'bg-green-500 animate-pulse'}`}></span>
          <span className="text-[11px] font-bold text-on-surface-variant uppercase tracking-wider">
            {isBreakerTripped ? 'Degraded (Outage Event)' : 'Staging Nominal'}
          </span>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="bg-surface-container-lowest p-3 rounded-lg flex flex-col justify-between border border-surface-variant/30">
          <span className="text-[10px] font-bold uppercase tracking-wider text-on-surface-variant">API Gateway Latency (p95)</span>
          <span className="text-xl font-bold text-primary mt-1">{sreMetrics.apiLatency}</span>
        </div>
        <div className="bg-surface-container-lowest p-3 rounded-lg flex flex-col justify-between border border-surface-variant/30">
          <span className="text-[10px] font-bold uppercase tracking-wider text-on-surface-variant">CloudWatch HTTP 5XX Rate</span>
          <span className={`text-xl font-bold mt-1 ${isBreakerTripped ? 'text-red-600' : 'text-[#006d48]'}`}>
            {sreMetrics.errorRate}
          </span>
        </div>
        <div className="bg-surface-container-lowest p-3 rounded-lg flex flex-col justify-between border border-surface-variant/30">
          <span className="text-[10px] font-bold uppercase tracking-wider text-on-surface-variant">Active WebSocket Traces</span>
          <span className="text-xl font-bold text-on-surface mt-1">{sreMetrics.activeConnections}</span>
        </div>
        <div className="bg-surface-container-lowest p-3 rounded-lg flex flex-col justify-between border border-surface-variant/30">
          <span className="text-[10px] font-bold uppercase tracking-wider text-on-surface-variant">SRE Simulation Control</span>
          <button
            onClick={onToggleOutage}
            className={`mt-1 py-1.5 px-3 text-[10px] font-bold uppercase rounded text-center transition-all shadow-sm ${
              isBreakerTripped
                ? 'bg-green-600 hover:bg-green-700 text-white'
                : 'bg-danger-600 hover:bg-danger-700 text-white'
            }`}
          >
            {isBreakerTripped ? 'Clear Outage' : 'Simulate Outage'}
          </button>
        </div>
      </div>

      {/* Service Status Map */}
      <div className="grid grid-cols-2 sm:grid-cols-6 gap-2 pt-2 text-center">
        {servicesList.map((srv) => (
          <div key={srv.name} className="p-2 bg-surface-container-lowest rounded border border-surface-variant/30 flex flex-col justify-between">
            <span className="text-[9px] truncate text-on-surface-variant font-semibold uppercase">{srv.name}</span>
            <span className={`text-[10px] font-bold mt-1 ${
              srv.status === 'HEALTHY'
                ? 'text-[#006d48]'
                : 'text-red-600 animate-pulse'
            }`}>
              {srv.status}
            </span>
          </div>
        ))}
      </div>
    </section>
  );
}
