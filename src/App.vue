<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { BadgeCheck, Check, ChevronLeft, ChevronRight, CircleAlert, Clock3, EyeOff, Flag, FlagOff, Send, Trophy } from 'lucide-vue-next'
import { useAuth } from './composables/useAuth'
import { useExamAttempt } from './composables/useExamAttempt'
import { useProfile } from './composables/useProfile'
import { useVariants } from './composables/useVariants'
import { questionImageUrl, setAttemptLeaderboardVisibility } from './lib/supabase'
import type { ResultPublicationStatus } from './types/leaderboard'
import AdminPanel from './components/AdminPanel.vue'
import AppHeader from './components/AppHeader.vue'
import LeaderboardStatusCard from './components/LeaderboardStatusCard.vue'
import TopPanel from './components/TopPanel.vue'

type View = 'welcome' | 'exam' | 'result' | 'profile' | 'admin' | 'top'
const view = ref<View>('welcome')
const accountMenuOpen = ref(false)
const { authUser, authMessage, connectTwitch, signOut: endSession } = useAuth()
const { userStatistics, loadStatistics, profile, nicknameDraft, nicknameMessage, isRequestingNickname, isProfileLoaded, profileLoadError, leaderboardStatus, latestAttempt, latestAttemptMessage, isUpdatingLatestAttempt, loadProfile, loadLatestAttempt, setLatestAttemptVisibility, submitNickname, clearProfile } = useProfile()
const { variants, selectedSlug, selectedVariant, variantsError, isLoadingVariants, loadVariants } = useVariants()
const { questions, question, currentIndex, answers, secondsLeft, formattedTime, savedAt, answeredCount, maxPrimary, shortCount, primaryScore, secondaryScore, rank, activeTitle, activeAttemptId, serverReview, flaggedQuestionIds, isSubmitting, isLoading, start, restoreActiveAttempt, submit, setQuestion, toggleQuestionFlag, reset: resetAttempt } = useExamAttempt()
const shortPoints = primaryScore
const resultPublicationStatus = ref<ResultPublicationStatus>('undecided')
const isUpdatingPublication = ref(false)
const publicationMessage = ref('')

onMounted(async () => {
  await loadVariants()
  if (await restoreActiveAttempt(() => void expireExam())) view.value = 'exam'
})
watch(authUser, (user) => {
  if (user) void loadProfile()
  else clearProfile()
}, { immediate: true })

const profileStatusIcon = computed(() => ({
  no_nickname: EyeOff,
  pending: Clock3,
  visible: BadgeCheck,
  rejected: CircleAlert,
})[leaderboardStatus.value])

async function startExam() {
  if (!selectedVariant.value) { authMessage.value = 'Нет доступных вариантов. Попробуйте позже.'; return }
  try { await start(selectedVariant.value, () => void expireExam()); view.value = 'exam' }
  catch { authMessage.value = 'Не удалось начать вариант. Обновите страницу и попробуйте ещё раз.' }
}
async function submitExam() {
  if (await submit()) {
    resultPublicationStatus.value = 'undecided'
    publicationMessage.value = ''
    view.value = 'result'
    window.scrollTo({ top: 0, behavior: 'smooth' })
    void loadProfile()
    return true
  }
  return false
}
async function expireExam() {
  if (await submitExam()) return
  resetAttempt()
  authMessage.value = 'Время на вариант истекло. Несохранённые ответы не вошли в результат.'
  view.value = 'welcome'
}
async function setResultPublication(visible: boolean) {
  if (!activeAttemptId.value || isUpdatingPublication.value) return
  isUpdatingPublication.value = true
  publicationMessage.value = ''
  try {
    await setAttemptLeaderboardVisibility(activeAttemptId.value, visible)
    resultPublicationStatus.value = visible ? 'published' : 'private'
  } catch {
    publicationMessage.value = 'Не удалось изменить публикацию. Проверь соединение и попробуй ещё раз.'
  } finally {
    isUpdatingPublication.value = false
  }
}
function previous() { if (currentIndex.value > 0) setQuestion(currentIndex.value - 1) }
function next() { if (currentIndex.value < questions.value.length - 1) setQuestion(currentIndex.value + 1) }
function reset() { resetAttempt(); view.value = 'welcome' }
async function openProfile() { accountMenuOpen.value = false; view.value = 'profile'; await Promise.all([loadStatistics(), loadProfile(), loadLatestAttempt()]) }
async function useTwitchNickname() { if (!authUser.value?.login) return; nicknameDraft.value = authUser.value.login; await submitNickname() }
function openTop() { accountMenuOpen.value = false; view.value = 'top' }
function openAdmin() { if (!authUser.value?.isAdmin) return; accountMenuOpen.value = false; view.value = 'admin' }
function reviewStatus(item: { id: number; kind: string }) {
  const review = serverReview.value[item.id]
  if (!review) return 'Ручная проверка'
  if (item.kind === 'long' && review.graded) return `Проверено · ${review.awarded_points}/${review.max_points}`
  if (review.is_correct === true) return 'Верно'
  if (review.is_correct === false) return 'Неверно'
  return 'Ручная проверка'
}
function plural(value: number, one: string, few: string, many: string) {
  const m10 = Math.abs(value) % 10
  const m100 = Math.abs(value) % 100
  if (m10 === 1 && m100 !== 11) return one
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return few
  return many
}
function formatAttemptDate(value: string) {
  return new Intl.DateTimeFormat('ru-RU', { day: 'numeric', month: 'long' }).format(new Date(value))
}
async function signOut() { await endSession(); accountMenuOpen.value = false; view.value = 'welcome' }
</script>

<template>
  <a class="skip-link" href="#content">К заданиям</a>
  <AppHeader :view="view" :formatted-time="formattedTime" :timer-state="secondsLeft <= 300 ? 'critical' : secondsLeft <= 600 ? 'warning' : 'normal'" :user="authUser" :menu-open="accountMenuOpen" @home="view = 'welcome'" @connect="connectTwitch" @toggle-menu="accountMenuOpen = !accountMenuOpen" @profile="openProfile" @admin="openAdmin" @top="openTop" @sign-out="signOut" />

  <main id="content">
    <section v-if="view === 'welcome'" class="welcome shell">
      <div class="eyebrow"><span class="cube" aria-hidden="true"></span> Пробный вариант · 2026</div>
      <h1>ЕГЭ по <span>кубам</span></h1>
      <p class="lede">Проверь, насколько хорошо ты знаешь Minecraft: {{ selectedVariant?.question_count ?? '—' }} заданий, {{ selectedVariant ? Math.round(selectedVariant.duration_seconds / 60) : '—' }} минут и подробный разбор после сдачи.</p>
      <div v-if="variants.length > 1" class="variant-picker" role="radiogroup" aria-label="Выбор варианта"><button v-for="item in variants" :key="item.slug" type="button" role="radio" :aria-checked="item.slug === selectedSlug" :class="{ active: item.slug === selectedSlug }" @click="selectedSlug = item.slug">{{ item.title }}</button></div>
      <div class="welcome-actions"><button class="button button-primary" type="button" :disabled="isLoading || isLoadingVariants || !selectedVariant" @click="startExam">{{ isLoading ? 'Загрузка…' : 'Начать вариант' }} <ChevronRight v-if="!isLoading" :size="18" aria-hidden="true" /></button><button class="button button-outline" type="button" @click="openTop"><Trophy :size="17" aria-hidden="true" /> Топ</button><span>Результат сохранится. После сдачи ты сам решишь, публиковать ли его в топе.</span></div>
      <p v-if="authMessage || variantsError" class="auth-message" role="status">{{ authMessage || variantsError }}</p>
      <dl class="stats"><div><dt>{{ selectedVariant?.question_count ?? '—' }}</dt><dd>заданий</dd></div><div><dt>{{ selectedVariant ? Math.round(selectedVariant.duration_seconds / 60) : '—' }}</dt><dd>минут</dd></div><div><dt>{{ selectedVariant?.max_primary ?? '—' }}</dt><dd>первичных баллов</dd></div></dl>
      <div class="exam-note"><span class="note-icon" aria-hidden="true">!</span><p><strong>Без спойлеров.</strong> Ключи и эталонные решения появятся только после отправки варианта.</p></div>
    </section>

    <section v-else-if="view === 'exam'" class="exam-layout shell">
      <aside class="question-nav" aria-label="Навигация по заданиям">
        <div class="nav-head"><span>Задания</span><span>{{ answeredCount }}/{{ questions.length }}</span></div>
        <div class="number-grid">
          <button v-for="(item, index) in questions" :key="item.id" class="number-button" :class="{ active: index === currentIndex, done: answers[item.id]?.trim(), flagged: flaggedQuestionIds.includes(item.id), long: item.kind === 'long' }" type="button" :aria-label="`Задание ${item.id}: ${answers[item.id]?.trim() ? 'есть ответ' : 'без ответа'}${flaggedQuestionIds.includes(item.id) ? ', отмечено для возврата' : ''}`" :aria-current="index === currentIndex ? 'step' : undefined" @click="setQuestion(index)">{{ item.id }}<span v-if="flaggedQuestionIds.includes(item.id)" aria-hidden="true">•</span></button>
        </div>
        <p v-if="savedAt" class="saved"><Check :size="14" aria-hidden="true" /> Сохранено {{ savedAt }}</p>
      </aside>
      <article class="question-card">
        <div class="question-meta"><span>Задание {{ question.id }} из {{ questions.length }}</span><span>{{ question.points }} {{ question.points === 1 ? 'балл' : question.points < 5 ? 'балла' : 'баллов' }}</span></div>
        <h1>{{ question.prompt }}</h1>
        <figure v-if="question.imagePath" class="question-figure"><img :src="questionImageUrl(question.imagePath)" :alt="`Схема к заданию ${question.id}`" loading="lazy" /></figure>
        <div v-if="question.options && !question.autonumber" class="option-columns"><div><p>Первый столбец</p><ol class="options labelled"><li v-for="option in question.options.filter((item) => /^[А-ЯЁ]/.test(item))" :key="option">{{ option }}</li></ol></div><div><p>Второй столбец</p><ol class="options labelled"><li v-for="option in question.options.filter((item) => /^[0-9]/.test(item))" :key="option">{{ option }}</li></ol></div></div>
        <ol v-else-if="question.options" class="options"><li v-for="option in question.options" :key="option">{{ option }}</li></ol>
        <div class="answer-area">
          <label :for="`answer-${question.id}`">{{ question.kind === 'short' ? 'Ответ' : 'Развёрнутый ответ' }}</label>
          <input v-if="question.kind === 'short'" :id="`answer-${question.id}`" v-model="answers[question.id]" autocomplete="off" inputmode="text" maxlength="16" placeholder="Введите ответ" />
          <textarea v-else :id="`answer-${question.id}`" v-model="answers[question.id]" placeholder="Опишите ход решения и ответ" rows="8"></textarea>
          <p>{{ question.kind === 'short' ? 'Без пробелов и знаков препинания, если это не указано в задании.' : 'Развёрнутые ответы будут сохранены. Сверить их с эталоном можно после сдачи.' }}</p>
        </div>
        <div class="question-actions"><button class="button button-ghost" type="button" :aria-pressed="flaggedQuestionIds.includes(question.id)" @click="toggleQuestionFlag(question.id)"><FlagOff v-if="flaggedQuestionIds.includes(question.id)" :size="17" aria-hidden="true" /><Flag v-else :size="17" aria-hidden="true" /> {{ flaggedQuestionIds.includes(question.id) ? 'Убрать отметку' : 'Вернуться позже' }}</button><button class="button button-ghost" type="button" :disabled="currentIndex === 0" @click="previous"><ChevronLeft :size="18" aria-hidden="true" /> Назад</button><button v-if="currentIndex < questions.length - 1" class="button button-primary" type="button" @click="next">Дальше <ChevronRight :size="18" aria-hidden="true" /></button><button v-else class="button button-primary" type="button" :disabled="answeredCount === 0" :title="answeredCount === 0 ? 'Ответьте хотя бы на один вопрос' : undefined" @click="submitExam"><Send :size="17" aria-hidden="true" /> Сдать вариант</button></div>
      </article>
      <aside class="exam-side"><div class="progress-card"><span>Заполнено</span><strong>{{ answeredCount }}<small>/{{ questions.length }}</small></strong><div class="progress"><i :style="{ width: `${questions.length ? answeredCount / questions.length * 100 : 0}%` }"></i></div><p v-if="flaggedQuestionIds.length" class="flagged-count"><Flag :size="14" aria-hidden="true" /> Отмечено: {{ flaggedQuestionIds.length }}</p></div><button class="button button-outline" type="button" :disabled="answeredCount === 0" :title="answeredCount === 0 ? 'Ответьте хотя бы на один вопрос' : undefined" @click="submitExam">Сдать вариант</button></aside>
    </section>

    <section v-else-if="view === 'profile'" class="profile shell">
      <div class="profile-heading"><div class="profile-avatar"><img v-if="authUser?.avatarUrl" :src="authUser.avatarUrl" alt="" /><span v-else>{{ authUser?.label.slice(0, 1) }}</span></div><div><p class="eyebrow">{{ authUser && !authUser.isAnonymous ? 'Профиль Twitch' : 'Профиль гостя' }}</p><h1>{{ authUser?.label }}</h1><p v-if="authUser?.login">@{{ authUser.login }}</p></div></div>
      <section class="nickname-block" aria-label="Статус в топе">
        <p v-if="profileLoadError" class="auth-message" role="status">Не удалось проверить статус публикации. Открой профиль позже.</p>
        <template v-else>
          <template v-if="leaderboardStatus === 'no_nickname'">
            <h2 class="profile-leaderboard-heading leaderboard-status--no_nickname"><component :is="profileStatusIcon" :size="20" aria-hidden="true" /> Ник не выбран</h2>
            <p class="nickname-description">Выбери ник заранее. Он будет показан в топе, если ты решишь опубликовать результат.</p>
            <label for="nickname">Выбери ник</label>
            <div class="nickname-row"><input id="nickname" v-model="nicknameDraft" autocomplete="nickname" name="nickname" maxlength="16" spellcheck="false" placeholder="Steve_2026" /><button class="button button-outline" type="button" :disabled="isRequestingNickname" @click="submitNickname">Отправить на проверку</button></div>
            <button v-if="authUser?.login" class="button button-ghost nickname-use" type="button" :disabled="isRequestingNickname" @click="useTwitchNickname">Использовать {{ authUser.login }}</button>
            <p class="nickname-hint">3–16 латинских букв, цифр или _. {{ authUser && !authUser.isAnonymous ? 'Ник Twitch одобряется сразу.' : 'После одобрения он будет использоваться в опубликованных результатах.' }}</p>
          </template>
          <template v-else-if="leaderboardStatus === 'pending'">
            <h2 class="profile-leaderboard-heading leaderboard-status--pending"><component :is="profileStatusIcon" :size="20" aria-hidden="true" /> Ник проверяется</h2>
            <p class="nickname-value">{{ profile?.nickname }}</p>
            <p class="nickname-description">Ник отправлен модераторам. Он будет использоваться, когда ты решишь опубликовать результат в топе.</p>
          </template>
          <template v-else-if="leaderboardStatus === 'visible'">
            <h2 class="profile-leaderboard-heading leaderboard-status--visible"><component :is="profileStatusIcon" :size="20" aria-hidden="true" /> В топе</h2>
            <p class="nickname-description">Этот ник будет показан в результатах, которые ты решишь опубликовать.</p>
          </template>
          <template v-else>
            <h2 class="profile-leaderboard-heading leaderboard-status--rejected"><component :is="profileStatusIcon" :size="20" aria-hidden="true" /> Ник нужно изменить</h2>
            <p class="nickname-value">{{ profile?.nickname }}</p>
            <p class="nickname-description">Этот ник не может быть опубликован. Выбери другой, чтобы использовать его в результатах для топа.</p>
            <label for="nickname">Новый ник</label>
            <div class="nickname-row"><input id="nickname" v-model="nicknameDraft" autocomplete="nickname" name="nickname" maxlength="16" spellcheck="false" placeholder="Steve_2026" /><button class="button button-outline" type="button" :disabled="isRequestingNickname" @click="submitNickname">Отправить снова</button></div>
            <p class="nickname-hint">3–16 латинских букв, цифр или _.</p>
          </template>
          <p v-if="nicknameMessage" class="nickname-status" role="status">{{ nicknameMessage }}</p>
        </template>
      </section>
       <div class="profile-stats"><div><span>Пройдено вариантов</span><strong>{{ userStatistics?.completed_attempts ?? '—' }}</strong></div><div><span>Лучший результат</span><strong>{{ userStatistics?.best_secondary_score ?? '—' }}<small v-if="userStatistics?.best_secondary_score">/100</small></strong></div><div><span>Средний результат</span><strong>{{ userStatistics?.average_secondary_score ?? '—' }}<small v-if="userStatistics?.average_secondary_score">/100</small></strong></div></div>
      <section class="latest-attempt-publication" aria-labelledby="latest-attempt-heading">
        <p class="eyebrow">Публикация</p>
        <h2 id="latest-attempt-heading">Последняя сданная попытка</h2>
        <template v-if="latestAttempt">
          <p>{{ latestAttempt.secondary_score }} / 100 · {{ formatAttemptDate(latestAttempt.submitted_at) }}</p>
          <p v-if="latestAttempt.leaderboard_visible">Результат опубликован в топе.</p>
          <p v-else>Результат сохранён и не виден другим игрокам.</p>
          <button v-if="latestAttempt.leaderboard_visible" class="button button-outline" type="button" :disabled="isUpdatingLatestAttempt" @click="setLatestAttemptVisibility(false)">Убрать из топа</button>
          <button v-else class="button button-primary" type="button" :disabled="isUpdatingLatestAttempt" @click="setLatestAttemptVisibility(true)">Опубликовать в топе</button>
        </template>
        <p v-else>Сданных вариантов пока нет.</p>
        <p v-if="latestAttemptMessage" class="auth-message" role="status">{{ latestAttemptMessage }}</p>
      </section>
      <button class="button button-primary" type="button" @click="view = 'welcome'">Пройти вариант</button>
    </section>
    <AdminPanel v-else-if="view === 'admin' && authUser?.isAdmin" />
    <TopPanel v-else-if="view === 'top'" />
    <section v-else class="result shell">
      <div class="result-hero"><div class="result-icon"><Trophy :size="28" aria-hidden="true" /></div><p class="eyebrow">{{ activeTitle || 'Вариант сдан' }}</p><h1>{{ secondaryScore }} <span>{{ plural(secondaryScore, 'балл', 'балла', 'баллов') }}</span></h1><p>Твоё звание — <strong>{{ rank }}</strong>. Краткие ответы проверены автоматически; развёрнутые можно сравнить с эталоном после ручной проверки.</p><button class="button button-outline" type="button" @click="reset">Пройти ещё раз</button></div>
      <div class="score-cards"><div><span>Первичный балл</span><strong>{{ primaryScore }}<small>/{{ maxPrimary }}</small></strong></div><div><span>Вторичный балл</span><strong>{{ secondaryScore }}<small>/100</small></strong></div><div><span>Краткие ответы</span><strong>{{ shortPoints }}<small>/{{ shortCount }}</small></strong></div></div>
       <LeaderboardStatusCard v-if="isProfileLoaded && !profileLoadError" :nickname-status="leaderboardStatus" :nickname="profile?.nickname" :publication-status="resultPublicationStatus" :is-saving="isUpdatingPublication" @publish="setResultPublication(true)" @keep-private="setResultPublication(false)" @withdraw="setResultPublication(false)" @open-top="openTop" />
       <p v-if="publicationMessage" class="auth-message" role="status">{{ publicationMessage }}</p>
      <section v-else-if="profileLoadError" class="leaderboard-status-card leaderboard-status--unavailable" role="status"><CircleAlert :size="22" aria-hidden="true" /><div><p class="eyebrow">Статус в топе</p><h2>Не удалось проверить статус публикации</h2><p>Результат сохранён. Попробуй открыть профиль позже.</p><button class="button button-outline" type="button" @click="openProfile">Открыть профиль</button></div></section>
      <p v-else class="leaderboard-status-loading" role="status">Проверяем статус публикации результата…</p>
      <section class="review"><div class="section-heading"><div><p class="eyebrow">Разбор</p><h2>Твои ответы</h2></div><span>{{ answeredCount }} из {{ questions.length }} заполнено</span></div><article v-for="item in questions" :key="item.id" class="review-item" :class="{ correct: serverReview[item.id]?.is_correct === true, missed: serverReview[item.id]?.is_correct === false }"><div class="review-number">{{ item.id }}</div><div><h3>{{ item.prompt }}</h3><p>Твой ответ: <strong>{{ answers[item.id] || 'нет ответа' }}</strong><template v-if="serverReview[item.id]?.correct_answer"> · Верный ответ: <strong>{{ serverReview[item.id].correct_answer }}</strong></template></p><details v-if="serverReview[item.id]?.solution"><summary>Показать эталонное решение</summary><p>{{ serverReview[item.id].solution }}</p></details></div><span class="status">{{ reviewStatus(item) }}</span></article></section>
    </section>
  </main>
</template>
