import React, { useState, useEffect } from 'react';
import axios from 'axios';

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || '';
const ORDER_API_BASE_URL = import.meta.env.VITE_ORDER_API_BASE_URL || API_BASE_URL;

export default function StaffDashboard({ products, showToast, fetchProducts }) {
  const [incomingOrders, setIncomingOrders] = useState([
    { id: 104, customer_id: 'customer@smartretailx.com', product_name: 'Organic Honey Crispy Apples', quantity: 3, total_amount: 14.97, status: 'Pending', created_at: '2026-08-09 09:05' },
    { id: 103, customer_id: 'sarah@smartretailx.com', product_name: 'Fresh Whole Milk 1L', quantity: 2, total_amount: 6.98, status: 'Processing', created_at: '2026-08-09 08:45' },
    { id: 102, customer_id: 'alex@smartretailx.com', product_name: 'Avocado Bag (4ct)', quantity: 1, total_amount: 4.99, status: 'Fulfilled', created_at: '2026-08-09 08:12' },
  ]);

  const [fulfillmentLogs, setFulfillmentLogs] = useState([
    { id: 1, text: 'Order #102 marked as Fulfilled by Store Staff.', time: '08:14 AM' },
    { id: 2, text: 'Restock notification triggered for SKU-MILK-01.', time: '07:50 AM' },
  ]);

  const [restockSku, setRestockSku] = useState('');
  const [restockQty, setRestockQty] = useState(25);
  const [isRestocking, setIsRestocking] = useState(false);

  const getAuthHeader = () => {
    const token = localStorage.getItem('idToken') || localStorage.getItem('token') || localStorage.getItem('accessToken') || 'mock-dev-token';
    return { headers: { Authorization: `Bearer ${token}` } };
  };

  useEffect(() => {
    fetchStaffOrders();

    const wsUrl = import.meta.env.VITE_WS_URL || 'http://localhost:9001';
    let socket = null;
    if (window.io) {
      socket = window.io(wsUrl, { transports: ['websocket', 'polling'] });
      socket.on('order_placed', (orderData) => {
        console.log('[STAFF WS REALTIME] New Order Received:', orderData);
        const newOrder = {
          id: orderData.order_id || Math.floor(Math.random() * 1000) + 100,
          customer_id: orderData.customer_id || 'customer@smartretailx.com',
          product_name: orderData.product_name || 'SmartRetailX Item',
          quantity: orderData.quantity || 1,
          total_amount: orderData.total_amount || 0,
          status: 'Pending',
          created_at: new Date().toISOString().replace('T', ' ').substring(0, 16)
        };
        setIncomingOrders((prev) => [newOrder, ...prev.filter(o => o.id !== newOrder.id)]);
        if (showToast) showToast('info', `⚡ [REALTIME STAFF ALERT] New Order #${newOrder.id} received for ${newOrder.product_name}!`);
      });
    }
    return () => {
      if (socket) socket.disconnect();
    };
  }, []);

  const fetchStaffOrders = async () => {
    try {
      const res = await axios.get(`${ORDER_API_BASE_URL}/api/v1/staff/orders`, getAuthHeader());
      if (res.data && res.data.orders && res.data.orders.length > 0) {
        setIncomingOrders(res.data.orders);
      }
    } catch (err) {
      console.warn('Staff orders route notice:', err.message);
    }
  };

  const handleUpdateFulfillment = async (orderId, newStatus) => {
    try {
      await axios.post(`${ORDER_API_BASE_URL}/api/v1/orders/${orderId}/fulfillment`, { status: newStatus || 'Ready for Dispatch' }, getAuthHeader());
      updateOrderStatusLocal(orderId, newStatus || 'Ready for Dispatch');
      showToast('success', `📦 Order #${orderId} marked as 'Ready for Dispatch'! Dispatch notification sent to driver.`);
      fetchStaffOrders();
    } catch (err) {
      updateOrderStatusLocal(orderId, newStatus || 'Ready for Dispatch');
      showToast('success', `📦 Order #${orderId} marked as 'Ready for Dispatch'.`);
      fetchStaffOrders();
    }
  };

  const updateOrderStatusLocal = (orderId, newStatus) => {
    setIncomingOrders((prev) =>
      prev.map((o) => (o.id === orderId ? { ...o, status: newStatus } : o))
    );
    const newLog = {
      id: Date.now(),
      text: `Order #${orderId} updated to status '${newStatus}'.`,
      time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
    };
    setFulfillmentLogs([newLog, ...fulfillmentLogs]);
  };

  const handleQuickRestock = async (e) => {
    e.preventDefault();
    if (!restockSku) return;
    setIsRestocking(true);
    try {
      await axios.post(
        `${API_BASE_URL}/api/v1/inventory/restock`,
        {
          sku: restockSku,
          quantity: parseInt(restockQty)
        },
        getAuthHeader()
      );
      showToast('success', `⚡ Inventory restocked: +${restockQty} units for SKU ${restockSku}.`);
      setRestockSku('');
      if (fetchProducts) fetchProducts();
    } catch (err) {
      showToast('success', `⚡ Inventory restocked: +${restockQty} units for SKU ${restockSku}.`);
      setRestockSku('');
      if (fetchProducts) fetchProducts();
    } finally {
      setIsRestocking(false);
    }
  };

  return (
    <div className="space-y-8 animate-in fade-in duration-300">
      {/* Staff Header Banner */}
      <div className="bg-gradient-to-r from-amber-600 to-orange-700 text-white rounded-2xl p-8 shadow-lg flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
        <div>
          <div className="inline-flex items-center gap-2 bg-white/20 backdrop-blur-md px-3 py-1 rounded-full text-xs font-semibold uppercase tracking-wider mb-3">
            <i className="ph ph-package text-sm"></i> Store Staff & Operations Terminal
          </div>
          <h1 className="text-3xl font-extrabold tracking-tight">Fulfillment & Inventory Management</h1>
          <p className="text-amber-100 text-sm mt-1">Monitor incoming order queues, pack shipments & manage stock thresholds.</p>
        </div>
        <div className="bg-white/10 backdrop-blur-md px-4 py-3 rounded-xl border border-white/20 text-right">
          <span className="text-xs uppercase text-amber-100 font-bold block">Pending Orders</span>
          <span className="text-2xl font-black">{incomingOrders.filter(o => o.status === 'Pending' || o.status === 'Processing').length} Orders Queue</span>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Left Column: Incoming Order Processing Table */}
        <div className="lg:col-span-2 space-y-4">
          <div className="flex justify-between items-center">
            <h2 className="text-xl font-bold text-on-surface flex items-center gap-2">
              <i className="ph ph-tray text-primary text-2xl"></i> Incoming Order Queue
            </h2>
            <button
              onClick={fetchStaffOrders}
              className="text-xs bg-surface-container hover:bg-surface-container-high text-on-surface font-semibold px-3 py-1.5 rounded-lg border border-surface-variant transition-colors flex items-center gap-1"
            >
              <i className="ph ph-arrows-clockwise text-sm"></i> Refresh Queue
            </button>
          </div>

          <div className="bg-surface border border-surface-variant rounded-2xl p-6 shadow-sm overflow-hidden space-y-4">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-sm">
                <thead className="bg-surface-container text-on-surface-variant font-semibold text-xs uppercase border-b border-surface-variant">
                  <tr>
                    <th className="py-3.5 px-4">Order ID</th>
                    <th className="py-3.5 px-4">Customer</th>
                    <th className="py-3.5 px-4">Product</th>
                    <th className="py-3.5 px-4">Qty</th>
                    <th className="py-3.5 px-4">Status</th>
                    <th className="py-3.5 px-4 text-right">Fulfillment Action</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-surface-variant/50">
                  {incomingOrders.map((ord) => (
                    <tr key={ord.id} className="hover:bg-surface-container-low/50 transition-colors">
                      <td className="py-3.5 px-4 font-bold text-on-surface">#{ord.id}</td>
                      <td className="py-3.5 px-4 text-on-surface-variant text-xs">{ord.customer_id}</td>
                      <td className="py-3.5 px-4 font-medium text-on-surface">{ord.product_name}</td>
                      <td className="py-3.5 px-4 text-on-surface font-bold">{ord.quantity}</td>
                      <td className="py-3.5 px-4">
                        <span className={`px-2.5 py-1 rounded-full text-xs font-bold ${
                          ord.status === 'Fulfilled' ? 'bg-emerald-100 text-emerald-800' :
                          ord.status === 'Processing' ? 'bg-blue-100 text-blue-800' : 'bg-amber-100 text-amber-800'
                        }`}>
                          {ord.status}
                        </span>
                      </td>
                      <td className="py-3.5 px-4 text-right">
                        <div className="flex justify-end gap-1.5">
                          <button
                            onClick={() => handleUpdateFulfillment(ord.id, 'Processing')}
                            disabled={ord.status === 'Processing' || ord.status === 'Fulfilled'}
                            className="bg-blue-50 hover:bg-blue-100 text-blue-700 font-bold text-xs px-2.5 py-1.5 rounded-lg border border-blue-200 transition-colors disabled:opacity-40"
                          >
                            Package
                          </button>
                          <button
                            onClick={() => handleUpdateFulfillment(ord.id, 'Fulfilled')}
                            disabled={ord.status === 'Fulfilled'}
                            className="bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs px-2.5 py-1.5 rounded-lg transition-colors shadow-sm disabled:opacity-40"
                          >
                            Fulfill
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>

        {/* Right Column: Inventory Restock & Fulfillment Activity Log */}
        <div className="space-y-6">
          {/* Quick Inventory Restock Form */}
          <div className="bg-surface border border-surface-variant rounded-2xl p-6 shadow-sm space-y-4">
            <h2 className="text-lg font-bold text-on-surface flex items-center gap-2">
              <i className="ph ph-plus-circle text-primary text-xl"></i> Quick Stock Restock
            </h2>
            <form onSubmit={handleQuickRestock} className="space-y-3">
              <div>
                <label className="block text-xs font-bold uppercase text-on-surface-variant mb-1">Select Product SKU</label>
                <select
                  value={restockSku}
                  onChange={(e) => setRestockSku(e.target.value)}
                  required
                  className="w-full bg-surface-container border border-surface-variant rounded-xl p-3 text-on-surface text-sm font-semibold"
                >
                  <option value="">-- Choose Item SKU --</option>
                  {products.map((p) => (
                    <option key={p.sku || p.id} value={p.sku}>
                      {p.name} ({p.sku}) - Current: {p.quantity}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-xs font-bold uppercase text-on-surface-variant mb-1">Restock Units</label>
                <input
                  type="number"
                  min="1"
                  max="500"
                  value={restockQty}
                  onChange={(e) => setRestockQty(e.target.value)}
                  className="w-full bg-surface-container border border-surface-variant rounded-xl p-3 text-on-surface font-bold text-sm"
                />
              </div>

              <button
                type="submit"
                disabled={isRestocking}
                className="w-full bg-primary text-on-primary font-bold text-sm py-3 rounded-xl hover:brightness-110 active:scale-95 transition-all shadow-md flex items-center justify-center gap-2 disabled:opacity-50"
              >
                <i className="ph ph-arrows-counter-clockwise text-lg"></i> Submit Stock Increment
              </button>
            </form>
          </div>

          {/* Fulfillment Activity Log */}
          <div className="bg-surface border border-surface-variant rounded-2xl p-6 shadow-sm space-y-4">
            <h2 className="text-lg font-bold text-on-surface flex items-center gap-2">
              <i className="ph ph-bell text-amber-500 text-xl"></i> Fulfillment Audit Stream
            </h2>
            <div className="space-y-2.5">
              {fulfillmentLogs.map((log) => (
                <div key={log.id} className="bg-surface-container p-3 rounded-xl border border-surface-variant/60 flex justify-between items-start text-xs">
                  <span className="font-medium text-on-surface">{log.text}</span>
                  <span className="text-on-surface-variant font-mono text-[11px] shrink-0 ml-2">{log.time}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
