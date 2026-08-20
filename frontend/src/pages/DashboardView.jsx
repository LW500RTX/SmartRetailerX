import React from 'react';
import KpiCards from '../components/KpiCards';
import SreTelemetry from '../components/SreTelemetry';
import WarehouseRequest from '../components/WarehouseRequest';

export default function DashboardView({
  products,
  loading,
  isBreakerTripped,
  onToggleOutage,
  sreMetrics,
  orderItems,
  onRemoveItem,
  onPlaceOrder,
  isSubmitting,
  onAddToOrder,
}) {
  // Stock status helper
  const getStockBadge = (qty) => {
    if (qty === 0) {
      return <span className="inline-flex items-center px-2.5 py-1 rounded-md text-[10px] font-bold bg-[#F3F4F6] text-[#1F2937]">OUT OF STOCK</span>;
    }
    if (qty < 10) {
      return (
        <span className="inline-flex items-center px-2.5 py-1 rounded-md text-[10px] font-bold bg-error text-on-error shadow-sm">
          <i className="ph ph-warning-circle mr-1 text-xs"></i> CRITICAL
        </span>
      );
    }
    if (qty < 50) {
      return <span className="inline-flex items-center px-2.5 py-1 rounded-md text-[10px] font-bold bg-warning-100 text-warning-600 border border-warning-200">LOW</span>;
    }
    return <span className="inline-flex items-center px-2.5 py-1 rounded-md text-[10px] font-bold bg-secondary-container text-on-secondary-container">GOOD</span>;
  };

  return (
    <div className="space-y-6 max-w-7xl mx-auto w-full text-left">
      {/* KPIs Display */}
      <KpiCards products={products} loading={loading} />

      {/* SRE Cockpit */}
      <SreTelemetry
        isBreakerTripped={isBreakerTripped}
        onToggleOutage={onToggleOutage}
        sreMetrics={sreMetrics}
      />

      {/* AI Predictions & Flow Insights */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* AI Inventory Predictions */}
        <div className="bg-surface rounded-xl shadow-sm border border-surface-variant overflow-hidden flex flex-col">
          <div className="px-6 py-4 border-b border-surface-variant flex items-center justify-between bg-surface-container-lowest">
            <h2 className="text-headline-md text-on-surface flex items-center gap-2 font-semibold">
              <i className="ph ph-magic-wand text-primary"></i>
              AI Inventory Predictions
            </h2>
            <span className="px-2.5 py-1 rounded-full text-xs font-semibold bg-secondary-container text-on-secondary-container flex items-center space-x-1">
              <span className="w-2 h-2 rounded-full bg-primary animate-pulse"></span>
              <span>LIVE MODEL</span>
            </span>
          </div>
          <div className="p-6 flex-1 space-y-4">
            <p className="text-body-md text-on-surface-variant">Suggested to Order based on consumption frequency & trends.</p>
            <div className="space-y-3">
              {/* AI Item 1 */}
              <div className="flex items-center justify-between p-3 rounded-lg border border-surface-variant bg-surface-container-lowest hover:bg-surface-container-low transition-colors">
                <div className="flex items-center space-x-3">
                  <div className="w-10 h-10 rounded-md bg-surface-container flex items-center justify-center shrink-0">
                    <i className="ph ph-coffee text-xl text-on-surface-variant"></i>
                  </div>
                  <div>
                    <div className="font-semibold text-body-md text-on-surface">Whole Bean Coffee</div>
                    <div className="text-xs text-on-surface-variant mt-0.5">Confidence: <span className="text-primary font-bold">92%</span></div>
                  </div>
                </div>
                <div className="text-right">
                  <div className="text-xs text-outline mb-1 uppercase tracking-wider font-bold">Suggested Qty</div>
                  <div className="font-bold text-on-surface text-lg">24 units</div>
                </div>
              </div>
              {/* AI Item 2 */}
              <div className="flex items-center justify-between p-3 rounded-lg border border-surface-variant bg-surface-container-lowest hover:bg-surface-container-low transition-colors">
                <div className="flex items-center space-x-3">
                  <div className="w-10 h-10 rounded-md bg-surface-container flex items-center justify-center shrink-0">
                    <i className="ph ph-carrot text-xl text-on-surface-variant"></i>
                  </div>
                  <div>
                    <div className="font-semibold text-body-md text-on-surface">Organic Carrots</div>
                    <div className="text-xs text-on-surface-variant mt-0.5">Confidence: <span className="text-primary font-bold">88%</span></div>
                  </div>
                </div>
                <div className="text-right">
                  <div className="text-xs text-outline mb-1 uppercase tracking-wider font-bold">Suggested Qty</div>
                  <div className="font-bold text-on-surface text-lg">15 kg</div>
                </div>
              </div>
              {/* AI Item 3 */}
              <div className="flex items-center justify-between p-3 rounded-lg border border-surface-variant bg-surface-container-lowest hover:bg-surface-container-low transition-colors">
                <div className="flex items-center space-x-3">
                  <div className="w-10 h-10 rounded-md bg-surface-container flex items-center justify-center shrink-0">
                    <i className="ph ph-egg text-xl text-on-surface-variant"></i>
                  </div>
                  <div>
                    <div className="font-semibold text-body-md text-on-surface">Free Range Eggs (Dozen)</div>
                    <div className="text-xs text-on-surface-variant mt-0.5">Confidence: <span className="text-primary font-bold">85%</span></div>
                  </div>
                </div>
                <div className="text-right">
                  <div className="text-xs text-outline mb-1 uppercase tracking-wider font-bold">Suggested Qty</div>
                  <div className="font-bold text-on-surface text-lg">30 units</div>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Inventory Flow Visualization */}
        <div className="bg-surface rounded-xl shadow-sm border border-surface-variant overflow-hidden flex flex-col">
          <div className="px-6 py-4 border-b border-surface-variant bg-surface-container-lowest">
            <h2 className="text-headline-md text-on-surface flex items-center gap-2 font-semibold">
              <i className="ph ph-chart-polar text-primary"></i>
              Inventory Flow
            </h2>
          </div>
          <div className="p-6 flex-1 flex flex-col justify-center">
            <div className="text-body-md text-on-surface-variant mb-6 text-center">Incoming vs Shelf Consumption (Past 7 Days)</div>
            {/* Flow Chart Diagram */}
            <div className="flex items-center justify-between relative px-4">
              <div className="absolute top-1/2 left-0 w-full h-1 bg-surface-variant -translate-y-1/2 z-0 rounded-full"></div>
              <div className="absolute top-1/2 left-[20%] right-[20%] h-1 bg-gradient-to-r from-blue-400 to-primary -translate-y-1/2 z-0 rounded-full opacity-70"></div>
              {/* Warehouse Node */}
              <div className="relative z-10 flex flex-col items-center">
                <div className="w-16 h-16 bg-blue-50 border-2 border-blue-200 rounded-full flex items-center justify-center shadow-sm mb-3">
                  <i className="ph ph-warehouse text-2xl text-blue-600"></i>
                </div>
                <div className="text-center">
                  <div className="text-body-md font-bold text-on-surface">450 units</div>
                  <div className="text-xs text-on-surface-variant mt-1">Incoming</div>
                </div>
              </div>
              {/* Flow indicator */}
              <div className="relative z-10 bg-surface px-2">
                <i className="ph ph-arrow-right text-2xl text-primary animate-pulse"></i>
              </div>
              {/* Shelf Node */}
              <div className="relative z-10 flex flex-col items-center">
                <div className="w-16 h-16 bg-primary-container/20 border-2 border-primary-container/50 rounded-full flex items-center justify-center shadow-sm mb-3">
                  <i className="ph ph-storefront text-2xl text-primary"></i>
                </div>
                <div className="text-center">
                  <div className="text-body-md font-bold text-on-surface">380 units</div>
                  <div className="text-xs text-on-surface-variant mt-1">Consumed</div>
                </div>
              </div>
            </div>
            {/* Stats list */}
            <div className="mt-8 grid grid-cols-2 gap-4 pt-6 border-t border-surface-variant/50">
              <div className="text-center">
                <div className="text-xs text-outline uppercase tracking-wider font-semibold mb-1">Net Flow Rate</div>
                <div className="text-body-lg font-bold text-primary">+15% / week</div>
              </div>
              <div className="text-center border-l border-surface-variant/50">
                <div className="text-xs text-outline uppercase tracking-wider font-semibold mb-1">Shelf Turnover</div>
                <div className="text-body-lg font-bold text-on-surface">2.4 days</div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Main Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left Column (Quick live inventory table) */}
        <div className="lg:col-span-2 flex flex-col bg-surface rounded-xl shadow-sm border border-surface-variant overflow-hidden">
          <div className="px-6 py-4 border-b border-surface-variant flex items-center justify-between bg-surface-container-lowest">
            <h2 className="text-headline-md text-on-surface font-semibold">Live Inventory Monitoring</h2>
          </div>
          <div className="overflow-x-auto flex-1 bg-surface-container-lowest">
            <table className="min-w-full w-full text-left whitespace-nowrap">
              <thead className="bg-surface-container text-on-surface-variant text-[11px] font-bold uppercase tracking-wider">
                <tr>
                  <th className="px-6 py-4 w-2/5 font-semibold">Product Name</th>
                  <th className="px-6 py-4 w-1/5 font-semibold">SKU</th>
                  <th className="px-6 py-4 w-1/5 font-semibold">Category</th>
                  <th className="px-6 py-4 w-1/12 text-right font-semibold">Price</th>
                  <th className="px-6 py-4 w-1/12 font-semibold">Stock Level</th>
                  <th className="px-6 py-4 w-1/12"></th>
                </tr>
              </thead>
              <tbody className="divide-y divide-surface-variant">
                {loading ? (
                  <tr>
                    <td colSpan="6" className="text-center py-10 text-on-surface-variant">
                      Loading catalogue data...
                    </td>
                  </tr>
                ) : (
                  products.slice(0, 5).map((product) => (
                    <tr key={product.id} className="hover:bg-surface-container-low transition-colors group">
                      <td className="px-6 py-4">
                        <div className="flex items-center space-x-4">
                          <img
                            alt={product.name}
                            className="w-10 h-10 rounded-lg object-cover border border-surface-variant shadow-sm"
                            src={product.image}
                          />
                          <span className="font-semibold text-body-lg text-on-surface group-hover:text-primary transition-colors">
                            {product.name}
                          </span>
                        </div>
                      </td>
                      <td className="px-6 py-4 text-xs font-mono text-on-surface-variant">{product.sku}</td>
                      <td className="px-6 py-4 text-body-md text-on-surface-variant">{product.category}</td>
                      <td className="px-6 py-4 text-xs font-mono text-on-surface text-right">${(parseFloat(product.price) || 0).toFixed(2)}</td>
                      <td className="px-6 py-4">{getStockBadge(parseInt(product.quantity) || 0)}</td>
                      <td className="px-6 py-4 text-right">
                        <button
                          onClick={() => onAddToOrder(product)}
                          className="text-primary font-bold text-xs hover:underline cursor-pointer"
                        >
                          Select
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>

        {/* Right Column (Warehouse Order Cart) */}
        <div>
          <WarehouseRequest
            orderItems={orderItems}
            onRemoveItem={onRemoveItem}
            onPlaceOrder={onPlaceOrder}
            isSubmitting={isSubmitting}
          />
        </div>
      </div>
    </div>
  );
}
