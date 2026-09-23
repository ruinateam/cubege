import { computed, onBeforeUnmount, ref, watch } from 'vue'
import { scoreScale, type Question } from '@/data/exam'
import { ensureAnonymousSession, getAttemptResults, getVariantQuestions, saveAnswer, startAttempt, submitAttempt, type AttemptReview, type ExamVariant } from '@/lib/supabase'

export function useExamAttempt() {
  const questions = ref<Question[]>([])
  const currentIndex = ref(0)
  const answers = ref<Record<number, string>>({})
  const secondsLeft = ref(0)
  const savedAt = ref('')
  const authMessage = ref('')
  const activeAttemptId = ref<string | null>(null)
  const activeSlug = ref('')
  const activeScale = ref<number[]>(scoreScale)
  const activeTitle = ref('')
  const serverScore = ref({ primary: 0, secondary: 0 })
  const serverReview = ref<Record<number, AttemptReview>>({})
  const isSubmitting = ref(false)
  const isLoading = ref(false)
  let timer: number | undefined

  const question = computed(() => questions.value[currentIndex.value])
  const answeredCount = computed(() => Object.values(answers.value).filter((value) => value.trim()).length)
  const maxPrimary = computed(() => Math.max(activeScale.value.length - 1, 0))
  const shortCount = computed(() => questions.value.filter((item) => item.kind === 'short').length)
  const primaryScore = computed(() => serverScore.value.primary)
  const secondaryScore = computed(() => serverScore.value.secondary || activeScale.value[Math.min(primaryScore.value, activeScale.value.length - 1)] || 0)
  const formattedTime = computed(() => `${String(Math.floor(secondsLeft.value / 60)).padStart(2, '0')}:${String(secondsLeft.value % 60).padStart(2, '0')}`)
  const rank = computed(() => secondaryScore.value >= 90 ? 'админ' : secondaryScore.value >= 80 ? 'про' : secondaryScore.value >= 70 ? 'читер' : secondaryScore.value >= 60 ? 'мастер' : secondaryScore.value >= 50 ? 'железник' : secondaryScore.value >= 40 ? 'тихоня' : secondaryScore.value >= 20 ? 'деревенщина' : secondaryScore.value >= 10 ? 'новичок' : 'нубик')

  function draftKey() { return `cubege-draft:${activeSlug.value || 'open-2026'}` }
  function startTimer(onExpire: () => void) { window.clearInterval(timer); timer = window.setInterval(() => secondsLeft.value <= 1 ? onExpire() : secondsLeft.value--, 1000) }

  async function start(variant: ExamVariant, onExpire: () => void) {
    isLoading.value = true
    try {
      await ensureAnonymousSession()
      const loaded = await getVariantQuestions(variant.slug)
      if (!loaded.length) throw new Error('Variant has no questions')
      activeSlug.value = variant.slug
      activeScale.value = variant.score_scale.length ? variant.score_scale : scoreScale
      activeTitle.value = variant.title
      questions.value = loaded
      currentIndex.value = 0
      secondsLeft.value = variant.duration_seconds
      answers.value = JSON.parse(localStorage.getItem(draftKey()) ?? '{}')
      activeAttemptId.value = await startAttempt(variant.slug)
      startTimer(onExpire)
    } finally {
      isLoading.value = false
    }
  }

  async function persist() { if (activeAttemptId.value) await Promise.all(Object.entries(answers.value).map(([position, value]) => saveAnswer(activeAttemptId.value!, Number(position), value))) }
  async function submit() { if (isSubmitting.value || !activeAttemptId.value) return false; isSubmitting.value = true; try { await persist(); const score = await submitAttempt(activeAttemptId.value); serverScore.value = { primary: score.primary_score, secondary: score.secondary_score }; serverReview.value = Object.fromEntries((await getAttemptResults(activeAttemptId.value)).map((item) => [item.question_position, item])); window.clearInterval(timer); return true } catch { authMessage.value = 'Не удалось отправить вариант. Проверьте соединение и попробуйте ещё раз.'; return false } finally { isSubmitting.value = false } }
  function setQuestion(index: number) { currentIndex.value = index; window.scrollTo({ top: 0, behavior: 'smooth' }) }
  function reset() { answers.value = {}; currentIndex.value = 0; secondsLeft.value = 0; activeAttemptId.value = null; serverScore.value = { primary: 0, secondary: 0 }; serverReview.value = {}; localStorage.removeItem(draftKey()) }

  watch(answers, (value) => { localStorage.setItem(draftKey(), JSON.stringify(value)); savedAt.value = new Intl.DateTimeFormat('ru-RU', { hour: '2-digit', minute: '2-digit' }).format(new Date()) }, { deep: true })
  onBeforeUnmount(() => window.clearInterval(timer))
  return { questions, question, currentIndex, answers, secondsLeft, formattedTime, savedAt, authMessage, answeredCount, maxPrimary, shortCount, primaryScore, secondaryScore, rank, activeTitle, serverReview, isSubmitting, isLoading, start, submit, setQuestion, reset }
}
