import { NavLink, Outlet } from 'react-router-dom';

export function App() {
  return (
    <div className="app">
      <header className="site-header">
        <div className="site-header__inner">
          <NavLink to="/play" className="site-logo" aria-label="Blackjack 101 home">
            <span className="site-logo__suit" aria-hidden="true">♠</span>
            <span className="site-logo__name">Blackjack 101</span>
            <span className="site-logo__suit" aria-hidden="true">♥</span>
          </NavLink>

          <nav className="site-nav" aria-label="Main navigation">
            <NavLink
              to="/play"
              className={({ isActive }) => `nav-link ${isActive ? 'nav-link--active' : ''}`}
            >
              Play
            </NavLink>
            <NavLink
              to="/learn"
              className={({ isActive }) => `nav-link ${isActive ? 'nav-link--active' : ''}`}
            >
              Learn
            </NavLink>
            <NavLink
              to="/stats"
              className={({ isActive }) => `nav-link ${isActive ? 'nav-link--active' : ''}`}
            >
              Stats
            </NavLink>
          </nav>
        </div>
      </header>

      <main className="site-main">
        <Outlet />
      </main>
    </div>
  );
}
