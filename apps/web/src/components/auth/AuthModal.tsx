import { useState } from 'react';
import { useAuthStore } from '../../store/authStore.js';

type Tab = 'email' | 'phone';
type PhoneStep = 'enter' | 'verify';

interface Props {
  onClose: () => void;
}

export function AuthModal({ onClose }: Props) {
  const { signInWithEmail, signInWithPhone, verifyPhoneOtp, signInWithGoogle } = useAuthStore();

  const [tab, setTab] = useState<Tab>('email');
  const [email, setEmail] = useState('');
  const [phone, setPhone] = useState('');
  const [otp, setOtp] = useState('');
  const [phoneStep, setPhoneStep] = useState<PhoneStep>('enter');
  const [loading, setLoading] = useState(false);
  const [successMsg, setSuccessMsg] = useState('');
  const [error, setError] = useState('');

  function resetError() { setError(''); }

  async function handleEmailSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true); resetError();
    const { error } = await signInWithEmail(email);
    setLoading(false);
    if (error) setError(error);
    else setSuccessMsg('Check your email — we sent a sign-in link!');
  }

  async function handlePhoneSend(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true); resetError();
    const { error } = await signInWithPhone(phone);
    setLoading(false);
    if (error) setError(error);
    else setPhoneStep('verify');
  }

  async function handlePhoneVerify(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true); resetError();
    const { error } = await verifyPhoneOtp(phone, otp);
    setLoading(false);
    if (error) setError(error);
    else onClose();
  }

  async function handleGoogle() {
    setLoading(true); resetError();
    const { error } = await signInWithGoogle();
    if (error) { setError(error); setLoading(false); }
    // on success the page redirects, so we don't setLoading(false)
  }

  return (
    <div className="auth-overlay" onClick={onClose}>
      <div className="auth-modal" onClick={(e) => e.stopPropagation()} role="dialog" aria-modal="true" aria-label="Sign in">

        <button className="auth-modal__close" onClick={onClose} aria-label="Close">✕</button>

        <div className="auth-modal__header">
          <span className="auth-modal__suit">♠</span>
          <h2 className="auth-modal__title">Sign in to Blackjack 101</h2>
          <p className="auth-modal__sub">Save your progress and stats across devices</p>
        </div>

        {/* Google */}
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

        {/* Tabs */}
        <div className="auth-tabs">
          <button className={`auth-tab ${tab === 'email' ? 'auth-tab--active' : ''}`} onClick={() => { setTab('email'); resetError(); setSuccessMsg(''); }}>
            Email
          </button>
          <button className={`auth-tab ${tab === 'phone' ? 'auth-tab--active' : ''}`} onClick={() => { setTab('phone'); resetError(); setSuccessMsg(''); }}>
            Phone
          </button>
        </div>

        {/* Email tab */}
        {tab === 'email' && (
          <div className="auth-form-area">
            {successMsg ? (
              <div className="auth-success">
                <span className="auth-success__icon">✓</span>
                <p>{successMsg}</p>
              </div>
            ) : (
              <form onSubmit={handleEmailSubmit} className="auth-form">
                <label className="auth-label" htmlFor="auth-email">Email address</label>
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
                {error && <p className="auth-error">{error}</p>}
                <button className="btn btn--primary btn--lg auth-submit" type="submit" disabled={loading}>
                  {loading ? 'Sending…' : 'Send magic link'}
                </button>
              </form>
            )}
          </div>
        )}

        {/* Phone tab */}
        {tab === 'phone' && (
          <div className="auth-form-area">
            {phoneStep === 'enter' ? (
              <form onSubmit={handlePhoneSend} className="auth-form">
                <label className="auth-label" htmlFor="auth-phone">Phone number</label>
                <input
                  id="auth-phone"
                  className="auth-input"
                  type="tel"
                  placeholder="+1 555 000 0000"
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                  autoComplete="tel"
                  required
                />
                <p className="auth-hint">Include country code, e.g. +1 for US</p>
                {error && <p className="auth-error">{error}</p>}
                <button className="btn btn--primary btn--lg auth-submit" type="submit" disabled={loading}>
                  {loading ? 'Sending…' : 'Send code'}
                </button>
              </form>
            ) : (
              <form onSubmit={handlePhoneVerify} className="auth-form">
                <p className="auth-hint">Enter the 6-digit code sent to <strong>{phone}</strong></p>
                <input
                  className="auth-input auth-input--otp"
                  type="text"
                  inputMode="numeric"
                  maxLength={6}
                  placeholder="000000"
                  value={otp}
                  onChange={(e) => setOtp(e.target.value.replace(/\D/g, ''))}
                  autoComplete="one-time-code"
                  required
                />
                {error && <p className="auth-error">{error}</p>}
                <button className="btn btn--primary btn--lg auth-submit" type="submit" disabled={loading || otp.length < 6}>
                  {loading ? 'Verifying…' : 'Verify code'}
                </button>
                <button type="button" className="btn btn--ghost btn--sm" onClick={() => { setPhoneStep('enter'); setOtp(''); resetError(); }}>
                  ← Change number
                </button>
              </form>
            )}
          </div>
        )}

      </div>
    </div>
  );
}
