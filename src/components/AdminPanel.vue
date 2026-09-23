<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { ArrowLeft, Check } from 'lucide-vue-next'
import { getAttemptLongAnswers, getAttemptsForGrading, getPendingNicknames, gradeAnswer, reviewNickname, type GradingAttempt, type LongAnswer, type PendingNickname } from '@/lib/supabase'

const attempts = ref<GradingAttempt[]>([])
const selected = ref<GradingAttempt | null>(null)
const answers = ref<LongAnswer[]>([])
const drafts = ref<Record<number, number>>({})
const loading = ref(false)
const saving = ref<number | null>(null)
const error = ref('')
const tab = ref<'attempts' | 'nicks'>('attempts')
const pending = ref<PendingNickname[]>([])
const reviewing = ref<string | null>(null)

function formatDate(value: string) {
  return new Intl.DateTimeFormat('ru-RU', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }).format(new Date(value))
}

async function loadAttempts() {
  loading.value = true
  error.value = ''
  try {
    attempts.value = await getAttemptsForGrading()
  } catch {
    error.value = 'Не удалось загрузить попытки.'
  } finally {
    loading.value = false
  }
}

async function loadPending() {
  try {
    pending.value = await getPendingNicknames()
  } catch {
    error.value = 'Не удалось загрузить ники.'
  }
}

async function review(item: PendingNickname, decision: 'approved' | 'rejected') {
  reviewing.value = item.user_id
  error.value = ''
  try {
    await reviewNickname(item.user_id, decision)
    await loadPending()
  } catch {
    error.value = 'Не удалось обновить ник.'
  } finally {
    reviewing.value = null
  }
}

async function openAttempt(item: GradingAttempt) {
  selected.value = item
  error.value = ''
  try {
    answers.value = await getAttemptLongAnswers(item.attempt_id)
    drafts.value = Object.fromEntries(answers.value.map((answer) => [answer.question_position, answer.awarded_points]))
  } catch {
    error.value = 'Не удалось загрузить ответы.'
  }
}

async function save(item: LongAnswer) {
  const points = drafts.value[item.question_position] ?? 0
  if (!Number.isInteger(points) || points < 0 || points > item.max_points) {
    error.value = `Баллы — целое число от 0 до ${item.max_points}.`
    return
  }
  if (!selected.value) return
  saving.value = item.question_position
  error.value = ''
  try {
    await gradeAnswer(selected.value.attempt_id, item.question_position, points)
    answers.value = await getAttemptLongAnswers(selected.value.attempt_id)
    attempts.value = await getAttemptsForGrading()
    selected.value = attempts.value.find((attempt) => attempt.attempt_id === selected.value!.attempt_id) ?? selected.value
  } catch {
    error.value = 'Не удалось сохранить оценку.'
  } finally {
    saving.value = null
  }
}

onMounted(async () => { await Promise.all([loadAttempts(), loadPending()]) })
</script>

<template>
  <section class="admin shell">
    <div v-if="!selected">
      <p class="eyebrow">Проверка</p>
      <h1>Модерация</h1>
      <div class="admin-tabs" role="tablist">
        <button type="button" role="tab" :aria-selected="tab === 'attempts'" :class="{ active: tab === 'attempts' }" @click="tab = 'attempts'">Попытки</button>
        <button type="button" role="tab" :aria-selected="tab === 'nicks'" :class="{ active: tab === 'nicks' }" @click="tab = 'nicks'">Ники<span v-if="pending.length"> ({{ pending.length }})</span></button>
      </div>
      <div v-if="tab === 'nicks'">
        <p v-if="error" class="auth-message" role="alert">{{ error }}</p>
        <p v-else-if="!pending.length" class="admin-empty">Ников на проверке нет.</p>
        <div v-else class="nick-list">
          <div v-for="item in pending" :key="item.user_id" class="nick-item">
            <span><strong>{{ item.nickname }}</strong><small>{{ item.user_email ?? item.user_id.slice(0, 8) }}</small></span>
            <span class="nick-actions">
              <button class="button button-primary" type="button" :disabled="reviewing === item.user_id" @click="review(item, 'approved')">Ок</button>
              <button class="button button-outline" type="button" :disabled="reviewing === item.user_id" @click="review(item, 'rejected')">Нет</button>
            </span>
          </div>
        </div>
      </div>
      <div v-else>
      <p v-if="error" class="auth-message" role="alert">{{ error }}</p>
      <p v-else-if="loading" class="admin-empty">Загрузка…</p>
      <p v-else-if="!attempts.length" class="admin-empty">Сданных вариантов пока нет.</p>
      <div v-else class="grading-list">
        <button v-for="item in attempts" :key="item.attempt_id" type="button" class="grading-item" @click="openAttempt(item)">
          <span><strong>{{ item.variant_title }}</strong><small>{{ item.user_email ?? item.attempt_id.slice(0, 8) }} · {{ formatDate(item.submitted_at) }}</small></span>
          <span class="grading-progress">{{ item.long_graded }}/{{ item.long_answered }} проверено · {{ item.primary_score }}/{{ item.secondary_score }}</span>
        </button>
      </div>
      </div>
    </div>
    <div v-else>
      <button class="button button-ghost admin-back" type="button" @click="selected = null"><ArrowLeft :size="17" aria-hidden="true" /> Все попытки</button>
      <p class="eyebrow">Проверка</p>
      <h1>{{ selected?.variant_title }}</h1>
      <p class="admin-sub">{{ selected?.user_email ?? selected?.attempt_id.slice(0, 8) }} · {{ selected ? formatDate(selected.submitted_at) : '' }} · {{ selected?.primary_score }}/{{ selected?.secondary_score }}</p>
      <p v-if="error" class="auth-message" role="alert">{{ error }}</p>
      <article v-for="item in answers" :key="item.question_position" class="grade-card">
        <div class="grade-head"><span class="review-number">{{ item.question_position }}</span><h2>Задание {{ item.question_position }}</h2><span class="status" :class="{ correct: item.graded }">{{ item.graded ? `Проверено · ${item.awarded_points}/${item.max_points}` : 'Не проверено' }}</span></div>
        <p class="grade-prompt">{{ item.prompt }}</p>
        <p class="grade-answer">{{ item.value || 'Нет ответа' }}</p>
        <details v-if="item.solution"><summary>Эталонное решение</summary><p>{{ item.solution }}</p></details>
        <div class="grade-row">
          <label :for="`grade-${item.question_position}`">Баллы (0–{{ item.max_points }})</label>
          <input :id="`grade-${item.question_position}`" v-model.number="drafts[item.question_position]" type="number" :min="0" :max="item.max_points" inputmode="numeric" />
          <button class="button button-primary" type="button" :disabled="saving === item.question_position" @click="save(item)"><Check :size="16" aria-hidden="true" /> {{ saving === item.question_position ? 'Сохранение…' : 'Сохранить' }}</button>
        </div>
      </article>
    </div>
  </section>
</template>
