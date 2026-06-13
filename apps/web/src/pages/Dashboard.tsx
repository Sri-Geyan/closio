import React, { useState } from 'react';
import { Routes, Route, useNavigate } from 'react-router-dom';

const MOCK_HUBS = [
  { id: '1', name: 'Weekend Warriors' },
  { id: '2', name: 'Movie Geeks' },
  { id: '3', name: 'Foodies' },
];

export default function Dashboard() {
  const [activeHub, setActiveHub] = useState(MOCK_HUBS[0].id);
  const navigate = useNavigate();

  return (
    <div className="app-container">
      <div className="sidebar">
        <div className="sidebar-header">
          Closio
        </div>
        <div className="hub-list">
          {MOCK_HUBS.map(hub => (
            <div 
              key={hub.id} 
              className={`hub-item ${activeHub === hub.id ? 'active' : ''}`}
              onClick={() => setActiveHub(hub.id)}
            >
              <div className="hub-item-name">{hub.name}</div>
            </div>
          ))}
        </div>
      </div>
      
      <div className="main-content">
        <div className="main-header">
          {MOCK_HUBS.find(h => h.id === activeHub)?.name}
        </div>
        <div style={{ flex: 1, padding: '20px', display: 'flex', flexDirection: 'column' }}>
          <div style={{ display: 'flex', gap: '20px', borderBottom: '1px solid #333', paddingBottom: '10px', marginBottom: '20px' }}>
            <span style={{ cursor: 'pointer', color: 'var(--primary-color)', fontWeight: 'bold' }}>Chat</span>
            <span style={{ cursor: 'pointer', color: 'var(--text-secondary)' }}>Calendar</span>
            <span style={{ cursor: 'pointer', color: 'var(--text-secondary)' }}>Splits</span>
          </div>
          
          <div style={{ flex: 1, backgroundColor: 'var(--surface-color)', borderRadius: '8px', padding: '20px', overflowY: 'auto' }}>
            {/* Placeholder for Chat View */}
            <div style={{ textAlign: 'center', color: 'var(--text-secondary)', marginTop: '50px' }}>
              <p>Chat history for {MOCK_HUBS.find(h => h.id === activeHub)?.name}</p>
              <p style={{ fontSize: '12px', marginTop: '10px' }}>(Voice and Video rooms are disabled on Web Companion)</p>
            </div>
          </div>
          
          <div style={{ marginTop: '20px', display: 'flex', gap: '10px' }}>
            <input 
              type="text" 
              className="auth-input" 
              placeholder="Type a message..." 
              style={{ marginBottom: 0, flex: 1 }}
            />
            <button className="auth-button" style={{ width: '100px' }}>Send</button>
          </div>
        </div>
      </div>
    </div>
  );
}
