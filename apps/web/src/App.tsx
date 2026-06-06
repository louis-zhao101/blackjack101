import { useEffect, useRef, useState } from 'react';
import { NavLink, Outlet, useLocation } from 'react-router-dom';
import { useAuthStore } from './store/authStore.js';
import { useStatsStore } from './store/statsStore.js';
import { useGameStore } from './store/gameStore.js';
import { useSettingsStore } from './store/settingsStore.js';
import { loadUserData, upsertSession, upsertProfile } from './lib/sync.js';
import { AuthModal } from './components/auth/AuthModal.js';

export function App() {
  const { user, loading, initialize, signOut } = useAuthStore();
  const { ruleSet } = useSettingsStore();
  const [showAuthModal, setShowAuthModal] = useState(false);
  const [showUserMenu, setShowUserMenu] = useState(false);
  const [showChart, setShowChart] = useState(false);
  const userMenuRef = useRef<HTMLDivElement>(null);
  const prevUserIdRef = useRef<string | null>(null);
  const location = useLocation();
  const isPlay = location.pathname === '/play';

  // Boot auth listener once
  useEffect(() => { initialize(); }, [initialize]);

  // Sync data on login/logout
  useEffect(() => {
    const prevId = prevUserIdRef.current;
    const currId = user?.id ?? null;
    prevUserIdRef.current = currId;

    if (currId && currId !== prevId) {
      // User just logged in — load or upload data
      void (async () => {
        const { profile, sessions } = await loadUserData(currId);
        if (sessions.length > 0) {
          // Cloud has data — use it
          useStatsStore.getState().loadFromCloud(sessions);
          if (profile?.bankroll != null) {
            useGameStore.getState().loadBankroll(profile.bankroll);
          }
        } else {
          // First login — upload local data to cloud
          const localStats = useStatsStore.getState();
          const localGame = useGameStore.getState();
          const allLocal = [
            ...localStats.sessions,
            ...(localStats.currentSession ? [localStats.currentSession] : []),
          ];
          await Promise.all([
            ...allLocal.map((s) => upsertSession(currId, s)),
            upsertProfile(currId, localGame.game.bankroll),
          ]);
        }
        setShowAuthModal(false);
      })();
    }
  }, [user?.id]);

  // Close user menu on outside click
  useEffect(() => {
    function handler(e: MouseEvent) {
      if (userMenuRef.current && !userMenuRef.current.contains(e.target as Node)) {
        setShowUserMenu(false);
      }
    }
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, []);

  const displayName = user?.email ?? user?.phone ?? 'Account';

  return (
    <div className="app">
      <header className="site-header">
        <div className="site-header__inner">
          <div className="header-left">
            <NavLink to="/play" className="site-logo" aria-label="Blackjack 101 home">
              <span className="site-logo__suit" aria-hidden="true">♠</span>
              <span className="site-logo__name">Blackjack 101</span>
              <span className="site-logo__suit" aria-hidden="true">♥</span>
            </NavLink>
            <nav className="site-nav" aria-label="Main navigation">
              <NavLink to="/play" className={({ isActive }) => `nav-link ${isActive ? 'nav-link--active' : ''}`}>Play</NavLink>
              <NavLink to="/learn" className={({ isActive }) => `nav-link ${isActive ? 'nav-link--active' : ''}`}>Learn</NavLink>
              <NavLink to="/stats" className={({ isActive }) => `nav-link ${isActive ? 'nav-link--active' : ''}`}>Stats</NavLink>
            </nav>
          </div>

          {isPlay && (
            <div className="header-center">
              <span className="toolbar-ruleset-badge">{ruleSet.name}</span>
            </div>
          )}

          <div className="header-right">
            {isPlay && (
              <button
                className={`icon-btn${showChart ? ' icon-btn--active' : ''}`}
                onClick={() => setShowChart((v) => !v)}
                aria-expanded={showChart}
                aria-controls="strategy-chart-panel"
                aria-label="Toggle strategy chart"
              >
                <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round">
                  <rect x="1" y="1" width="14" height="14" rx="1.5"/>
                  <line x1="1" y1="5.5" x2="15" y2="5.5"/>
                  <line x1="1" y1="10.5" x2="15" y2="10.5"/>
                  <line x1="5.5" y1="1" x2="5.5" y2="15"/>
                  <line x1="10.5" y1="1" x2="10.5" y2="15"/>
                </svg>
              </button>
            )}
            {!loading && !user && (
              <button className="icon-btn" onClick={() => setShowAuthModal(true)} aria-label="Sign in">
                <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
                  <circle cx="8" cy="5.5" r="2.5"/>
                  <path d="M2 14.5c0-3.314 2.686-6 6-6s6 2.686 6 6"/>
                </svg>
              </button>
            )}
            {user && (
              <div className="user-menu-wrap" ref={userMenuRef}>
                <button className="user-avatar-btn" onClick={() => setShowUserMenu((v) => !v)} aria-label="Account menu">
                  {displayName.slice(0, 1).toUpperCase()}
                </button>
                {showUserMenu && (
                  <div className="user-menu">
                    <div className="user-menu__name">{displayName}</div>
                    <button className="user-menu__item" onClick={() => { void signOut(); setShowUserMenu(false); }}>
                      Sign out
                    </button>
                  </div>
                )}
              </div>
            )}
          </div>
        </div>
      </header>

      <main className="site-main">
        <Outlet context={{ showChart, setShowChart }} />
      </main>

      {showAuthModal && <AuthModal onClose={() => setShowAuthModal(false)} />}
    </div>
  );
}
