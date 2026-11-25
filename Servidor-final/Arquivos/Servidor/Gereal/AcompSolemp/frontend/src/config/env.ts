export type DataSource = 'local' | 'supabase'

/** Injetado em runtime por `public/server-config.js` (servidor portátil). */
type RuntimeServerConfig = {
  dataSource?: DataSource
  supabaseUrl?: string
  supabaseAnonKey?: string
  /** E-mail único autorizado como Portal do Gestor (Dashboard do servidor). */
  gestorEmail?: string
}

function runtimeConfig(): RuntimeServerConfig {
  if (typeof window === 'undefined') return {}
  const w = window as Window & { __ACOMP_SERVER__?: RuntimeServerConfig }
  return w.__ACOMP_SERVER__ ?? {}
}

function readDataSource(): DataSource {
  const fromRuntime = runtimeConfig().dataSource
  if (fromRuntime === 'supabase' || fromRuntime === 'local') return fromRuntime
  const value = import.meta.env.VITE_DATA_SOURCE
  return value === 'supabase' ? 'supabase' : 'local'
}

/**
 * Se a página está em HTTPS e a URL do Supabase veio em HTTP no mesmo host,
 * sobe para HTTPS. Evita mixed content (modal "Sistema fora do ar").
 */
function alignSupabaseUrlToPage(raw: string): string {
  const trimmed = raw.trim()
  if (!trimmed || typeof window === 'undefined') return trimmed
  try {
    const configured = new URL(trimmed)
    const page = new URL(window.location.href)
    if (
      configured.hostname === page.hostname &&
      page.protocol === 'https:' &&
      configured.protocol === 'http:'
    ) {
      configured.protocol = 'https:'
      return configured.toString().replace(/\/+$/, '')
    }
  } catch {
    // mantém o valor original
  }
  return trimmed
}

function readSupabaseUrl(): string {
  return alignSupabaseUrlToPage(
    (runtimeConfig().supabaseUrl || import.meta.env.VITE_SUPABASE_URL || '').trim(),
  )
}

function readSupabaseAnonKey(): string {
  return (runtimeConfig().supabaseAnonKey || import.meta.env.VITE_SUPABASE_ANON_KEY || '').trim()
}

function readAllowedGestorEmail(): string {
  const fromRuntime = (runtimeConfig().gestorEmail || '').trim().toLowerCase()
  if (fromRuntime) return fromRuntime
  return (import.meta.env.VITE_GESTOR_GOOGLE_EMAIL ?? '').trim().toLowerCase()
}

export const env = {
  dataSource: readDataSource(),
  isSupabase: readDataSource() === 'supabase',
  /** E-mail opcional do gestor no bootstrap local (deve ser @marinha.mil.br) */
  gestorGoogleEmail: (import.meta.env.VITE_GESTOR_GOOGLE_EMAIL ?? '').trim().toLowerCase(),
  /**
   * Quando definido (Dashboard do servidor / server-config.js), só este e-mail
   * pode cadastrar ou entrar no Portal do Gestor.
   */
  allowedGestorEmail: readAllowedGestorEmail(),
  supabase: {
    url: readSupabaseUrl(),
    anonKey: readSupabaseAnonKey(),
  },
} as const

export function isSupabaseConfigured(): boolean {
  return Boolean(env.supabase.url && env.supabase.anonKey)
}

/** Bloqueia Portal do Gestor se o servidor definiu outro e-mail autorizado. */
export function assertAllowedGestorEmail(email: string): void {
  const allowed = env.allowedGestorEmail
  if (!allowed) return
  const current = email.trim().toLowerCase()
  if (current !== allowed) {
    throw new Error(
      `Apenas o e-mail do gestor configurado no Dashboard do servidor pode usar o Portal do Gestor (${allowed}).`,
    )
  }
}
