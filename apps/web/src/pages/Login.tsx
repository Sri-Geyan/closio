import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';

export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [totpCode, setTotpCode] = useState('');
  const [showTotp, setShowTotp] = useState(false);
  const navigate = useNavigate();

  const handleLogin = (e: React.FormEvent) => {
    e.preventDefault();
    if (!showTotp) {
      // Simulate Supabase login success, moving to TOTP step
      setShowTotp(true);
    } else {
      // Simulate TOTP validation
      if (totpCode.length === 6) {
        navigate('/dashboard');
      } else {
        alert('Invalid TOTP code');
      }
    }
  };

  return (
    <div className="auth-container">
      <div className="auth-card">
        <h1 className="auth-title">Closio Web</h1>
        <form onSubmit={handleLogin}>
          {!showTotp ? (
            <>
              <input
                type="email"
                className="auth-input"
                placeholder="Email Address"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
              />
              <input
                type="password"
                className="auth-input"
                placeholder="Password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
              />
              <button type="submit" className="auth-button">
                Sign In
              </button>
            </>
          ) : (
            <>
              <p style={{ textAlign: 'center', marginBottom: '20px' }}>
                Please enter the 6-digit code from your authenticator app.
              </p>
              <input
                type="text"
                className="auth-input"
                placeholder="000000"
                value={totpCode}
                onChange={(e) => setTotpCode(e.target.value)}
                maxLength={6}
                required
              />
              <button type="submit" className="auth-button">
                Verify
              </button>
            </>
          )}
        </form>
      </div>
    </div>
  );
}
