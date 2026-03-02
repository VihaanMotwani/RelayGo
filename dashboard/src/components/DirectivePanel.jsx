import { useState, useCallback } from 'react';

const API_URL = 'http://localhost:8000/api/directives';

export default function DirectivePanel({ onSent }) {
  const [name, setName] = useState('');
  const [zone, setZone] = useState('');
  const [body, setBody] = useState('');
  const [priority, setPriority] = useState('high');
  const [sending, setSending] = useState(false);
  const [flash, setFlash] = useState(null); // 'success' | 'error'

  const send = useCallback(async () => {
    if (!body.trim() || !name.trim()) return;
    setSending(true);
    setFlash(null);

    try {
      const res = await fetch(API_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          kind: 'directive',
          id: crypto.randomUUID(),
          ts: Math.floor(Date.now() / 1000),
          src: `responder-${name.trim().toLowerCase().replace(/\s+/g, '-')}`,
          name: name.trim(),
          to: null,
          zone: zone.trim() || null,
          body: body.trim(),
          priority,
          hops: 0,
          ttl: 15,
        }),
      });

      if (res.ok) {
        setBody('');
        setFlash('success');
        onSent?.();
        setTimeout(() => setFlash(null), 2000);
      } else {
        setFlash('error');
        setTimeout(() => setFlash(null), 3000);
      }
    } catch {
      setFlash('error');
      setTimeout(() => setFlash(null), 3000);
    } finally {
      setSending(false);
    }
  }, [name, zone, body, priority, onSent]);

  return (
    <div style={s.container}>
      <div style={s.header}>
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M22 2L11 13" />
          <path d="M22 2L15 22L11 13L2 9L22 2Z" />
        </svg>
        <span style={s.headerLabel}>Send Directive</span>
      </div>

      <input
        style={s.input}
        type="text"
        placeholder="Responder name / badge ID"
        value={name}
        onChange={(e) => setName(e.target.value)}
      />

      <input
        style={s.input}
        type="text"
        placeholder="Zone (e.g. mission-fire)"
        value={zone}
        onChange={(e) => setZone(e.target.value)}
      />

      <textarea
        style={s.textarea}
        placeholder="Instruction for people in the disaster zone..."
        value={body}
        onChange={(e) => setBody(e.target.value)}
        rows={3}
      />

      <div style={s.bottomRow}>
        <div style={s.priorityGroup}>
          {['high', 'medium', 'low'].map((p) => (
            <button
              key={p}
              style={{
                ...s.prioBtn,
                ...(priority === p ? s.prioBtnActive : {}),
                ...(priority === p ? { borderColor: PRIO_COLORS[p], color: PRIO_COLORS[p] } : {}),
              }}
              onClick={() => setPriority(p)}
            >
              {p.charAt(0).toUpperCase() + p.slice(1)}
            </button>
          ))}
        </div>

        <button
          style={{
            ...s.sendBtn,
            opacity: (!body.trim() || !name.trim() || sending) ? 0.4 : 1,
          }}
          disabled={!body.trim() || !name.trim() || sending}
          onClick={send}
        >
          {sending ? 'Sending…' : 'Broadcast'}
        </button>
      </div>

      {flash === 'success' && (
        <div style={s.flash}>Directive sent to mesh gateway</div>
      )}
      {flash === 'error' && (
        <div style={{ ...s.flash, color: 'var(--red)' }}>Failed to send — backend offline?</div>
      )}
    </div>
  );
}

const PRIO_COLORS = {
  high: 'var(--red)',
  medium: 'var(--orange)',
  low: 'var(--green)',
};

const s = {
  container: {
    padding: '10px 12px 12px',
    borderTop: '0.5px solid var(--separator)',
    flexShrink: 0,
    display: 'flex',
    flexDirection: 'column',
    gap: 8,
  },
  header: {
    display: 'flex',
    alignItems: 'center',
    gap: 6,
    color: 'var(--text-secondary)',
    marginBottom: 2,
  },
  headerLabel: {
    fontSize: 11,
    fontWeight: 700,
    textTransform: 'uppercase',
    letterSpacing: '0.04em',
    color: 'var(--text-secondary)',
  },
  input: {
    width: '100%',
    padding: '7px 10px',
    fontSize: 12,
    fontFamily: 'var(--system-font)',
    background: 'var(--chip-bg)',
    border: '0.5px solid var(--chip-border)',
    borderRadius: 6,
    color: 'var(--text-primary)',
    outline: 'none',
  },
  textarea: {
    width: '100%',
    padding: '7px 10px',
    fontSize: 12,
    fontFamily: 'var(--system-font)',
    background: 'var(--chip-bg)',
    border: '0.5px solid var(--chip-border)',
    borderRadius: 6,
    color: 'var(--text-primary)',
    outline: 'none',
    resize: 'vertical',
    minHeight: 56,
    lineHeight: 1.5,
  },
  bottomRow: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 8,
  },
  priorityGroup: {
    display: 'flex',
    gap: 4,
  },
  prioBtn: {
    padding: '4px 10px',
    fontSize: 10,
    fontWeight: 600,
    fontFamily: 'var(--system-font)',
    borderRadius: 5,
    border: '0.5px solid var(--chip-border)',
    background: 'var(--chip-bg)',
    color: 'var(--text-tertiary)',
    cursor: 'pointer',
    transition: 'all 0.15s',
    outline: 'none',
  },
  prioBtnActive: {
    background: 'transparent',
  },
  sendBtn: {
    padding: '6px 16px',
    fontSize: 11,
    fontWeight: 700,
    fontFamily: 'var(--system-font)',
    borderRadius: 6,
    border: 'none',
    background: 'var(--tint)',
    color: '#fff',
    cursor: 'pointer',
    transition: 'opacity 0.15s',
  },
  flash: {
    fontSize: 10,
    fontWeight: 500,
    color: 'var(--green)',
    fontFamily: 'var(--mono)',
    animation: 'fadeIn 0.2s ease',
  },
};
