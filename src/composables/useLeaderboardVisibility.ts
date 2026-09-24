import { computed, toValue, type MaybeRefOrGetter } from 'vue'
import type { LeaderboardProfile, LeaderboardVisibilityStatus } from '@/types/leaderboard'

export const leaderboardStatusLabels: Record<LeaderboardVisibilityStatus, string> = {
  visible_anonymous: 'В топе анонимно',
  pending: 'На проверке · в топе анонимно',
  visible: 'В топе',
  rejected: 'Нужно изменить ник · в топе анонимно',
}

export function getLeaderboardVisibilityStatus(profile: LeaderboardProfile | null | undefined): LeaderboardVisibilityStatus {
  if (!profile?.nickname) return 'visible_anonymous'
  if (profile.nickname_status === 'approved') return 'visible'
  if (profile.nickname_status === 'rejected') return 'rejected'
  return 'pending'
}

export function useLeaderboardVisibility(profile: MaybeRefOrGetter<LeaderboardProfile | null | undefined>) {
  return computed(() => getLeaderboardVisibilityStatus(toValue(profile)))
}
