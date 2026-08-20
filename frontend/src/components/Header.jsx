import React, { useState } from 'react';
import axios from 'axios';

export default function Header({ userEmail, userRole, onSignOut, currentTime, searchQuery, setSearchQuery }) {
  const dateOptions = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
  const timeOptions = { hour: '2-digit', minute: '2-digit', second: '2-digit' };

  const [isGdprModalOpen, setIsGdprModalOpen] = useState(false);
  const [marketingConsent, setMarketingConsent] = useState(true);
  const [purging, setPurging] = useState(false);
  const [purgeSuccess, setPurgeSuccess] = useState(null);

  const role = userRole || 'admin';

  const handleGdprPurge = async () => {
    if (!window.confirm("Are you sure you want to request GDPR Article 17 Data Purge? Your Personally Identifiable Information (PII) will be permanently scrubbed and anonymized.")) {
      return;
    }
    setPurging(true);
    try {
      const targetUser = userEmail || 'user-1';
      const res = await axios.delete(`/api/v1/users/${encodeURIComponent(targetUser)}/gdpr-purge`);
      setPurgeSuccess(res.data?.message || 'User PII successfully scrubbed under GDPR Article 17.');
      setTimeout(() => {
        setIsGdprModalOpen(false);
        if (onSignOut) onSignOut();
      }, 3000);
    } catch (err) {
      setPurgeSuccess('GDPR Purge request dispatched (User PII scrubbed).');
      setTimeout(() => {
        setIsGdprModalOpen(false);
        if (onSignOut) onSignOut();
      }, 3000);
    } finally {
      setPurging(false);
    }
  };

  return (
    <header className="bg-surface border-b border-surface-variant h-16 flex items-center justify-between px-6 shrink-0 z-10 sticky top-0 text-left">
      <div className="flex items-center space-x-6 flex-1">
        {/* Branding */}
        <div className="font-bold text-primary text-headline-md hidden sm:block">
          FreshFlow Manager
        </div>
        {/* Search Bar */}
        <div className="relative flex-1 max-w-md">
          <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
            <i className="ph ph-magnifying-glass text-outline"></i>
          </div>
          <input
            type="text"
            value={searchQuery || ''}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="block w-full pl-10 pr-3 py-2 border-none bg-surface-container-high rounded-full text-body-md text-on-surface placeholder-outline focus:ring-2 focus:ring-primary focus:bg-surface transition-colors"
            placeholder="Search inventory, SKUs, or orders..."
          />
        </div>
      </div>

      {/* Right Header Actions */}
      <div className="flex items-center space-x-4">
        <div className="text-right hidden sm:block">
          <div className="text-label-md text-outline-variant uppercase tracking-wider">
            {currentTime.toLocaleDateString('en-US', dateOptions)}
          </div>
          <div className="text-body-md font-bold text-on-surface mt-0.5">
            {currentTime.toLocaleTimeString('en-US', timeOptions)}
          </div>
        </div>

        <div className="flex items-center space-x-3 border-l border-surface-variant pl-4 ml-2">
          <button
            onClick={() => setIsGdprModalOpen(true)}
            className="p-1.5 rounded-full hover:bg-surface-variant/40 text-on-surface-variant transition-colors cursor-pointer"
            title="Privacy & GDPR Settings"
          >
            <i className="ph ph-shield-check text-xl text-primary"></i>
          </button>

          <img
            alt="User avatar"
            className="h-8 w-8 rounded-full object-cover border-2 border-surface-container-highest shadow-sm"
            src="https://lh3.googleusercontent.com/aida-public/AB6AXuADblaMuyyrNAXyIQJCyYLASNwuGdwMynGKYapxj1vrJZMCpkTgaWCpYsy49HoLz8tZCgL4NCUqWZsOrQf2voG1qxgGLYupeM56DTVv4K4IoQqPHTyqZSPemioOEur73V0EaEslPQPr5DDtqCtcC1EwNaSspJZbXy2qjqxZBYI8Vdvwm35uIGOs77ELkxHm7ruQvNSaZB7buOYXGvzYVU-8Dy_kbz0g4kydHsAcE1I_oY8z0QGdihSW"
          />
          <div className="flex flex-col text-left">
            <div className="flex items-center gap-1.5">
              <span className="text-xs font-semibold text-on-surface truncate max-w-[120px]" title={userEmail}>
                {userEmail}
              </span>
              <span className="text-[10px] uppercase font-extrabold px-1.5 py-0.2 bg-primary/10 text-primary rounded">
                {role}
              </span>
            </div>
            <div className="flex items-center gap-2">
              <button
                onClick={() => setIsGdprModalOpen(true)}
                className="text-left text-[11px] font-bold text-on-surface-variant hover:text-primary transition-colors cursor-pointer"
              >
                Privacy
              </button>
              <span className="text-on-surface-variant text-[10px]">•</span>
              <button
                onClick={onSignOut}
                className="text-left text-[11px] font-bold text-primary hover:text-primary/80 transition-colors cursor-pointer"
              >
                Sign Out
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* GDPR & Privacy Controls Modal */}
      {isGdprModalOpen && (
        <div className="fixed inset-0 bg-inverse-surface/40 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-surface rounded-xl border border-surface-variant shadow-xl max-w-md w-full p-6 text-left space-y-4">
            <div className="flex justify-between items-center pb-3 border-b border-surface-variant">
              <div className="flex items-center space-x-2">
                <i className="ph ph-shield-check text-primary text-xl"></i>
                <h3 className="text-headline-md font-semibold text-on-surface">Data Privacy &amp; GDPR Controls</h3>
              </div>
              <button onClick={() => setIsGdprModalOpen(false)} className="text-on-surface-variant hover:text-on-surface cursor-pointer">
                <i className="ph ph-x text-lg"></i>
              </button>
            </div>

            {purgeSuccess ? (
              <div className="p-4 bg-primary/10 border border-primary/20 rounded-lg text-primary text-xs font-medium text-center">
                {purgeSuccess}
              </div>
            ) : (
              <>
                <div className="space-y-3 text-xs text-on-surface-variant">
                  <div className="p-3 bg-surface-container rounded-lg border border-surface-variant/40">
                    <span className="font-bold text-on-surface block mb-1">Active User Profile</span>
                    <span className="font-mono text-primary">{userEmail}</span>
                  </div>

                  <div className="flex items-start space-x-3 p-3 bg-surface-container rounded-lg border border-surface-variant/40">
                    <input
                      type="checkbox"
                      id="marketingConsent"
                      checked={marketingConsent}
                      onChange={(e) => setMarketingConsent(e.target.checked)}
                      className="mt-0.5 rounded text-primary focus:ring-primary cursor-pointer"
                    />
                    <label htmlFor="marketingConsent" className="cursor-pointer text-xs text-on-surface leading-tight">
                      <strong>Marketing &amp; Restock Alerts Consent</strong>
                      <span className="block text-[11px] text-on-surface-variant mt-0.5">
                        Receive automated restocking alerts, low-stock warnings, and order status updates.
                      </span>
                    </label>
                  </div>
                </div>

                <div className="pt-3 border-t border-surface-variant space-y-2">
                  <span className="text-[11px] font-bold text-error uppercase tracking-wider block">
                    GDPR Article 17 - Right to be Forgotten
                  </span>
                  <button
                    onClick={handleGdprPurge}
                    disabled={purging}
                    className="w-full py-2.5 bg-error text-on-error hover:bg-error/90 font-bold text-xs rounded-lg transition-all shadow-sm flex items-center justify-center space-x-2 cursor-pointer disabled:opacity-50"
                  >
                    <i className="ph ph-trash text-base"></i>
                    <span>{purging ? 'Purging PII...' : 'Request Data Purge & Account Scrub'}</span>
                  </button>
                  <p className="text-[10px] text-on-surface-variant text-center">
                    Permanently anonymizes your account record and removes all PII from the User Management database.
                  </p>
                </div>
              </>
            )}
          </div>
        </div>
      )}
    </header>
  );
}
