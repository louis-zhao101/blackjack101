import { createBrowserRouter, Navigate } from 'react-router-dom';
import { App } from './App.js';
import { PlayPage } from './pages/PlayPage.js';
import { LearnPage } from './pages/LearnPage.js';
import { StatsPage } from './pages/StatsPage.js';

export const router: ReturnType<typeof createBrowserRouter> = createBrowserRouter([
  {
    path: '/',
    element: <App />,
    children: [
      { index: true, element: <Navigate to="/play" replace /> },
      { path: 'play', element: <PlayPage /> },
      { path: 'learn', element: <LearnPage /> },
      { path: 'stats', element: <StatsPage /> },
    ],
  },
]);
