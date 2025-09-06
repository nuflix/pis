'use client';
import { useState, useEffect } from 'react';

type Msg = { id: string; ime: string; poruka: string; created_at: string };

export default function Home() {
  const [name, setName] = useState('');
  const [body, setBody] = useState('');
  const [shard, setShard] = useState<'serverA' | 'serverB'>('serverA');
  const [msg, setMsg] = useState<string | null>(null);

  const [tab, setTab] = useState<'all' | 'serverA' | 'serverB'>('all');
  const [messages, setMessages] = useState<Msg[]>([]);

  const loadMessages = async (tabSel: typeof tab) => {
    const res = await fetch(`/api/messages?shard=${tabSel}`);
    const data = await res.json();
    if (data.ok) {
      // sortiraj po datumu
      const sorted = data.messages.sort(
        (a: Msg, b: Msg) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
      );
      setMessages(sorted);
    }
  };

  useEffect(() => {
    loadMessages(tab);
  }, [tab]);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    const res = await fetch('/api/messages', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name, body, shard }),
    });
    const data = await res.json();
    if (data.ok) {
      setMsg(`Sačuvano na ${data.shard} (pod: ${data.pod})`);
      setBody('');
      loadMessages(tab); // refresh liste
    } else {
      setMsg(`Greška: ${data.error}`);
    }
  };

  return (
    <main style={{ maxWidth: 600, margin: '40px auto', fontFamily: 'system-ui' }}>
      <h1>Pošalji poruku</h1>
      <form onSubmit={submit} style={{ display: 'grid', gap: 12 }}>
        <input placeholder="Ime" value={name} onChange={e => setName(e.target.value)} required />
        <textarea placeholder="Poruka" value={body} onChange={e => setBody(e.target.value)} required />
        <select value={shard} onChange={e => setShard(e.target.value as any)}>
          <option value="serverA">serverA</option>
          <option value="serverB">serverB</option>
        </select>
        <button type="submit">Pošalji</button>
      </form>
      {msg && <p style={{ marginTop: 12 }}>{msg}</p>}

      <hr style={{ margin: '24px 0' }} />

      <div style={{ display: 'flex', gap: 12, marginBottom: 16 }}>
        {['all', 'serverA', 'serverB'].map(t => (
          <button
            key={t}
            onClick={() => setTab(t as any)}
            style={{
              padding: '6px 12px',
              borderRadius: 6,
              border: tab === t ? '2px solid black' : '1px solid gray',
              background: tab === t ? '#eee' : 'white',
            }}
          >
            {t}
          </button>
        ))}
      </div>

      <ul style={{ listStyle: 'none', padding: 0 }}>
        {messages.map(m => (
          <li key={m.id} style={{ borderBottom: '1px solid #ddd', padding: '8px 0' }}>
            <strong>{m.ime}</strong>: {m.poruka}
            <div style={{ fontSize: '0.8em', color: '#555' }}>
              {new Date(m.created_at).toLocaleString()}
            </div>
          </li>
        ))}
        {messages.length === 0 && <p>Nema poruka za {tab}</p>}
      </ul>
    </main>
  );
}
