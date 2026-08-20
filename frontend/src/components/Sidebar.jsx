import React from 'react';

export default function Sidebar({ activeView, setActiveView, onSyncCatalog, userEmail, userRole }) {
  const role = userRole || 'admin';

  // Role-based navigation items
  const navItems = [
    { id: 'dashboard', label: 'Main Overview', icon: 'ph-squares-four', roles: ['admin', 'staff', 'driver', 'customer'] },
    { id: 'customer_dashboard', label: 'Customer Portal', icon: 'ph-shopping-bag', roles: ['customer', 'admin'] },
    { id: 'driver_dashboard', label: 'Driver Dispatch', icon: 'ph-truck', roles: ['driver', 'admin'] },
    { id: 'staff_dashboard', label: 'Staff Fulfillment', icon: 'ph-package', roles: ['staff', 'admin'] },
    { id: 'admin_dashboard', label: 'Admin Governance', icon: 'ph-crown', roles: ['admin'] },
    { id: 'inventory', label: 'Inventory Catalog', icon: 'ph-barcode', roles: ['admin', 'staff'] },
    { id: 'orders', label: 'Order History', icon: 'ph-shopping-cart', roles: ['admin', 'staff', 'customer'] },
    { id: 'system', label: 'System Health', icon: 'ph-cpu', roles: ['admin'] },
  ];

  const visibleItems = navItems.filter((item) => item.roles.includes(role));

  return (
    <aside className="w-64 bg-surface border-r border-surface-variant flex flex-col justify-between hidden md:flex shrink-0 z-20 h-screen fixed left-0 top-0">
      <div>
        {/* Store Info */}
        <div className="p-6 flex items-center space-x-3">
          <div className="w-10 h-10 bg-primary rounded-lg flex items-center justify-center text-on-primary shrink-0 shadow-sm">
            <i className="ph ph-storefront text-xl"></i>
          </div>
          <div>
            <h1 className="font-bold text-on-surface leading-tight text-body-lg">SmartRetailX</h1>
            <p className="text-xs text-on-surface-variant capitalize font-semibold flex items-center gap-1">
              <span className="w-2 h-2 rounded-full bg-emerald-500"></span> Role: {role}
            </p>
          </div>
        </div>

        {/* Navigation Links */}
        <nav className="px-4 space-y-1">
          {visibleItems.map((item) => {
            const isActive = activeView === item.id;
            return (
              <button
                key={item.id}
                onClick={() => setActiveView(item.id)}
                className={`w-full flex items-center space-x-3 px-3 py-2.5 rounded-lg font-medium transition-colors ${
                  isActive
                    ? 'bg-secondary-container text-on-secondary-container font-bold'
                    : 'text-on-surface-variant hover:bg-surface-variant/50 hover:text-on-surface'
                }`}
              >
                <i className={`ph ${item.icon} text-lg`}></i>
                <span className="text-body-md">{item.label}</span>
              </button>
            );
          })}
        </nav>
      </div>

      {/* Sidebar Bottom Actions */}
      <div className="p-4 space-y-4 border-t border-surface-variant/50 mt-auto bg-surface">
        <button
          onClick={onSyncCatalog}
          className="w-full bg-primary hover:bg-primary/90 text-on-primary flex items-center justify-center space-x-2 py-2.5 rounded-lg font-medium transition-colors shadow-sm"
        >
          <i className="ph ph-arrows-clockwise text-lg"></i>
          <span className="text-body-md font-medium">Sync Catalog Status</span>
        </button>

        <div className="space-y-1">
          <a
            href="#"
            className="flex items-center space-x-3 px-3 py-2 text-on-surface-variant hover:text-on-surface hover:bg-surface-variant/30 rounded-lg transition-colors"
          >
            <i className="ph ph-question text-lg"></i>
            <span className="text-sm font-medium">Support</span>
          </a>
          <button
            onClick={() => document.documentElement.classList.toggle('dark')}
            className="w-full flex items-center space-x-3 px-3 py-2 text-on-surface-variant hover:text-on-surface hover:bg-surface-variant/30 rounded-lg transition-colors text-left"
          >
            <i className="ph ph-moon text-lg"></i>
            <span className="text-sm font-medium">Dark Mode</span>
          </button>
        </div>
      </div>
    </aside>
  );
}
