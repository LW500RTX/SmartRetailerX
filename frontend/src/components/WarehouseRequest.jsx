import React, { useState } from 'react';

export default function WarehouseRequest({ orderItems, onRemoveItem, onPlaceOrder, isSubmitting }) {
  const [paymentMethod, setPaymentMethod] = useState('Digital Bank Transfer (Bank of Ceylon / Sampath Bank)');
  const totalCount = orderItems.reduce((sum, item) => sum + item.qty, 0);

  const handleSubmitOrder = () => {
    if (onPlaceOrder) {
      onPlaceOrder(paymentMethod);
    }
  };

  return (
    <div className="bg-surface-container-lowest rounded-xl shadow-sm border border-surface-variant overflow-hidden flex flex-col h-full min-h-[400px]">
      <div className="p-5 border-b border-surface-variant bg-surface-container-low text-left">
        <h3 className="font-headline-sm text-on-surface flex items-center gap-2 font-semibold">
          <i className="ph ph-shopping-bag text-primary text-lg"></i>
          Warehouse Request
        </h3>
        <p className="text-xs text-on-surface-variant mt-0.5">Assemble restocking order &amp; select settlement terms</p>
      </div>

      {/* Selected Items Scroll Area */}
      <div className="flex-1 overflow-y-auto p-4 space-y-3 min-h-[200px] max-h-[300px]">
        {orderItems.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-10 text-center space-y-2 opacity-50">
            <div className="w-12 h-12 bg-surface-container rounded-full flex items-center justify-center mb-2">
              <i className="ph ph-package text-2xl text-on-surface-variant"></i>
            </div>
            <p className="text-sm font-medium text-on-surface">No items selected.</p>
            <p className="text-xs text-on-surface-variant mt-1">Click "Select" or "+ Order" on products.</p>
          </div>
        ) : (
          orderItems.map((item) => (
            <div
              key={item.sku}
              className="flex items-center justify-between p-3 bg-surface-container rounded-lg border border-surface-variant/30 animate-in fade-in slide-in-from-right-4 duration-300"
            >
              <div className="flex-1 min-w-0 text-left">
                <p className="font-body-md font-bold truncate text-on-surface">{item.name}</p>
                <p className="text-xs text-on-surface-variant mt-0.5">Qty: {item.qty} units</p>
              </div>
              <button
                onClick={() => onRemoveItem(item.sku)}
                className="p-1 hover:bg-error-container/20 rounded-full text-error transition-colors cursor-pointer"
                title="Remove item"
              >
                <i className="ph ph-x text-lg"></i>
              </button>
            </div>
          ))
        )}
      </div>

      {/* Payment Selector & Action / Submit Area */}
      <div className="p-5 border-t border-surface-variant/30 space-y-4 bg-surface-container-lowest mt-auto text-left">
        <div className="flex justify-between items-center font-bold">
          <span className="text-xs text-on-surface-variant uppercase tracking-wider font-semibold">Total Items</span>
          <span className="font-headline-sm text-primary animate-pulse text-lg">
            {totalCount}
          </span>
        </div>

        {/* Payment Method Selector */}
        <div className="space-y-1.5">
          <label className="text-[11px] font-bold text-on-surface-variant uppercase tracking-wider block">
            Payment Method
          </label>
          <select
            value={paymentMethod}
            onChange={(e) => setPaymentMethod(e.target.value)}
            className="w-full p-2.5 bg-surface border border-surface-variant rounded-lg text-xs text-on-surface outline-none focus:ring-1 focus:ring-primary cursor-pointer font-medium"
          >
            <option value="Digital Bank Transfer (Bank of Ceylon / Sampath Bank)">
              🏦 Digital Bank Transfer (Bank of Ceylon / Sampath Bank)
            </option>
            <option value="Corporate Account Terms (Net-30 Credit Line)">
              🏢 Corporate Account Terms (Net-30 Credit Line)
            </option>
            <option value="Cash on Delivery (COD)">
              💵 Cash on Delivery (COD)
            </option>
          </select>
        </div>

        <button
          onClick={handleSubmitOrder}
          disabled={orderItems.length === 0 || isSubmitting}
          className={`w-full font-bold py-3.5 rounded-lg flex items-center justify-center space-x-2 transition-all shadow-sm cursor-pointer ${
            orderItems.length === 0 || isSubmitting
              ? 'bg-surface-variant text-on-surface-variant/50 cursor-not-allowed'
              : 'bg-primary text-on-primary hover:bg-primary/95 active:scale-95'
          }`}
        >
          {isSubmitting ? (
            <>
              <span className="spinner animate-spin border-2 border-on-primary border-t-transparent w-4 h-4 rounded-full mr-2"></span>
              <span>Transmitting Request...</span>
            </>
          ) : (
            <>
              <i className="ph ph-paper-plane-right text-lg"></i>
              <span>Request Warehouse Stock</span>
            </>
          )}
        </button>
        <p className="text-[10px] text-center text-on-surface-variant uppercase tracking-wider">
          Order will be routed to Regional Distribution Center 02
        </p>
      </div>
    </div>
  );
}
