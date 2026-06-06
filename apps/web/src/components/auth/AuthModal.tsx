import { useState } from 'react';
import { useAuthStore } from '../../store/authStore.js';

type Mode = 'signin' | 'signup';

interface Props {
  onClose: () => void;
}

export function AuthModal({ onClose }: Props) {
  const { signInWithPassword, signUp, signInWithGoogle } = useAuthStore();

  const [mode, setMode] = useState<Mode>('signin');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [successMsg, setSuccessMsg] = useState('');
  const [error, setError] = useState('');

  function switchMode(m: Mode) {
    setMode(m);
    setError('');
    setSuccessMsg('');
    setPassword('');
    setConfirmPassword('');
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError('');

    if (mode === 'signup') {
      if (password.length < 8) { setError('Password must be at least 8 characters.'); return; }
      if (password !== confirmPassword) { setError('Passwords do not match.'); return; }
    }

    setLoading(true);

    if (mode === 'signin') {
      const { error } = await signInWithPassword(email, password);
      setLoading(false);
      if (error) setError(error === 'Invalid login credentials' ? 'Incorrect email or password.' : error);
      else onClose();
    } else {
      const { error } = await signUp(email, password);
      setLoading(false);
      if (error) setError(error);
      else setSuccessMsg('Account created! Check your email to confirm, then sign in.');
    }
  }

  async function handleGoogle() {
    setLoading(true); setError('');
    const { error } = await signInWithGoogle();
    if (error) { setError(error); setLoading(false); }
  }

  return (
    <div className="auth-overlay" onClick={onClose}>
      <div className="auth-modal" onClick={(e) => e.stopPropagation()} role="dialog" aria-modal="true" aria-label="Sign in">

        <button className="auth-modal__close" onClick={onClose} aria-label="Close">✕</button>

        <div className="auth-modal__header">
          <span className="auth-modal__suit">♠</span>
          <h2 className="auth-modal__title">
            {mode === 'signin' ? 'Sign in' : 'Create account'}
          </h2>
          <p className="auth-modal__sub">Save your progress and stats across devices</p>
        </div>

        <button className="btn-google" onClick={handleGoogle} disabled={loading}>
          <svg width="18" height="18" viewBox="0 0 18 18" aria-hidden="true">
            <path fill="#4285F4" d="M17.64 9.2c0-.637-.057-1.251-.164-1.84H9v3.481h4.844c-.209 1.125-.843 2.078-1.796 2.717v2.258h2.908c1.702-1.567 2.684-3.875 2.684-6.615z"/>
            <path fill="#34A853" d="M9 18c2.43 0 4.467-.806 5.956-2.184l-2.908-2.258c-.806.54-1.837.86-3.048.86-2.344 0-4.328-1.584-5.036-3.711H.957v2.332A8.997 8.997 0 0 0 9 18z"/>
            <path fill="#FBBC05" d="M3.964 10.707A5.41 5.41 0 0 1 3.682 9c0-.593.102-1.17.282-1.707V4.961H.957A8.996 8.996 0 0 0 0 9c0 1.452.348 2.827.957 4.039l3.007-2.332z"/>
            <path fill="#EA4335" d="M9 3.58c1.321 0 2.508.454 3.44 1.345l2.582-2.58C13.463.891 11.426 0 9 0A8.997 8.997 0 0 0 .957 4.961L3.964 7.293C4.672 5.163 6.656 3.58 9 3.58z"/>
          </svg>
          Continue with Google
        </button>

        <div className="auth-divider"><span>or</span></div>

        <div className="auth-form-area">
          {successMsg ? (
            <div className="auth-success">
              <span className="auth-success__icon">✓</span>
              <p>{successMsg}</p>
            </div>
          ) : (
            <form onSubmit={handleSubmit} className="auth-form">
              <div>
                <label className="auth-label" htmlFor="auth-email">Email</label>
                <input
                  id="auth-email"
                  className="auth-input"
                  type="email"
                  placeholder="you@example.com"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  autoComplete="email"
                  required
                />
              </div>
              <div>
                <label className="auth-label" htmlFor="auth-password">Password</label>
                <input
                  id="auth-password"
                  className="auth-input"
                  type="password"
                  placeholder={mode === 'signup' ? 'At least 8 characters' : '••••••••'}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  autoComplete={mode === 'signin' ? 'current-password' : 'new-password'}
                  required
                />
              </div>
              {mode === 'signup' && (
                <div>
                  <label className="auth-label" htmlFor="auth-confirm">Confirm password</label>
                  <input
                    id="auth-confirm"
                    className="auth-input"
                    type="password"
                    placeholder="••••••••"
                    value={confirmPassword}
                    onChange={(e) => setConfirmPassword(e.target.value)}
                    autoComplete="new-password"
                    required
                  />
                </div>
              )}
              {error && <p className="auth-error">{error}</p>}
              <button className="btn btn--primary btn--lg auth-submit" type="submit" disabled={loading}>
                {loading ? '…' : mode === 'signin' ? 'Sign in' : 'Create account'}
              </button>
            </form>
          )}
        </div>

        <p className="auth-switch">
          {mode === 'signin' ? (
            <>No account? <button className="auth-switch__link" onClick={() => switchMode('signup')}>Create one</button></>
          ) : (
            <>Already have an account? <button className="auth-switch__link" onClick={() => switchMode('signin')}>Sign in</button></>
          )}
        </p>

      </div>
    </div>
  );
}
