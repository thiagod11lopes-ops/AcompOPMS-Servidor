import { useCallback, useEffect, useRef, useState } from 'react'
import { env, isSupabaseConfigured } from '@/config/env'

const POLL_MS = 8_000
const FETCH_TIMEOUT_MS = 4_000
/** Exige N falhas seguidas antes de mostrar o modal (evita falso positivo). */
const FAILS_BEFORE_OFFLINE = 2

async function pingUrl(url: string, init?: RequestInit): Promise<boolean> {
  const controller = new AbortController()
  const timer = window.setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS)
  try {
    const res = await fetch(url, {
      cache: 'no-store',
      signal: controller.signal,
      ...init,
    })
    // Qualquer resposta HTTP = servidor alcançável (inclusive 401/404/502).
    // Só rede morta / timeout deve marcar offline.
    if (init?.mode === 'no-cors') return true
    return typeof res.status === 'number'
  } catch {
    return false
  } finally {
    window.clearTimeout(timer)
  }
}

async function pingServer(): Promise<boolean> {
  const pageOrigin = window.location.origin.replace(/\/$/, '')

  // 1) Página atual (sem header custom → sem preflight CORS)
  if (await pingUrl(`${pageOrigin}/`, { method: 'GET' })) return true
  if (await pingUrl(`${pageOrigin}/login`, { method: 'GET' })) return true

  // 2) Auth health na mesma origem (sem apikey — evita OPTIONS bloqueado)
  if (await pingUrl(`${pageOrigin}/auth/v1/health`, { method: 'GET' })) return true

  // 3) Fallback no-cors (opaque)
  if (await pingUrl(`${pageOrigin}/`, { method: 'GET', mode: 'no-cors' })) return true

  if (isSupabaseConfigured()) {
    const base = env.supabase.url.replace(/\/$/, '')
    if (base && base !== pageOrigin) {
      if (await pingUrl(`${base}/auth/v1/health`, { method: 'GET' })) return true
      if (await pingUrl(base, { method: 'GET', mode: 'no-cors' })) return true
    }
  }

  return false
}

/**
 * true = rede/servidor acessiveis; false = fora do ar.
 * Só marca offline após falhas repetidas; o evento "offline" do browser
 * sozinho não abre o modal (em celular costuma ser falso positivo).
 */
export function useServerReachable(): {
  reachable: boolean
  checking: boolean
  recheck: () => void
} {
  const [reachable, setReachable] = useState(true)
  const [checking, setChecking] = useState(false)
  const failStreak = useRef(0)

  const applyResult = useCallback((ok: boolean) => {
    if (ok) {
      failStreak.current = 0
      setReachable(true)
      return
    }
    failStreak.current += 1
    if (failStreak.current >= FAILS_BEFORE_OFFLINE) {
      setReachable(false)
    }
  }, [])

  const recheck = useCallback(() => {
    setChecking(true)
    void pingServer().then((ok) => {
      if (ok) failStreak.current = 0
      else failStreak.current = FAILS_BEFORE_OFFLINE
      setReachable(ok)
      setChecking(false)
    })
  }, [])

  useEffect(() => {
    let cancelled = false

    const run = async () => {
      const ok = await pingServer()
      if (!cancelled) {
        applyResult(ok)
        setChecking(false)
      }
    }

    void run()
    const id = window.setInterval(() => {
      // Em segundo plano (celular) o fetch falha com frequência e gerava falso offline.
      if (document.visibilityState === 'hidden') return
      void run()
    }, POLL_MS)

    const onOnline = () => {
      void run()
    }
    const onOffline = () => {
      // Não fecha o sistema só com o evento do browser — confirma com ping.
      void run()
    }
    const onVisible = () => {
      if (document.visibilityState === 'visible') void run()
    }

    window.addEventListener('online', onOnline)
    window.addEventListener('offline', onOffline)
    document.addEventListener('visibilitychange', onVisible)

    return () => {
      cancelled = true
      window.clearInterval(id)
      window.removeEventListener('online', onOnline)
      window.removeEventListener('offline', onOffline)
      document.removeEventListener('visibilitychange', onVisible)
    }
  }, [applyResult])

  return { reachable, checking, recheck }
}
