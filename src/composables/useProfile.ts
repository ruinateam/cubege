import { ref } from 'vue'
import { getLatestSubmittedAttempt, getMyProfile, getUserStatistics, requestNickname, setAttemptLeaderboardVisibility, syncTwitchNickname, type LatestSubmittedAttempt, type UserProfile, type UserStatistics } from '@/lib/supabase'
import { useLeaderboardVisibility } from '@/composables/useLeaderboardVisibility'

export function useProfile() {
  const userStatistics = ref<UserStatistics | null>(null)
  const profile = ref<UserProfile | null>(null)
  const nicknameDraft = ref('')
  const nicknameMessage = ref('')
  const isRequestingNickname = ref(false)
  const isProfileLoaded = ref(false)
  const profileLoadError = ref(false)
  const latestAttempt = ref<LatestSubmittedAttempt | null>(null)
  const latestAttemptMessage = ref('')
  const isUpdatingLatestAttempt = ref(false)
  const leaderboardStatus = useLeaderboardVisibility(profile)

  async function loadStatistics() { try { userStatistics.value = await getUserStatistics() } catch { userStatistics.value = null } }
  async function loadProfile() {
    nicknameMessage.value = ''
    profileLoadError.value = false
    isProfileLoaded.value = false
    try {
      try { await syncTwitchNickname() } catch { /* A profile can still load when Twitch sync is unavailable. */ }
      profile.value = await getMyProfile()
      if (profile.value?.nickname) nicknameDraft.value = profile.value.nickname
    } catch {
      profile.value = null
      profileLoadError.value = true
    } finally {
      isProfileLoaded.value = true
    }
  }
  async function loadLatestAttempt() {
    latestAttemptMessage.value = ''
    try { latestAttempt.value = await getLatestSubmittedAttempt() }
    catch {
      latestAttempt.value = null
      latestAttemptMessage.value = 'Не удалось загрузить последнюю попытку. Попробуй открыть профиль позже.'
    }
  }
  async function setLatestAttemptVisibility(visible: boolean) {
    if (!latestAttempt.value || isUpdatingLatestAttempt.value) return
    isUpdatingLatestAttempt.value = true
    latestAttemptMessage.value = ''
    try {
      await setAttemptLeaderboardVisibility(latestAttempt.value.attempt_id, visible)
      await loadLatestAttempt()
    } catch {
      latestAttemptMessage.value = 'Не удалось изменить публикацию. Проверь соединение и попробуй ещё раз.'
    } finally {
      isUpdatingLatestAttempt.value = false
    }
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
      nicknameMessage.value = status === 'approved' ? 'Ник принят. Он появится в результате, если ты решишь опубликовать его в топе.' : 'Ник отправлен на проверку.'
    } catch {
      nicknameMessage.value = 'Не удалось отправить ник. Возможно, он уже занят.'
    } finally {
      isRequestingNickname.value = false
    }
  }
  function clearProfile() {
    profile.value = null
    nicknameDraft.value = ''
    nicknameMessage.value = ''
    profileLoadError.value = false
    isProfileLoaded.value = false
    latestAttempt.value = null
    latestAttemptMessage.value = ''
    isUpdatingLatestAttempt.value = false
  }
  return { userStatistics, loadStatistics, profile, nicknameDraft, nicknameMessage, isRequestingNickname, isProfileLoaded, profileLoadError, leaderboardStatus, latestAttempt, latestAttemptMessage, isUpdatingLatestAttempt, loadProfile, loadLatestAttempt, setLatestAttemptVisibility, submitNickname, clearProfile }
}
