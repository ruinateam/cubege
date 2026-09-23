const STORAGE_KEY = 'cubege-device-id'

function randomId() {
  if (typeof crypto !== 'undefined' && 'randomUUID' in crypto) return crypto.randomUUID()
  return `dev-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 14)}`
}

export function ensureDeviceId() {
  try {
    const existing = localStorage.getItem(STORAGE_KEY)
    if (existing) return existing
    const created = randomId()
    localStorage.setItem(STORAGE_KEY, created)
    return created
  } catch {
    return null
  }
}
