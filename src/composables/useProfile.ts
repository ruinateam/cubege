import { ref } from 'vue'
import { getUserStatistics, type UserStatistics } from '@/lib/supabase'

export function useProfile() {
  const userStatistics = ref<UserStatistics | null>(null)
  async function loadStatistics() { try { userStatistics.value = await getUserStatistics() } catch { userStatistics.value = null } }
  return { userStatistics, loadStatistics }
}
