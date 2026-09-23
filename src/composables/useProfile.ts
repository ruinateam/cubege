import { ref } from 'vue'
import { getMyProfile, getUserStatistics, requestNickname, type UserProfile, type UserStatistics } from '@/lib/supabase'

export function useProfile() {
  const userStatistics = ref<UserStatistics | null>(null)
  const profile = ref<UserProfile | null>(null)
  const nicknameDraft = ref('')
  const nicknameMessage = ref('')
  const isRequestingNickname = ref(false)

  async function loadStatistics() { try { userStatistics.value = await getUserStatistics() } catch { userStatistics.value = null } }
  async function loadProfile() {
    nicknameMessage.value = ''
    try {
      profile.value = await getMyProfile()
      if (profile.value?.nickname) nicknameDraft.value = profile.value.nickname
    } catch { profile.value = null }
  }
  async function submitNickname() {
    const value = nicknameDraft.value.trim()
    if (!/^[A-Za-z0-9_]{3,16}$/.test(value)) {
      nicknameMessage.value = 'Ник: 3–16 латинских букв, цифр или _.'
      return
    }
    isRequestingNickname.value = true
    nicknameMessage.value = ''
    try {
      const status = await requestNickname(value)
      await loadProfile()
      nicknameMessage.value = status === 'approved' ? 'Ник принят — ты в топе.' : 'Отправлено на проверку.'
    } catch {
      nicknameMessage.value = 'Не удалось отправить ник. Возможно, он уже занят.'
    } finally {
      isRequestingNickname.value = false
    }
  }
  return { userStatistics, loadStatistics, profile, nicknameDraft, nicknameMessage, isRequestingNickname, loadProfile, submitNickname }
}
