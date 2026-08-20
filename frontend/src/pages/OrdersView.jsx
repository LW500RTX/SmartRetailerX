import React, { useState, useEffect } from 'react';
import axios from 'axios';

export default function OrdersView({ userEmail, token, showToast, API_BASE_URL, ORDER_API_BASE_URL, products }) {
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(false);
  const [updatingId, setUpdatingId] = useState(null);

  // Fetch orders from order-service backend
  const fetchOrders = async () => {
    setLoading(true);
    try {
      const response = await axios.get(`${ORDER_API_BASE_URL}/api/v1/orders`, {
        headers: {
          'Authorization': `Bearer ${token || 'mock-dev-token'}`
        }
      });
      setOrders(response.data || []);
    } catch (err) {
      console.warn('Orders tracking notice:', err.message);
      if (err.message === 'Network Error') {
        showToast('warning', 'Order processing service initializing on port 8000...');
      } else {
        showToast('error', err.response?.data?.detail || err.message || 'Failed to retrieve orders.');
      }
      setOrders([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchOrders();
  }, []);

  const handleUpdateDelivery = async (orderId, newStatus) => {
    setUpdatingId(orderId);
    try {
      const response = await axios.post(
        `${ORDER_API_BASE_URL}/api/v1/orders/${orderId}/delivery`,
        { status: newStatus },
        {
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${token}`
          }
        }
      );
      
      showToast('success', response.data.message || 'EventBridge delivery event dispatched.');
      
      // Update local status representation
      setOrders(prev => prev.map(o => o.id === orderId ? { ...o, status: newStatus } : o));
    } catch (err) {
      console.error('Failed to update delivery:', err);
      showToast('error', err.response?.data?.detail || err.message || 'Failed to dispatch delivery update.');
    } finally {
      setUpdatingId(null);
    }
  };

  const getStatusBadge = (status) => {
    const s = status ? status.toLowerCase() : 'pending';
    if (s === 'delivered') {
      return <span className="px-2.5 py-1 rounded text-xs font-semibold bg-[#D1FAE5] text-[#065F46]">DELIVERED</span>;
    }
    if (s === 'shipped') {
      return <span className="px-2.5 py-1 rounded text-xs font-semibold bg-blue-100 text-blue-700">SHIPPED</span>;
    }
    if (s === 'processing') {
      return <span className="px-2.5 py-1 rounded text-xs font-semibold bg-yellow-100 text-yellow-800 animate-pulse">PROCESSING</span>;
    }
    return <span className="px-2.5 py-1 rounded text-xs font-semibold bg-gray-100 text-gray-600">PENDING</span>;
  };

  const getProductName = (prodId) => {
    const p = products.find(prod => prod.id === prodId || prod.sku === prodId);
    return p ? p.name : prodId;
  };

  return (
    <div className="bg-surface rounded-xl shadow-sm border border-surface-variant overflow-hidden flex flex-col w-full text-left">
      <div className="px-6 py-5 border-b border-surface-variant flex items-center justify-between bg-surface-container-lowest">
        <div>
          <h2 className="text-headline-md text-on-surface font-semibold">Orders Tracking</h2>
          <p className="text-xs text-on-surface-variant mt-0.5">Track restocking requests, processing stages, and dispatch delivery events</p>
        </div>
        <button
          onClick={fetchOrders}
          className="p-2 hover:bg-surface-variant rounded-full transition-colors"
          title="Reload orders"
        >
          <i className="ph ph-arrows-clockwise text-lg"></i>
        </button>
      </div>

      <div className="overflow-x-auto bg-surface-container-lowest">
        <table className="min-w-full w-full text-left whitespace-nowrap">
          <thead className="bg-surface-container text-on-surface-variant text-[11px] font-bold uppercase tracking-wider">
            <tr>
              <th className="px-6 py-4 w-1/12 font-semibold">Order ID</th>
              <th className="px-6 py-4 w-2/5 font-semibold">Product Name</th>
              <th className="px-6 py-4 w-1/12 text-center font-semibold">Quantity</th>
              <th className="px-6 py-4 w-1/12 text-right font-semibold">Total Amount</th>
              <th className="px-6 py-4 w-1/5 font-semibold">Date Placed</th>
              <th className="px-6 py-4 w-1/12 font-semibold">Status</th>
              <th className="px-6 py-4 w-1/5 text-right font-semibold">Dispatch Control</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-surface-variant">
            {loading ? (
              <tr>
                <td colSpan="7" className="text-center py-10 text-on-surface-variant">
                  Loading orders log...
                </td>
              </tr>
            ) : orders.length === 0 ? (
              <tr>
                <td colSpan="7" className="text-center py-10 text-on-surface-variant font-medium">
                  No restocking orders registered in database.
                </td>
              </tr>
            ) : (
              orders.map((order) => (
                <tr key={order.id} className="hover:bg-surface-container-low transition-colors">
                  <td className="px-6 py-4 text-xs font-mono font-semibold text-on-surface">#{order.id}</td>
                  <td className="px-6 py-4">
                    <div>
                      <div className="font-semibold text-body-md text-on-surface">
                        {getProductName(order.product_id)}
                      </div>
                      <div className="text-xs text-on-surface-variant mt-0.5 font-mono">
                        UID: {order.product_id}
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4 text-xs font-mono text-center">{order.quantity}</td>
                  <td className="px-6 py-4 text-xs font-mono text-on-surface text-right">${(parseFloat(order.total_amount) || 0).toFixed(2)}</td>
                  <td className="px-6 py-4 text-xs text-on-surface-variant">
                    {new Date(order.created_at).toLocaleString()}
                  </td>
                  <td className="px-6 py-4">{getStatusBadge(order.status)}</td>
                  <td className="px-6 py-4 text-right">
                    <select
                      disabled={updatingId === order.id}
                      value={order.status || 'Pending'}
                      onChange={(e) => handleUpdateDelivery(order.id, e.target.value)}
                      className="text-xs bg-surface border border-surface-variant rounded px-2 py-1 outline-none cursor-pointer focus:ring-1 focus:ring-primary disabled:opacity-50"
                    >
                      <option value="Pending" disabled>Pending</option>
                      <option value="Processing">Processing</option>
                      <option value="Shipped">Shipped</option>
                      <option value="Delivered">Delivered</option>
                    </select>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
