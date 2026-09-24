export type NicknameStatus = 'pending' | 'approved' | 'rejected'

export type LeaderboardVisibilityStatus =
  | 'visible_anonymous'
  | 'pending'
  | 'visible'
  | 'rejected'

export type LeaderboardProfile = {
  nickname: string | null
  nickname_status: NicknameStatus
}
