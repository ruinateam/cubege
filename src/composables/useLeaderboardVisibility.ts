import { computed, toValue, type MaybeRefOrGetter } from 'vue'
import type { LeaderboardProfile, LeaderboardVisibilityStatus } from '@/types/leaderboard'

export const leaderboardStatusLabels: Record<LeaderboardVisibilityStatus, string> = {
  no_nickname: 'Ник не выбран',
  pending: 'Ник на проверке',
  visible: 'В топе',
  rejected: 'Нужно изменить ник',
}

export function getLeaderboardVisibilityStatus(profile: LeaderboardProfile | null | undefined): LeaderboardVisibilityStatus {
  if (!profile?.nickname) return 'no_nickname'
  if (profile.nickname_status === 'approved') return 'visible'
  if (profile.nickname_status === 'rejected') return 'rejected'
  return 'pending'
}

export function useLeaderboardVisibility(profile: MaybeRefOrGetter<LeaderboardProfile | null | undefined>) {
  return computed(() => getLeaderboardVisibilityStatus(toValue(profile)))
}
