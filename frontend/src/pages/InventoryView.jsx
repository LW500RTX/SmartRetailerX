import React, { useState } from 'react';

export default function InventoryView({ products, loading, onAddToOrder, onUpdatePromotion, onAddProduct }) {
  const [search, setSearch] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('All');
  const [selectedStockStatus, setSelectedStockStatus] = useState('All');
  
  // Promotion Edit State
  const [editingProduct, setEditingProduct] = useState(null);
  const [newPrice, setNewPrice] = useState('');
  const [promoCode, setPromoCode] = useState('');
  const [updating, setUpdating] = useState(false);

  // Add Product State
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);
  const [newItemData, setNewItemData] = useState({
    name: '',
    sku: '',
    category: 'Produce',
    price: '',
    quantity: '',
    image: '',
  });
  const [isCreating, setIsCreating] = useState(false);

  // Pagination State
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 10;

  // Filter products
  const filteredProducts = products.filter((p) => {
    const matchesSearch =
      p.name.toLowerCase().includes(search.toLowerCase()) ||
      p.sku.toLowerCase().includes(search.toLowerCase());
      
    const matchesCategory =
      selectedCategory === 'All' ||
      p.category.toLowerCase() === selectedCategory.toLowerCase();

    const stockQty = parseInt(p.quantity) || 0;
    let matchesStatus = true;
    if (selectedStockStatus === 'Critical') {
      matchesStatus = stockQty < 10 && stockQty > 0;
    } else if (selectedStockStatus === 'Low') {
      matchesStatus = stockQty >= 10 && stockQty < 50;
    } else if (selectedStockStatus === 'OutOfStock') {
      matchesStatus = stockQty === 0;
    } else if (selectedStockStatus === 'Good') {
      matchesStatus = stockQty >= 50;
    }

    return matchesSearch && matchesCategory && matchesStatus;
  });

  const totalPages = Math.ceil(filteredProducts.length / itemsPerPage) || 1;
  const paginatedProducts = filteredProducts.slice(
    (currentPage - 1) * itemsPerPage,
    currentPage * itemsPerPage
  );

  const getStockBadge = (qty) => {
    if (qty === 0) {
      return <span className="px-2.5 py-1 rounded text-xs font-semibold bg-[#F3F4F6] text-[#1F2937]">OUT OF STOCK</span>;
    }
    if (qty < 10) {
      return (
        <span className="inline-flex items-center px-2.5 py-1 rounded text-xs font-semibold bg-error text-on-error shadow-sm animate-pulse">
          <i className="ph ph-warning-circle mr-1 text-sm"></i> CRITICAL
        </span>
      );
    }
    if (qty < 50) {
      return <span className="px-2.5 py-1 rounded text-xs font-semibold bg-warning-100 text-warning-600 border border-warning-200">LOW</span>;
    }
    return <span className="px-2.5 py-1 rounded text-xs font-semibold bg-secondary-container text-on-secondary-container">GOOD</span>;
  };

  const handleOpenPromoModal = (product) => {
    setEditingProduct(product);
    setNewPrice(product.price.toString());
    setPromoCode(product.promotion_code || '');
  };

  const handleSavePromotion = async (e) => {
    e.preventDefault();
    if (!editingProduct) return;
    setUpdating(true);
    try {
      await onUpdatePromotion(editingProduct.id, parseFloat(newPrice), promoCode);
      setEditingProduct(null);
    } catch (err) {
      console.error(err);
    } finally {
      setUpdating(false);
    }
  };

  const handleCreateProductSubmit = async (e) => {
    e.preventDefault();
    if (!newItemData.name || !newItemData.sku) return;
    setIsCreating(true);
    try {
      if (onAddProduct) {
        await onAddProduct(newItemData);
      }
      setIsAddModalOpen(false);
      setNewItemData({
        name: '',
        sku: '',
        category: 'Produce',
        price: '',
        quantity: '',
        image: '',
      });
    } catch (err) {
      console.error(err);
    } finally {
      setIsCreating(false);
    }
  };

  return (
    <div className="bg-surface rounded-xl shadow-sm border border-surface-variant overflow-hidden flex flex-col w-full text-left">
      {/* Header Panel */}
      <div className="px-6 py-5 border-b border-surface-variant flex flex-col md:flex-row md:items-center justify-between gap-4 bg-surface-container-lowest">
        <div>
          <h2 className="text-headline-md text-on-surface font-semibold">Inventory Management</h2>
          <p className="text-xs text-on-surface-variant mt-0.5">Manage catalogue details, prices, and promotions</p>
        </div>

        {/* Quick Search & Filters */}
        <div className="flex flex-wrap items-center gap-2">
          <button
            onClick={() => setIsAddModalOpen(true)}
            className="flex items-center gap-1.5 px-3.5 py-1.5 bg-primary hover:bg-primary/90 text-on-primary font-bold text-xs rounded-lg transition-colors cursor-pointer shadow-sm shrink-0"
          >
            <i className="ph ph-plus text-sm font-bold"></i>
            <span>Add Item</span>
          </button>

          <div className="relative">
            <span className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
              <i className="ph ph-magnifying-glass text-outline"></i>
            </span>
            <input
              type="text"
              placeholder="Search by name/SKU..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="pl-9 pr-3 py-1.5 border border-surface-variant bg-surface rounded-lg text-xs placeholder-outline focus:ring-1 focus:ring-primary outline-none"
            />
          </div>
          <select
            value={selectedCategory}
            onChange={(e) => setSelectedCategory(e.target.value)}
            className="px-2 py-1.5 border border-surface-variant bg-surface rounded-lg text-xs outline-none cursor-pointer"
          >
            <option value="All">All Categories</option>
            <option value="Produce">Produce</option>
            <option value="Dairy">Dairy</option>
            <option value="Bakery">Bakery</option>
            <option value="Beverages">Beverages</option>
            <option value="Meat">Meat</option>
            <option value="Pantry">Pantry</option>
          </select>
          <select
            value={selectedStockStatus}
            onChange={(e) => setSelectedStockStatus(e.target.value)}
            className="px-2 py-1.5 border border-surface-variant bg-surface rounded-lg text-xs outline-none cursor-pointer"
          >
            <option value="All">All Stock Levels</option>
            <option value="Good">Good (50+)</option>
            <option value="Low">Low (10-49)</option>
            <option value="Critical">Critical (1-9)</option>
            <option value="OutOfStock">Out of Stock (0)</option>
          </select>
        </div>
      </div>

      {/* Catalogue Table */}
      <div className="overflow-x-auto bg-surface-container-lowest">
        <table className="min-w-full w-full text-left whitespace-nowrap">
          <thead className="bg-surface-container text-on-surface-variant text-[11px] font-bold uppercase tracking-wider">
            <tr>
              <th className="px-6 py-4 w-2/5 font-semibold">Product Name</th>
              <th className="px-6 py-4 w-1/5 font-semibold">SKU</th>
              <th className="px-6 py-4 w-1/6 font-semibold">Category</th>
              <th className="px-6 py-4 w-1/6 font-semibold">Price</th>
              <th className="px-6 py-4 w-1/6 font-semibold">Stock Qty</th>
              <th className="px-6 py-4 w-1/6 font-semibold">Status</th>
              <th className="px-6 py-4 w-1/6 text-right font-semibold">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-surface-variant/50 text-body-md text-on-surface">
            {loading ? (
              <tr>
                <td colSpan="7" className="px-6 py-12 text-center text-on-surface-variant text-xs">
                  Loading catalogue data...
                </td>
              </tr>
            ) : filteredProducts.length === 0 ? (
              <tr>
                <td colSpan="7" className="px-6 py-12 text-center text-on-surface-variant text-xs">
                  No matching products found in database.
                </td>
              </tr>
            ) : (
              paginatedProducts.map((p) => (
                <tr key={p.id || p.sku} className="hover:bg-surface-container-low/50 transition-colors">
                  <td className="px-6 py-4 flex items-center space-x-3">
                    {p.image ? (
                      <img src={p.image} alt={p.name} className="w-10 h-10 object-cover rounded-lg border border-surface-variant shrink-0" />
                    ) : (
                      <div className="w-10 h-10 bg-surface-container border border-surface-variant rounded-lg flex items-center justify-center text-on-surface-variant text-xs font-bold shrink-0">
                        {p.name.charAt(0)}
                      </div>
                    )}
                    <div>
                      <span className="font-semibold text-on-surface text-xs block">{p.name}</span>
                      {p.promotion_code && (
                        <span className="inline-block mt-0.5 px-2 py-0.5 bg-primary/10 text-primary text-[10px] font-bold rounded uppercase">
                          {p.promotion_code}
                        </span>
                      )}
                    </div>
                  </td>
                  <td className="px-6 py-4 font-mono text-xs text-on-surface-variant">{p.sku}</td>
                  <td className="px-6 py-4 text-xs text-on-surface-variant">{p.category}</td>
                  <td className="px-6 py-4 text-xs font-semibold text-on-surface">${parseFloat(p.price).toFixed(2)}</td>
                  <td className="px-6 py-4 text-xs text-on-surface font-semibold">{p.quantity}</td>
                  <td className="px-6 py-4">{getStockBadge(parseInt(p.quantity) || 0)}</td>
                  <td className="px-6 py-4 text-right space-x-2">
                    <button
                      onClick={() => handleOpenPromoModal(p)}
                      className="px-2.5 py-1.5 bg-surface-container border border-surface-variant hover:bg-surface-variant/40 text-on-surface text-xs rounded font-medium transition-colors cursor-pointer"
                    >
                      Promo Edit
                    </button>
                    <button
                      onClick={() => onAddToOrder(p)}
                      className="px-2.5 py-1.5 bg-primary hover:bg-primary/90 text-on-primary text-xs rounded font-bold transition-colors cursor-pointer shadow-sm"
                    >
                      + Order
                    </button>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {/* Table Pagination Footer */}
      <div className="px-6 py-4 border-t border-surface-variant flex items-center justify-between bg-surface-container-lowest text-xs text-on-surface-variant">
        <div>
          Showing <span className="font-semibold text-on-surface">{filteredProducts.length > 0 ? (currentPage - 1) * itemsPerPage + 1 : 0}</span> to <span className="font-semibold text-on-surface">{Math.min(currentPage * itemsPerPage, filteredProducts.length)}</span> of <span className="font-semibold text-on-surface">{filteredProducts.length}</span> items
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={() => setCurrentPage(prev => Math.max(1, prev - 1))}
            disabled={currentPage === 1}
            className="px-3 py-1.5 border border-surface-variant rounded-lg hover:bg-surface-variant/30 disabled:opacity-40 disabled:cursor-not-allowed cursor-pointer transition-colors font-medium"
          >
            Previous
          </button>
          
          <span className="font-medium text-on-surface">
            Page {currentPage} of {totalPages}
          </span>

          <button
            onClick={() => setCurrentPage(prev => Math.min(totalPages, prev + 1))}
            disabled={currentPage === totalPages}
            className="px-3 py-1.5 border border-surface-variant rounded-lg hover:bg-surface-variant/30 disabled:opacity-40 disabled:cursor-not-allowed cursor-pointer transition-colors font-medium"
          >
            Next
          </button>
        </div>
      </div>

      {/* Add New Product Modal */}
      {isAddModalOpen && (
        <div className="fixed inset-0 bg-inverse-surface/40 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-surface rounded-xl border border-surface-variant shadow-xl max-w-md w-full p-6 text-left animate-in fade-in zoom-in-95 duration-150">
            <div className="flex justify-between items-center pb-4 border-b border-surface-variant">
              <div>
                <h3 className="text-headline-md font-semibold text-on-surface">Add New Product</h3>
                <p className="text-xs text-on-surface-variant">Enter details to add an item to the store catalogue</p>
              </div>
              <button onClick={() => setIsAddModalOpen(false)} className="text-on-surface-variant hover:text-on-surface">
                <i className="ph ph-x text-lg"></i>
              </button>
            </div>

            <form onSubmit={handleCreateProductSubmit} className="space-y-4 pt-4">
              <div className="flex flex-col">
                <label className="text-xs font-semibold text-on-surface-variant mb-1 uppercase tracking-wider">Product Name *</label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Fresh Organic Bananas 1kg"
                  value={newItemData.name}
                  onChange={(e) => setNewItemData({ ...newItemData, name: e.target.value })}
                  className="rounded border border-surface-variant bg-surface p-2.5 text-xs text-on-surface outline-none focus:ring-1 focus:ring-primary"
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="flex flex-col">
                  <label className="text-xs font-semibold text-on-surface-variant mb-1 uppercase tracking-wider">SKU Code *</label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. PROD-BAN-001"
                    value={newItemData.sku}
                    onChange={(e) => setNewItemData({ ...newItemData, sku: e.target.value })}
                    className="rounded border border-surface-variant bg-surface p-2.5 text-xs text-on-surface outline-none focus:ring-1 focus:ring-primary font-mono"
                  />
                </div>

                <div className="flex flex-col">
                  <label className="text-xs font-semibold text-on-surface-variant mb-1 uppercase tracking-wider">Category</label>
                  <select
                    value={newItemData.category}
                    onChange={(e) => setNewItemData({ ...newItemData, category: e.target.value })}
                    className="rounded border border-surface-variant bg-surface p-2.5 text-xs text-on-surface outline-none focus:ring-1 focus:ring-primary cursor-pointer"
                  >
                    <option value="Produce">Produce</option>
                    <option value="Dairy">Dairy</option>
                    <option value="Bakery">Bakery</option>
                    <option value="Beverages">Beverages</option>
                    <option value="Meat">Meat</option>
                    <option value="Pantry">Pantry</option>
                    <option value="General">General</option>
                  </select>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="flex flex-col">
                  <label className="text-xs font-semibold text-on-surface-variant mb-1 uppercase tracking-wider">Price ($ USD) *</label>
                  <input
                    type="number"
                    step="0.01"
                    required
                    placeholder="e.g. 4.99"
                    value={newItemData.price}
                    onChange={(e) => setNewItemData({ ...newItemData, price: e.target.value })}
                    className="rounded border border-surface-variant bg-surface p-2.5 text-xs text-on-surface outline-none focus:ring-1 focus:ring-primary"
                  />
                </div>

                <div className="flex flex-col">
                  <label className="text-xs font-semibold text-on-surface-variant mb-1 uppercase tracking-wider">Initial Stock Qty *</label>
                  <input
                    type="number"
                    required
                    placeholder="e.g. 100"
                    value={newItemData.quantity}
                    onChange={(e) => setNewItemData({ ...newItemData, quantity: e.target.value })}
                    className="rounded border border-surface-variant bg-surface p-2.5 text-xs text-on-surface outline-none focus:ring-1 focus:ring-primary"
                  />
                </div>
              </div>

              <div className="flex flex-col">
                <label className="text-xs font-semibold text-on-surface-variant mb-1 uppercase tracking-wider">Image URL (Optional)</label>
                <input
                  type="url"
                  placeholder="https://images.unsplash.com/photo-..."
                  value={newItemData.image}
                  onChange={(e) => setNewItemData({ ...newItemData, image: e.target.value })}
                  className="rounded border border-surface-variant bg-surface p-2.5 text-xs text-on-surface outline-none focus:ring-1 focus:ring-primary"
                />
              </div>

              <div className="flex justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setIsAddModalOpen(false)}
                  className="px-4 py-2 border border-surface-variant text-xs rounded-lg hover:bg-surface-variant/30 font-medium transition-colors cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isCreating}
                  className="px-4 py-2 bg-primary text-on-primary text-xs rounded-lg hover:brightness-105 font-bold transition-all disabled:opacity-50 cursor-pointer shadow-sm"
                >
                  {isCreating ? 'Saving Item...' : 'Save Product'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Edit Promotion Modal */}
      {editingProduct && (
        <div className="fixed inset-0 bg-inverse-surface/40 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-surface rounded-xl border border-surface-variant shadow-xl max-w-md w-full p-6 text-left animate-in fade-in zoom-in-95 duration-150">
            <div className="flex justify-between items-center pb-4 border-b border-surface-variant">
              <div>
                <h3 className="text-headline-md font-semibold text-on-surface">Update Product Promotion</h3>
                <p className="text-xs text-on-surface-variant">Set price discounts or apply promotional codes</p>
              </div>
              <button onClick={() => setEditingProduct(null)} className="text-on-surface-variant hover:text-on-surface">
                <i className="ph ph-x text-lg"></i>
              </button>
            </div>

            <form onSubmit={handleSavePromotion} className="space-y-4 pt-4">
              <div className="flex flex-col">
                <label className="text-xs font-semibold text-on-surface-variant mb-1 uppercase tracking-wider">Product Title</label>
                <input
                  type="text"
                  disabled
                  value={editingProduct.name}
                  className="rounded border border-surface-variant bg-surface-container p-2.5 text-xs text-on-surface-variant outline-none"
                />
              </div>

              <div className="flex flex-col">
                <label className="text-xs font-semibold text-on-surface-variant mb-1 uppercase tracking-wider">SKU</label>
                <input
                  type="text"
                  disabled
                  value={editingProduct.sku}
                  className="rounded border border-surface-variant bg-surface-container p-2.5 text-xs text-on-surface-variant outline-none font-mono"
                />
              </div>

              <div className="flex flex-col">
                <label className="text-xs font-semibold text-on-surface-variant mb-1 uppercase tracking-wider">Price ($ USD)</label>
                <input
                  type="number"
                  step="0.01"
                  required
                  value={newPrice}
                  onChange={(e) => setNewPrice(e.target.value)}
                  className="rounded border border-surface-variant bg-surface p-2.5 text-xs text-on-surface outline-none focus:ring-1 focus:ring-primary"
                />
              </div>

              <div className="flex flex-col">
                <label className="text-xs font-semibold text-on-surface-variant mb-1 uppercase tracking-wider">Promotion Code</label>
                <input
                  type="text"
                  placeholder="e.g. SUMMER20, DISCOUNT10"
                  value={promoCode}
                  onChange={(e) => setPromoCode(e.target.value)}
                  className="rounded border border-surface-variant bg-surface p-2.5 text-xs text-on-surface outline-none focus:ring-1 focus:ring-primary"
                />
              </div>

              <div className="flex justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setEditingProduct(null)}
                  className="px-4 py-2 border border-surface-variant text-xs rounded-lg hover:bg-surface-variant/30 font-medium transition-colors cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={updating}
                  className="px-4 py-2 bg-primary text-on-primary text-xs rounded-lg hover:brightness-105 font-bold transition-all disabled:opacity-50 cursor-pointer shadow-sm"
                >
                  {updating ? 'Applying...' : 'Apply Promotion'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
