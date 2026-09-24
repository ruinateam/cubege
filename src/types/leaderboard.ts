export type NicknameStatus = 'pending' | 'approved' | 'rejected'

export type LeaderboardVisibilityStatus =
  | 'no_nickname'
  | 'pending'
  | 'visible'
  | 'rejected'

export type ResultPublicationStatus = 'undecided' | 'private' | 'published'

export type LeaderboardProfile = {
  nickname: string | null
  nickname_status: NicknameStatus
}
