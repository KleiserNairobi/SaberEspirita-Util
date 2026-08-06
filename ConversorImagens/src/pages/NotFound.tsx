import { Link } from 'wouter';

export default function NotFound() {
  return (
    <div
      style={{
        minHeight: '100dvh',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 16,
        background: 'var(--bg)',
        textAlign: 'center',
        padding: 24,
      }}
    >
      <div style={{ fontSize: '4rem', lineHeight: 1 }}>🖼️</div>
      <h1 style={{ fontSize: '5rem', fontWeight: 900, color: 'var(--primary)', lineHeight: 1 }}>
        404
      </h1>
      <h2 style={{ fontSize: '1.4rem', fontWeight: 700, color: 'var(--text-primary)' }}>
        Página não encontrada
      </h2>
      <p style={{ color: 'var(--text-secondary)', fontSize: '0.95rem', maxWidth: 360 }}>
        A página que você procura não existe ou foi movida.
      </p>
      <Link href="/" className="btn-primary" style={{ marginTop: 8 }}>
        ← Voltar ao Conversor
      </Link>
    </div>
  );
}
