import { createClient } from '@supabase/supabase-js'
import type { Question } from '@/data/exam'

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
export type AttemptReview = { question_position: number; is_correct: boolean | null; correct_answer: string | null; solution: string | null }
export type UserStatistics = { completed_attempts: number; best_secondary_score: number | null; average_secondary_score: number | null; latest_submitted_at: string | null }
export type VariantQuestion = { position: number; kind: 'short' | 'long'; points: number; prompt: string; options: string[] | null }
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

export async function getVariantQuestions(slug: string): Promise<Question[]> {
  const { data, error } = await client().rpc('variant_questions', { target_slug: slug })
  if (error) throw error
  return (data as VariantQuestion[]).map((item) => ({ id: item.position, kind: item.kind, points: item.points, prompt: item.prompt, options: item.options ?? undefined }))
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
