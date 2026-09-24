import { createClient } from '@supabase/supabase-js'
import type { Question } from '@/data/exam'
import type { NicknameStatus } from '@/types/leaderboard'

const url = import.meta.env.VITE_SUPABASE_URL
const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY

export const supabase = url && key ? createClient(url, key) : null

export async function ensureAnonymousSession() {
  if (!supabase) return null
  const { data: { session } } = await supabase.auth.getSession()
  if (session) return session
  const { data, error } = await supabase.auth.signInAnonymously()
  if (error) throw error
  return data.session
}

export async function signInWithTwitch() {
  if (!supabase) throw new Error('Supabase is not configured')
  const { error } = await supabase.auth.signInWithOAuth({
    provider: 'twitch',
    options: { redirectTo: window.location.origin + import.meta.env.BASE_URL },
  })
  if (error) throw error
}

export type AttemptScore = { primary_score: number; secondary_score: number }
export type AttemptReview = { question_position: number; is_correct: boolean | null; correct_answer: string | null; solution: string | null; awarded_points: number; max_points: number; graded: boolean }
export type ActiveAttempt = { attempt_id: string; variant_slug: string; variant_title: string; expires_at: string; score_scale: number[]; answers: Record<string, string> }
export type GradingAttempt = { attempt_id: string; user_email: string | null; variant_slug: string; variant_title: string; submitted_at: string; primary_score: number; secondary_score: number; long_answered: number; long_graded: number }
export type LongAnswer = { question_position: number; prompt: string; max_points: number; value: string; awarded_points: number; graded: boolean; solution: string | null }
export type { NicknameStatus } from '@/types/leaderboard'
export type UserProfile = { nickname: string | null; nickname_status: NicknameStatus }
export type PendingNickname = { user_id: string; user_email: string | null; nickname: string; created_at: string }
export type LeaderboardRow = { nickname: string; generated_nickname: boolean; verified: boolean; is_current_user: boolean; best_secondary: number; completed: number; latest: string }
export type UserStatistics = { completed_attempts: number; best_secondary_score: number | null; average_secondary_score: number | null; latest_submitted_at: string | null }
export type LatestSubmittedAttempt = {
  attempt_id: string
  submitted_at: string
  secondary_score: number
  leaderboard_visible: boolean
  leaderboard_visibility_decided_at: string | null
}
export type VariantQuestion = { position: number; kind: 'short' | 'long'; points: number; prompt: string; options: string[] | null; image_path: string | null }

export function questionImageUrl(path: string) {
  if (!supabase) return ''
  return supabase.storage.from('exam-images').getPublicUrl(path).data.publicUrl
}
export type ExamVariant = { slug: string; title: string; duration_seconds: number; question_count: number; max_primary: number; score_scale: number[] }

function client() {
  if (!supabase) throw new Error('Supabase is not configured')
  return supabase
}

export async function getVariants(): Promise<ExamVariant[]> {
  const { data, error } = await client().rpc('list_variants')
  if (error) throw error
  return data as ExamVariant[]
}

export async function startAttempt(slug: string) {
  const { data, error } = await client().rpc('start_attempt', { target_slug: slug })
  if (error) throw error
  return data as string
}

export async function getAttemptDeadline(attemptId: string) {
  const { data, error } = await client().rpc('attempt_deadline', { target_attempt: attemptId })
  if (error) throw error
  return data as string
}

export async function getActiveAttempt(attemptId: string) {
  const { data, error } = await client().rpc('active_attempt', { target_attempt: attemptId })
  if (error) throw error
  return (data?.[0] ?? null) as ActiveAttempt | null
}

export async function getVariantQuestions(slug: string): Promise<Question[]> {
  const { data, error } = await client().rpc('variant_questions', { target_slug: slug })
  if (error) throw error
  return (data as VariantQuestion[]).map((item) => ({ id: item.position, kind: item.kind, points: item.points, prompt: item.prompt, options: item.options ?? undefined, imagePath: item.image_path ?? undefined, autonumber: !item.options?.some((option) => /^[А-ЯЁA-Z0-9]+\)/.test(option)) }))
}

export async function saveAnswer(attemptId: string, position: number, value: string) {
  const { error } = await client().rpc('save_answer', { target_attempt: attemptId, target_position: position, submitted_value: value })
  if (error) throw error
}

export async function submitAttempt(attemptId: string) {
  const { data, error } = await client().rpc('submit_attempt', { target_attempt: attemptId })
  if (error) throw error
  return data[0] as AttemptScore
}

export async function getAttemptResults(attemptId: string) {
  const { data, error } = await client().rpc('attempt_results', { target_attempt: attemptId })
  if (error) throw error
  return data as AttemptReview[]
}

export async function getUserStatistics() {
  const { data, error } = await client().rpc('user_statistics')
  if (error) throw error
  return data[0] as UserStatistics
}

export async function setDeviceId(deviceId: string) {
  const { error } = await client().rpc('set_device_id', { device: deviceId })
  if (error) throw error
}

export async function claimGuestData(deviceId: string) {
  const { error } = await client().rpc('claim_guest_data', { device: deviceId })
  if (error) throw error
}

export async function getAttemptsForGrading() {
  const { data, error } = await client().rpc('attempts_for_grading')
  if (error) throw error
  return data as GradingAttempt[]
}

export async function getAttemptLongAnswers(attemptId: string) {
  const { data, error } = await client().rpc('attempt_long_answers', { target_attempt: attemptId })
  if (error) throw error
  return data as LongAnswer[]
}

export async function gradeAnswer(attemptId: string, position: number, awarded: number) {
  const { error } = await client().rpc('grade_answer', { target_attempt: attemptId, target_position: position, awarded })
  if (error) throw error
}

export async function getMyProfile() {
  const { data, error } = await client().from('profiles').select('nickname,nickname_status').maybeSingle()
  if (error) throw error
  return data as UserProfile | null
}

export async function requestNickname(nickname: string) {
  const { data, error } = await client().rpc('request_nickname', { requested_nickname: nickname })
  if (error) throw error
  return data as NicknameStatus
}

export async function syncTwitchNickname() {
  const { data, error } = await client().rpc('sync_twitch_nickname')
  if (error) throw error
  return data as NicknameStatus | null
}

export async function getPendingNicknames() {
  const { data, error } = await client().rpc('pending_nicknames')
  if (error) throw error
  return data as PendingNickname[]
}

export async function reviewNickname(userId: string, decision: 'approved' | 'rejected') {
  const { error } = await client().rpc('review_nickname', { target_user: userId, decision })
  if (error) throw error
}

export async function getLeaderboard(limit = 20) {
  const { data, error } = await client().rpc('leaderboard', { limit_n: limit })
  if (error) throw error
  return data as LeaderboardRow[]
}

export async function setAttemptLeaderboardVisibility(attemptId: string, visible: boolean) {
  const { data, error } = await client().rpc('set_attempt_leaderboard_visibility', {
    target_attempt: attemptId,
    visible,
  })
  if (error) throw error
  return data as boolean
}

export async function getLatestSubmittedAttempt() {
  const { data, error } = await client().rpc('latest_submitted_attempt')
  if (error) throw error
  return (data?.[0] ?? null) as LatestSubmittedAttempt | null
}
