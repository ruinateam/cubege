import { computed, onBeforeUnmount, ref, watch } from 'vue'
import { scoreScale, type Question } from '@/data/exam'
import { ensureAnonymousSession, getActiveAttempt, getAttemptDeadline, getAttemptResults, getVariantQuestions, saveAnswer, startAttempt, submitAttempt, type AttemptDetailRow, type AttemptReview, type ExamVariant } from '@/lib/supabase'

const ACTIVE_ATTEMPT_STORAGE_KEY = 'cubege-active-attempt:v1'

type StoredAttempt = {
  version: 1
  attemptId: string
  slug: string
  title: string
  scoreScale: number[]
  expiresAt: number
  currentIndex: number
  answers: Record<number, string>
  flaggedQuestionIds: number[]
}

export function useExamAttempt() {
  const questions = ref<Question[]>([])
  const currentIndex = ref(0)
  const answers = ref<Record<number, string>>({})
  const secondsLeft = ref(0)
  const savedAt = ref('')
  const authMessage = ref('')
  const activeAttemptId = ref<string | null>(null)
  const expiresAt = ref<number | null>(null)
  const activeSlug = ref('')
  const activeScale = ref<number[]>(scoreScale)
  const activeTitle = ref('')
  const serverScore = ref({ primary: 0, secondary: 0 })
  const serverReview = ref<Record<number, AttemptReview>>({})
  const flaggedQuestionIds = ref<number[]>([])
  const isSubmitting = ref(false)
  const isLoading = ref(false)
  let timer: number | undefined
  let saveTimer: number | undefined

  const question = computed(() => questions.value[currentIndex.value])
  const answeredCount = computed(() => Object.values(answers.value).filter((value) => value.trim()).length)
  const maxPrimary = computed(() => Math.max(activeScale.value.length - 1, 0))
  const shortCount = computed(() => questions.value.filter((item) => item.kind === 'short').length)
  const primaryScore = computed(() => serverScore.value.primary)
  const secondaryScore = computed(() => serverScore.value.secondary || activeScale.value[Math.min(primaryScore.value, activeScale.value.length - 1)] || 0)
  const formattedTime = computed(() => `${String(Math.floor(secondsLeft.value / 60)).padStart(2, '0')}:${String(secondsLeft.value % 60).padStart(2, '0')}`)
  const rank = computed(() => secondaryScore.value >= 90 ? 'админ' : secondaryScore.value >= 80 ? 'про' : secondaryScore.value >= 70 ? 'читер' : secondaryScore.value >= 60 ? 'мастер' : secondaryScore.value >= 50 ? 'железник' : secondaryScore.value >= 40 ? 'тихоня' : secondaryScore.value >= 20 ? 'деревенщина' : secondaryScore.value >= 10 ? 'новичок' : 'нубик')

  function clearStoredAttempt() { localStorage.removeItem(ACTIVE_ATTEMPT_STORAGE_KEY) }
  function persistStoredAttempt() {
    if (!activeAttemptId.value || !activeSlug.value || !expiresAt.value) return clearStoredAttempt()
    const stored: StoredAttempt = {
      version: 1,
      attemptId: activeAttemptId.value,
      slug: activeSlug.value,
      title: activeTitle.value,
      scoreScale: activeScale.value,
      expiresAt: expiresAt.value,
      currentIndex: currentIndex.value,
      answers: answers.value,
      flaggedQuestionIds: flaggedQuestionIds.value,
    }
    localStorage.setItem(ACTIVE_ATTEMPT_STORAGE_KEY, JSON.stringify(stored))
  }
  function readStoredAttempt(): StoredAttempt | null {
    try {
      const value = JSON.parse(localStorage.getItem(ACTIVE_ATTEMPT_STORAGE_KEY) ?? 'null') as Partial<StoredAttempt> | null
      if (!value || value.version !== 1 || typeof value.attemptId !== 'string' || typeof value.slug !== 'string' || typeof value.expiresAt !== 'number' || !Array.isArray(value.scoreScale) || !Array.isArray(value.flaggedQuestionIds)) return null
      return {
        version: 1,
        attemptId: value.attemptId,
        slug: value.slug,
        title: typeof value.title === 'string' ? value.title : '',
        scoreScale: value.scoreScale,
        expiresAt: value.expiresAt,
        currentIndex: typeof value.currentIndex === 'number' ? value.currentIndex : 0,
        answers: value.answers && typeof value.answers === 'object' ? value.answers : {},
        flaggedQuestionIds: value.flaggedQuestionIds.filter((id): id is number => typeof id === 'number'),
      }
    } catch {
      return null
    }
  }
  function startTimer(onExpire: () => void) {
    window.clearInterval(timer)
    const tick = () => {
      const seconds = expiresAt.value === null ? 0 : Math.max(0, Math.ceil((expiresAt.value - Date.now()) / 1000))
      secondsLeft.value = seconds
      if (seconds === 0) {
        window.clearInterval(timer)
        onExpire()
      }
    }
    tick()
    if (secondsLeft.value > 0) timer = window.setInterval(tick, 1000)
  }

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
      answers.value = {}
      flaggedQuestionIds.value = []
      activeAttemptId.value = await startAttempt(variant.slug)
      expiresAt.value = new Date(await getAttemptDeadline(activeAttemptId.value)).getTime()
      if (Number.isNaN(expiresAt.value)) throw new Error('Invalid attempt deadline')
      startTimer(onExpire)
    } finally {
      isLoading.value = false
    }
  }

  async function persist() { if (activeAttemptId.value) await Promise.all(Object.entries(answers.value).map(([position, value]) => saveAnswer(activeAttemptId.value!, Number(position), value))) }
  async function restoreActiveAttempt(onExpire: () => void) {
    const stored = readStoredAttempt()
    if (!stored) return false
    if (stored.expiresAt <= Date.now()) { clearStoredAttempt(); return false }
    try {
      await ensureAnonymousSession()
      const active = await getActiveAttempt(stored.attemptId)
      if (!active) { clearStoredAttempt(); return false }
      const loaded = await getVariantQuestions(active.variant_slug)
      if (!loaded.length) { clearStoredAttempt(); return false }
      const deadline = new Date(active.expires_at).getTime()
      if (Number.isNaN(deadline) || deadline <= Date.now()) { clearStoredAttempt(); return false }
      activeAttemptId.value = active.attempt_id
      activeSlug.value = active.variant_slug
      activeTitle.value = active.variant_title
      activeScale.value = active.score_scale.length ? active.score_scale : scoreScale
      expiresAt.value = deadline
      questions.value = loaded
      answers.value = { ...active.answers, ...stored.answers }
      flaggedQuestionIds.value = stored.flaggedQuestionIds.filter((id) => loaded.some((question) => question.id === id))
      currentIndex.value = Math.min(Math.max(stored.currentIndex, 0), loaded.length - 1)
      startTimer(onExpire)
      return true
    } catch {
      return false
    }
  }
  async function submit() { if (isSubmitting.value || !activeAttemptId.value) return false; isSubmitting.value = true; try { if (secondsLeft.value > 0) await persist(); const score = await submitAttempt(activeAttemptId.value); serverScore.value = { primary: score.primary_score, secondary: score.secondary_score }; serverReview.value = Object.fromEntries((await getAttemptResults(activeAttemptId.value)).map((item) => [item.question_position, item])); window.clearInterval(timer); clearStoredAttempt(); return true } catch { authMessage.value = 'Не удалось отправить вариант. Проверьте соединение и попробуйте ещё раз.'; return false } finally { isSubmitting.value = false } }
  function setQuestion(index: number) { currentIndex.value = index; window.scrollTo({ top: 0, behavior: 'smooth' }) }
  function showSubmittedDetail(rows: AttemptDetailRow[]) {
    const head = rows[0]
    if (!head) throw new Error('Attempt has no questions')
    window.clearInterval(timer)
    window.clearTimeout(saveTimer)
    activeAttemptId.value = head.attempt_id
    activeSlug.value = head.variant_slug
    activeTitle.value = head.variant_title
    activeScale.value = head.score_scale?.length ? head.score_scale : scoreScale
    serverScore.value = { primary: head.primary_score, secondary: head.secondary_score }
    questions.value = rows.map((row) => ({
      id: row.question_position,
      kind: row.kind as 'short' | 'long',
      points: row.points,
      prompt: row.prompt,
      options: row.options ?? undefined,
      imagePath: row.image_path ?? undefined,
      autonumber: !row.options?.some((option) => /^[А-ЯЁA-Z0-9]+\)/.test(option)),
    }))
    answers.value = Object.fromEntries(rows.map((row) => [row.question_position, row.value]))
    serverReview.value = Object.fromEntries(rows.map((row) => [row.question_position, {
      question_position: row.question_position,
      is_correct: row.is_correct,
      correct_answer: row.correct_answer,
      solution: row.solution,
      awarded_points: row.awarded_points,
      max_points: row.points,
      graded: row.graded,
    }]))
    currentIndex.value = 0
    flaggedQuestionIds.value = []
    secondsLeft.value = 0
    expiresAt.value = null
    savedAt.value = ''
  }
  function toggleQuestionFlag(questionId: number) { flaggedQuestionIds.value = flaggedQuestionIds.value.includes(questionId) ? flaggedQuestionIds.value.filter((id) => id !== questionId) : [...flaggedQuestionIds.value, questionId] }
  function reset() { window.clearInterval(timer); window.clearTimeout(saveTimer); answers.value = {}; flaggedQuestionIds.value = []; currentIndex.value = 0; secondsLeft.value = 0; activeAttemptId.value = null; expiresAt.value = null; serverScore.value = { primary: 0, secondary: 0 }; serverReview.value = {}; clearStoredAttempt() }

  watch([activeAttemptId, activeSlug, activeTitle, activeScale, expiresAt, currentIndex, answers, flaggedQuestionIds], persistStoredAttempt, { deep: true })
  watch(answers, () => {
    window.clearTimeout(saveTimer)
    if (!activeAttemptId.value) return
    saveTimer = window.setTimeout(() => {
      void persist().then(() => { savedAt.value = new Intl.DateTimeFormat('ru-RU', { hour: '2-digit', minute: '2-digit' }).format(new Date()) }).catch(() => { authMessage.value = 'Не удалось сохранить ответ. Проверьте соединение.' })
    }, 500)
  }, { deep: true })
  onBeforeUnmount(() => { window.clearInterval(timer); window.clearTimeout(saveTimer) })
  return { questions, question, currentIndex, answers, secondsLeft, formattedTime, savedAt, authMessage, answeredCount, maxPrimary, shortCount, primaryScore, secondaryScore, rank, activeTitle, activeAttemptId, serverReview, flaggedQuestionIds, isSubmitting, isLoading, start, restoreActiveAttempt, submit, setQuestion, showSubmittedDetail, toggleQuestionFlag, reset }
}
