import { onBeforeUnmount, onMounted, ref } from 'vue'
import { ensureAnonymousSession, setDeviceId, claimGuestData, signInWithTwitch, supabase } from '@/lib/supabase'
import { ensureDeviceId } from '@/lib/device'

export type AuthUser = { label: string; login: string | null; avatarUrl: string | null; isAnonymous: boolean; isAdmin: boolean }
type SupabaseUser = { email?: string | null; is_anonymous?: boolean; user_metadata: Record<string, unknown>; identities?: Array<{ provider?: string; identity_data?: Record<string, unknown> }> }

function validImageUrl(value: unknown) {
  if (typeof value !== 'string') return null
  try { const url = new URL(value); return url.protocol === 'https:' ? url.toString() : null } catch { return null }
}
function firstText(...values: unknown[]) { return values.find((value): value is string => typeof value === 'string' && value.trim().length > 0) ?? null }

export function useAuth() {
  const authUser = ref<AuthUser | null>(null)
  const authMessage = ref('')
  let unsubscribe: (() => void) | undefined

  async function enrichTwitchProfile(login: string) {
    try {
      const response = await fetch(`https://api.ivr.fi/v2/twitch/user?login=${encodeURIComponent(login)}`)
      const data: unknown = await response.json()
      if (!response.ok || !Array.isArray(data) || !data[0] || typeof data[0] !== 'object' || authUser.value?.login !== login) return
      const profile = data[0] as Record<string, unknown>
      authUser.value = { ...authUser.value, label: firstText(profile.displayName, authUser.value.label)!, avatarUrl: validImageUrl(profile.logo) ?? authUser.value.avatarUrl }
    } catch { /* Supabase metadata remains the fallback. */ }
  }

  function setAuthUser(user: SupabaseUser | null) {
    if (!user) { authUser.value = null; return }
    const identity = user.identities?.find((item) => item.provider === 'twitch')?.identity_data ?? {}
    const login = firstText(identity.preferred_username, identity.login, identity.user_name, user.user_metadata.preferred_username, user.user_metadata.user_name, user.user_metadata.nickname)
    const label = firstText(identity.display_name, identity.full_name, identity.name, user.user_metadata.display_name, user.user_metadata.full_name, user.user_metadata.name, login, user.email)
    authUser.value = { label: label || (user.is_anonymous ? 'Гость' : 'Twitch подключён'), login, avatarUrl: validImageUrl(identity.picture) ?? validImageUrl(identity.avatar_url) ?? validImageUrl(user.user_metadata.avatar_url), isAnonymous: Boolean(user.is_anonymous), isAdmin: user.user_metadata.role === 'admin' }
    if (!user.is_anonymous && login) void enrichTwitchProfile(login)
  }

  async function bindDevice() {
    const deviceId = ensureDeviceId()
    if (!deviceId) return
    try { await setDeviceId(deviceId) } catch { /* Профиль уже привязан или сессия гостевая без профиля. */ }
    try { if (authUser.value && !authUser.value.isAnonymous) await claimGuestData(deviceId) } catch { /* Нечего забирать. */ }
  }

  async function initialize() {
    try {
      await ensureAnonymousSession()
      if (!supabase) return
      const { data } = await supabase.auth.getUser()
      setAuthUser(data.user)
      void bindDevice()
      const { data: listener } = supabase.auth.onAuthStateChange((_event, session) => { setAuthUser(session?.user ?? null); if (session?.user) void bindDevice() })
      unsubscribe = () => listener.subscription.unsubscribe()
    } catch { authMessage.value = 'Не удалось создать анонимную сессию. Черновик сохранится только на этом устройстве.' }
  }

  async function connectTwitch() {
    try { await signInWithTwitch() }
    catch { authMessage.value = supabase ? 'Не удалось начать вход через Twitch. Попробуйте ещё раз.' : 'Twitch станет доступен после настройки Supabase.' }
  }
  async function signOut() { if (supabase) await supabase.auth.signOut(); authUser.value = null }

  onMounted(initialize)
  onBeforeUnmount(() => unsubscribe?.())
  return { authUser, authMessage, connectTwitch, signOut }
}
