import React from 'react';

export default function KpiCards({ products, loading }) {
  const totalProductsOnShelf = products.reduce((acc, p) => acc + (parseInt(p.quantity) || 0), 0);
  const lowStockAlertsCount = products.filter((p) => (parseInt(p.quantity) || 0) < 50).length;
  const pendingDeliveries = 3; // Baseline from specifications

  return (
    <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
      {/* Metric 1: Total Products */}
      <div className="bg-surface rounded-xl p-6 shadow-sm border border-surface-variant flex justify-between items-start relative overflow-hidden group hover:shadow-md transition-shadow">
        <div className="z-10">
          <h3 className="text-body-md font-medium text-on-surface-variant mb-1">Total Products on Shelf</h3>
          <div className="text-display-lg text-on-surface">
            {loading ? '...' : totalProductsOnShelf.toLocaleString()}
          </div>
        </div>
        <div className="w-12 h-12 bg-primary-container/20 text-primary rounded-xl flex items-center justify-center relative z-10 group-hover:scale-110 transition-transform">
          <i className="ph ph-clipboard-text text-2xl"></i>
        </div>
        {/* Decorative background icon */}
        <i className="ph ph-check-square absolute -bottom-4 -right-4 text-[100px] text-surface-container-high/50 opacity-40 z-0 transform rotate-12 group-hover:rotate-6 transition-transform"></i>
      </div>

      {/* Metric 2: Low Stock Alerts */}
      <div className="bg-error-container/10 rounded-xl p-6 shadow-sm border border-error-container flex justify-between items-start relative overflow-hidden group hover:shadow-md transition-shadow">
        <div className="z-10">
          <h3 className="text-body-md font-medium text-error mb-1">Low Stock Alerts</h3>
          <div className="text-display-lg text-error">
            {loading ? '...' : lowStockAlertsCount}
          </div>
        </div>
        <div className="w-12 h-12 bg-error-container text-on-error-container rounded-xl flex items-center justify-center relative z-10 group-hover:scale-110 transition-transform">
          <i className="ph ph-warning text-2xl"></i>
        </div>
        {/* Decorative background icon */}
        <i className="ph ph-warning absolute -bottom-4 -right-4 text-[100px] text-error-container/40 opacity-40 z-0 group-hover:scale-105 transition-transform"></i>
      </div>

      {/* Metric 3: Deliveries Pending */}
      <div className="bg-surface rounded-xl p-6 shadow-sm border border-surface-variant flex justify-between items-start relative overflow-hidden group hover:shadow-md transition-shadow">
        <div className="z-10">
          <h3 className="text-body-md font-medium text-on-surface-variant mb-1">Warehouse Deliveries Pending</h3>
          <div className="text-display-lg text-on-surface">3</div>
        </div>
        <div className="w-12 h-12 bg-blue-50 text-blue-600 rounded-xl flex items-center justify-center relative z-10 group-hover:scale-110 transition-transform">
          <i className="ph ph-truck text-2xl"></i>
        </div>
        {/* Decorative background icon */}
        <i className="ph ph-truck absolute -bottom-4 -right-4 text-[100px] text-surface-container-high/50 opacity-40 z-0 group-hover:-translate-x-2 transition-transform"></i>
      </div>
    </div>
  );
}
