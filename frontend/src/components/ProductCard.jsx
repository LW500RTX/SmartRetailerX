import React from 'react';

export default function ProductCard({ product, onSelect, onAddToOrder }) {
  const originalPrice = product.original_price || product.price || 0;
  const discountPrice = product.discount_price || product.promo_price || product.flash_sale_price;
  const isOnSale = product.is_on_sale || (discountPrice && discountPrice < originalPrice);
  const activePrice = isOnSale ? discountPrice : originalPrice;
  const discountPct = product.discount_percentage || (isOnSale && originalPrice > 0 ? Math.round(((originalPrice - discountPrice) / originalPrice) * 100) : 20);

  return (
    <div className="bg-surface-container-lowest border border-outline-variant/30 rounded-xl p-5 shadow-sm hover:shadow-md transition-all flex flex-col justify-between relative overflow-hidden group">
      {/* Visual Badge / Tag */}
      {isOnSale && (
        <div className="absolute top-3 right-3 bg-gradient-to-r from-red-600 to-amber-500 text-white text-[11px] font-extrabold px-2.5 py-1 rounded-full shadow-sm animate-pulse flex items-center gap-1 z-10">
          <i className="ph ph-fire text-xs"></i>
          <span>🔥 Sale -{discountPct}%</span>
        </div>
      )}

      <div>
        <div className="h-36 w-full rounded-lg overflow-hidden bg-surface-container-high mb-4">
          <img
            src={product.image || product.image_url || 'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&q=80&w=300'}
            alt={product.name}
            className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
          />
        </div>

        <span className="text-[11px] font-bold uppercase tracking-wider text-primary bg-primary-container/20 px-2 py-0.5 rounded">
          {product.category || 'General'}
        </span>

        <h3 className="font-bold text-on-surface text-base mt-2 line-clamp-1">{product.name}</h3>
        <p className="text-xs text-on-surface-variant mt-1 font-mono">SKU: {product.sku || product.id}</p>
      </div>

      <div className="mt-4 pt-3 border-t border-outline-variant/20 flex items-center justify-between">
        <div className="flex flex-col">
          {isOnSale && (
            <span className="text-xs text-on-surface-variant line-through font-semibold">
              ${parseFloat(originalPrice).toFixed(2)}
            </span>
          )}
          <span className="text-xl font-black text-emerald-600">
            ${parseFloat(activePrice).toFixed(2)}
          </span>
        </div>

        <button
          onClick={() => onAddToOrder ? onAddToOrder(product) : onSelect && onSelect(product)}
          className="bg-primary hover:brightness-110 active:scale-95 text-on-primary text-xs font-bold px-3.5 py-2 rounded-lg transition-all flex items-center gap-1.5 shadow-sm"
        >
          <i className="ph ph-shopping-cart text-sm"></i>
          <span>Add</span>
        </button>
      </div>
    </div>
  );
}
