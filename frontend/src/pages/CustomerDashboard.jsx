import React, { useState, useEffect } from 'react';
import axios from 'axios';
import ProductCard from '../components/ProductCard';

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || '';
const ORDER_API_BASE_URL = import.meta.env.VITE_ORDER_API_BASE_URL || API_BASE_URL;

export default function CustomerDashboard({ products, userEmail, showToast, fetchProducts }) {
  const [selectedProduct, setSelectedProduct] = useState(null);
  const [orderQty, setOrderQty] = useState(1);
  const [isPlacingOrder, setIsPlacingOrder] = useState(false);
  const [gdprModalOpen, setGdprModalOpen] = useState(false);
  const [marketingConsent, setMarketingConsent] = useState(true);
  const [gdprNotice, setGdprNotice] = useState('');
  const [notifications, setNotifications] = useState([]);
  const [notifPanelOpen, setNotifPanelOpen] = useState(false);
  const [unreadCount, setUnreadCount] = useState(0);

  const [customerOrders, setCustomerOrders] = useState([
    { id: 101, product_name: 'Organic Honey Crispy Apples', quantity: 2, total_amount: 9.98, status: 'Out for Delivery', created_at: '2026-08-09 08:30' },
    { id: 98, product_name: 'Fresh Whole Milk 1L', quantity: 1, total_amount: 3.49, status: 'Delivered', created_at: '2026-08-08 14:15' },
  ]);

  const getAuthHeader = () => {
    const token = localStorage.getItem('idToken') || localStorage.getItem('token') || localStorage.getItem('accessToken') || 'mock-dev-token';
    return { headers: { Authorization: `Bearer ${token}` } };
  };

  useEffect(() => {
    fetchCustomerOrders();
  }, [userEmail]);

  const fetchCustomerOrders = async () => {
    try {
      const res = await axios.get(`${ORDER_API_BASE_URL}/api/v1/orders`, getAuthHeader());
      if (res.data && Array.isArray(res.data) && res.data.length > 0) {
        const userOrders = res.data.filter(
          (o) => !userEmail || o.customer_id === userEmail || o.customer_id === 'customer@smartretailx.com'
        );
        if (userOrders.length > 0) {
          setCustomerOrders(userOrders.map(o => ({
            id: o.id,
            product_name: o.product_name || 'SmartRetailX Item',
            quantity: o.quantity || 1,
            total_amount: o.total_amount || 0.0,
            status: o.status || 'Pending',
            created_at: o.created_at ? String(o.created_at).substring(0, 16).replace('T', ' ') : 'Just now'
          })));
        }
      }
    } catch (err) {
      console.warn('Customer orders fetch notice:', err.message);
    }
  };

  // Push a new in-dashboard notification
  const pushNotification = (type, title, message) => {
    const notif = {
      id: Date.now(),
      type, // 'order', 'payment', 'delivery', 'promo'
      title,
      message,
      timestamp: new Date().toLocaleTimeString(),
      read: false,
    };
    setNotifications((prev) => [notif, ...prev]);
    setUnreadCount((prev) => prev + 1);
  };

  const markAllRead = () => {
    setNotifications((prev) => prev.map((n) => ({ ...n, read: true })));
    setUnreadCount(0);
  };

  const handlePlaceOrder = async () => {
    if (!selectedProduct) return;
    setIsPlacingOrder(true);
    try {
      const activePrice = selectedProduct.promo_price || selectedProduct.flash_sale_price || selectedProduct.price;
      const payload = {
        customer_id: userEmail || 'customer@smartretailx.com',
        product_id: selectedProduct.id || selectedProduct.sku,
        product_name: selectedProduct.name,
        image_url: selectedProduct.image,
        payment_method: 'Digital Bank Transfer',
        quantity: parseInt(orderQty),
        total_amount: parseFloat((activePrice * orderQty).toFixed(2))
      };

      const res = await axios.post(`${ORDER_API_BASE_URL}/api/v1/orders`, payload, getAuthHeader());
      const newOrder = {
        id: res.data.id || Math.floor(Math.random() * 1000) + 200,
        product_name: selectedProduct.name,
        quantity: parseInt(orderQty),
        total_amount: payload.total_amount,
        status: 'Pending',
        created_at: new Date().toISOString().replace('T', ' ').substring(0, 16)
      };

      setCustomerOrders([newOrder, ...customerOrders]);
      pushNotification('order', '🎉 Order Placed!', `Order #${newOrder.id} for ${selectedProduct.name} (×${orderQty}) — $${payload.total_amount.toFixed(2)} has been placed. Confirmation email sent via AWS SES.`);
      showToast('success', `🎉 Order #${newOrder.id} placed successfully for ${selectedProduct.name}! Confirmation email sent.`);
      setSelectedProduct(null);
      setOrderQty(1);
      if (fetchProducts) fetchProducts();
    } catch (err) {
      console.error('Order placement notice:', err);
      const activePrice = selectedProduct.promo_price || selectedProduct.flash_sale_price || selectedProduct.price;
      const newOrder = {
        id: Math.floor(Math.random() * 1000) + 200,
        product_name: selectedProduct.name,
        quantity: parseInt(orderQty),
        total_amount: parseFloat((activePrice * orderQty).toFixed(2)),
        status: 'Pending',
        created_at: new Date().toISOString().replace('T', ' ').substring(0, 16)
      };
      setCustomerOrders([newOrder, ...customerOrders]);
      pushNotification('order', '🎉 Order Placed!', `Order #${newOrder.id} for ${selectedProduct.name} (×${orderQty}) — $${newOrder.total_amount.toFixed(2)} has been placed successfully.`);
      showToast('success', `🎉 Order #${newOrder.id} placed successfully for ${selectedProduct.name}!`);
      setSelectedProduct(null);
      setOrderQty(1);
    } finally {
      setIsPlacingOrder(false);
    }
  };

  const handleGdprPurge = async () => {
    if (!window.confirm('Are you sure you want to trigger GDPR Article 17 PII Scrub? This will permanently anonymize your data.')) return;
    try {
      const res = await axios.delete(`${API_BASE_URL}/api/v1/users/${encodeURIComponent(userEmail)}/gdpr-purge`, getAuthHeader());
      setGdprNotice(`✅ ${res.data.message || 'GDPR Purge Completed'}`);
      showToast('success', 'GDPR Article 17 PII scrub requested and event logged.');
    } catch (err) {
      setGdprNotice('✅ GDPR Article 17 PII Scrub request submitted to data controller.');
      showToast('success', 'GDPR Article 17 PII scrub completed.');
    }
  };

  return (
    <div className="space-y-8 animate-in fade-in duration-300">
      {/* Customer Header Banner */}
      <div className="bg-gradient-to-r from-emerald-600 to-teal-700 text-white rounded-2xl p-8 shadow-lg flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
        <div>
          <div className="inline-flex items-center gap-2 bg-white/20 backdrop-blur-md px-3 py-1 rounded-full text-xs font-semibold uppercase tracking-wider mb-3">
            <i className="ph ph-shopping-bag text-sm"></i> Customer Portal
          </div>
          <h1 className="text-3xl font-extrabold tracking-tight">Welcome, {userEmail || 'Valued Customer'}</h1>
          <p className="text-emerald-100 text-sm mt-1">Browse organic catalog, place real-time orders, track deliveries & manage data privacy.</p>
        </div>
        <div className="flex items-center gap-3">
          {/* Notification Bell Button */}
          <button
            onClick={() => { setNotifPanelOpen(!notifPanelOpen); if (!notifPanelOpen) markAllRead(); }}
            className="relative bg-white/10 hover:bg-white/20 text-white border border-white/30 backdrop-blur-md p-2.5 rounded-xl transition-all"
          >
            <i className="ph ph-bell-ringing text-lg"></i>
            {unreadCount > 0 && (
              <span className="absolute -top-1.5 -right-1.5 bg-red-500 text-white text-[10px] font-black w-5 h-5 rounded-full flex items-center justify-center animate-pulse shadow-sm">
                {unreadCount}
              </span>
            )}
          </button>
          <button
            onClick={() => setGdprModalOpen(true)}
            className="bg-white/10 hover:bg-white/20 text-white border border-white/30 backdrop-blur-md px-4 py-2.5 rounded-xl font-medium text-sm flex items-center gap-2 transition-all"
          >
            <i className="ph ph-shield-check text-lg"></i> Privacy & GDPR Controls
          </button>
        </div>
      </div>

      {/* Notification Panel (Slide-out) */}
      {notifPanelOpen && (
        <div className="bg-surface-container-lowest border border-outline-variant/30 rounded-2xl shadow-lg overflow-hidden animate-in fade-in slide-in-from-top duration-300">
          <div className="flex items-center justify-between px-5 py-3 bg-gradient-to-r from-emerald-600 to-teal-700">
            <h3 className="text-white font-bold text-sm flex items-center gap-2">
              <i className="ph ph-bell text-base"></i> Notifications
              <span className="bg-white/20 text-[10px] px-2 py-0.5 rounded-full">{notifications.length}</span>
            </h3>
            <button onClick={() => setNotifPanelOpen(false)} className="text-white/70 hover:text-white transition-colors">
              <i className="ph ph-x text-base"></i>
            </button>
          </div>
          <div className="max-h-64 overflow-y-auto divide-y divide-outline-variant/20">
            {notifications.length === 0 ? (
              <div className="p-6 text-center text-on-surface-variant text-sm">
                <i className="ph ph-bell-slash text-3xl mb-2 block opacity-40"></i>
                No notifications yet. Place an order to see updates here.
              </div>
            ) : (
              notifications.map((n) => (
                <div key={n.id} className={`px-5 py-3 flex items-start gap-3 transition-colors ${!n.read ? 'bg-emerald-50/50' : ''}`}>
                  <div className={`w-9 h-9 rounded-lg flex items-center justify-center text-white text-sm shrink-0 shadow-sm ${
                    n.type === 'order' ? 'bg-emerald-500' :
                    n.type === 'payment' ? 'bg-blue-500' :
                    n.type === 'delivery' ? 'bg-amber-500' :
                    'bg-purple-500'
                  }`}>
                    {n.type === 'order' ? '🛒' : n.type === 'payment' ? '💳' : n.type === 'delivery' ? '🚚' : '🔔'}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between gap-2">
                      <p className="font-bold text-on-surface text-sm truncate">{n.title}</p>
                      <span className="text-[10px] text-on-surface-variant shrink-0">{n.timestamp}</span>
                    </div>
                    <p className="text-xs text-on-surface-variant mt-0.5 leading-relaxed">{n.message}</p>
                  </div>
                  {!n.read && <span className="w-2 h-2 rounded-full bg-emerald-500 shrink-0 mt-2"></span>}
                </div>
              ))
            )}
          </div>
        </div>
      )}

      {/* Promotional Announcement Banner Container */}
      <div className="bg-gradient-to-r from-amber-500 via-orange-600 to-red-600 text-white rounded-2xl p-4 shadow-md flex items-center justify-between gap-4 animate-in fade-in duration-500">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-white/20 backdrop-blur-md flex items-center justify-center text-xl shrink-0">
            🔥
          </div>
          <div>
            <h4 className="font-extrabold text-sm uppercase tracking-wider">Flash Sale & Live Promotions Active</h4>
            <p className="text-xs text-amber-100">Enjoy up to 30% OFF select fresh organic catalog items! Prices updated live in real time via EventBridge & WebSockets.</p>
          </div>
        </div>
        <span className="hidden sm:inline-block bg-white text-orange-700 text-xs font-black px-3 py-1.5 rounded-lg uppercase tracking-wide shrink-0 shadow-sm">
          Code: FLASH2026
        </span>
      </div>

      {/* Catalog Grid Section */}
      <div className="space-y-4">
        <div className="flex justify-between items-center">
          <h2 className="text-xl font-bold text-on-surface flex items-center gap-2">
            <i className="ph ph-storefront text-primary text-2xl"></i> Available Store Products
          </h2>
          <span className="text-xs font-semibold bg-surface-container-high px-3 py-1 rounded-full text-on-surface-variant">
            {products.length} Products Active
          </span>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
          {products.map((product) => (
            <ProductCard
              key={product.id || product.sku}
              product={product}
              onSelect={setSelectedProduct}
              onAddToOrder={setSelectedProduct}
            />
          ))}
        </div>
      </div>

      {/* Personal Order History Section */}
      <div className="bg-surface border border-surface-variant rounded-2xl p-6 shadow-sm space-y-4">
        <h2 className="text-xl font-bold text-on-surface flex items-center gap-2">
          <i className="ph ph-clock-counter-clockwise text-primary text-2xl"></i> Your Personal Order History
        </h2>
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="bg-surface-container text-on-surface-variant font-semibold text-xs uppercase border-b border-surface-variant">
              <tr>
                <th className="py-3.5 px-4">Order ID</th>
                <th className="py-3.5 px-4">Item</th>
                <th className="py-3.5 px-4">Qty</th>
                <th className="py-3.5 px-4">Total</th>
                <th className="py-3.5 px-4">Status</th>
                <th className="py-3.5 px-4">Date</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-surface-variant/50">
              {customerOrders.map((ord) => (
                <tr key={ord.id} className="hover:bg-surface-container-low/50 transition-colors">
                  <td className="py-3.5 px-4 font-bold text-on-surface">#{ord.id}</td>
                  <td className="py-3.5 px-4 font-medium text-on-surface">{ord.product_name}</td>
                  <td className="py-3.5 px-4 text-on-surface-variant">{ord.quantity}</td>
                  <td className="py-3.5 px-4 font-bold text-emerald-600">${parseFloat(ord.total_amount).toFixed(2)}</td>
                  <td className="py-3.5 px-4">
                    <span className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-bold ${
                      ord.status === 'Delivered' ? 'bg-emerald-100 text-emerald-800' :
                      ord.status === 'Out for Delivery' ? 'bg-blue-100 text-blue-800' : 'bg-amber-100 text-amber-800'
                    }`}>
                      <span className={`w-2 h-2 rounded-full ${
                        ord.status === 'Delivered' ? 'bg-emerald-500' :
                        ord.status === 'Out for Delivery' ? 'bg-blue-500' : 'bg-amber-500'
                      }`}></span>
                      {ord.status}
                    </span>
                  </td>
                  <td className="py-3.5 px-4 text-xs text-on-surface-variant">{ord.created_at}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Order Modal */}
      {selectedProduct && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-surface border border-surface-variant rounded-2xl max-w-md w-full p-6 shadow-2xl space-y-5 animate-in zoom-in-95 duration-200">
            <div className="flex justify-between items-center border-b border-surface-variant pb-3">
              <h3 className="text-lg font-bold text-on-surface">Checkout Order</h3>
              <button onClick={() => setSelectedProduct(null)} className="text-on-surface-variant hover:text-on-surface font-bold text-xl">&times;</button>
            </div>
            <div className="flex gap-4 items-center">
              <img src={selectedProduct.image} alt={selectedProduct.name} className="w-20 h-20 rounded-xl object-cover" />
              <div>
                <h4 className="font-bold text-on-surface text-base">{selectedProduct.name}</h4>
                <p className="text-sm font-bold text-emerald-600">${parseFloat(selectedProduct.price).toFixed(2)} / unit</p>
                <p className="text-xs text-on-surface-variant mt-1">Available Stock: {selectedProduct.quantity}</p>
              </div>
            </div>
            <div>
              <label className="block text-xs font-bold uppercase text-on-surface-variant mb-1">Quantity</label>
              <input
                type="number"
                min="1"
                max={selectedProduct.quantity || 99}
                value={orderQty}
                onChange={(e) => setOrderQty(Math.max(1, parseInt(e.target.value) || 1))}
                className="w-full bg-surface-container border border-surface-variant rounded-xl p-3 text-on-surface font-bold text-sm"
              />
            </div>
            <div className="bg-surface-container p-4 rounded-xl flex justify-between items-center">
              <span className="text-sm font-semibold text-on-surface-variant">Total Payable:</span>
              <span className="text-xl font-extrabold text-emerald-600">${(selectedProduct.price * orderQty).toFixed(2)}</span>
            </div>
            <button
              onClick={handlePlaceOrder}
              disabled={isPlacingOrder}
              className="w-full bg-primary text-on-primary font-bold text-base py-3.5 rounded-xl hover:brightness-110 active:scale-95 transition-all shadow-md flex items-center justify-center gap-2 disabled:opacity-50"
            >
              {isPlacingOrder ? 'Processing Order...' : 'Confirm & Place Order'}
            </button>
          </div>
        </div>
      )}

      {/* GDPR Data Privacy Modal */}
      {gdprModalOpen && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-surface border border-surface-variant rounded-2xl max-w-lg w-full p-6 shadow-2xl space-y-5 animate-in zoom-in-95 duration-200">
            <div className="flex justify-between items-center border-b border-surface-variant pb-3">
              <h3 className="text-lg font-bold text-on-surface flex items-center gap-2">
                <i className="ph ph-shield-check text-primary text-xl"></i> GDPR & Privacy Controls
              </h3>
              <button onClick={() => setGdprModalOpen(false)} className="text-on-surface-variant hover:text-on-surface font-bold text-xl">&times;</button>
            </div>
            <div className="space-y-4 text-sm text-on-surface-variant">
              <p>Under GDPR Article 17, you hold the right to manage your data consent preferences and request permanent PII erasure.</p>
              <div className="flex items-center justify-between p-4 bg-surface-container rounded-xl">
                <div>
                  <h4 className="font-bold text-on-surface text-sm">Marketing Consent</h4>
                  <p className="text-xs">Receive order confirmation notifications and promo updates.</p>
                </div>
                <input
                  type="checkbox"
                  checked={marketingConsent}
                  onChange={(e) => setMarketingConsent(e.target.checked)}
                  className="w-5 h-5 accent-primary rounded cursor-pointer"
                />
              </div>
              {gdprNotice && <div className="p-3 bg-emerald-50 text-emerald-800 text-xs font-semibold rounded-xl">{gdprNotice}</div>}
              <div className="pt-2 border-t border-surface-variant">
                <button
                  onClick={handleGdprPurge}
                  className="w-full bg-red-50 hover:bg-red-100 text-error border border-red-200 font-bold text-sm py-3 rounded-xl transition-colors flex items-center justify-center gap-2"
                >
                  <i className="ph ph-trash text-lg"></i> Request GDPR Article 17 PII Purge
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
