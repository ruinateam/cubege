<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { Check, ChevronLeft, ChevronRight, Send, Trophy } from 'lucide-vue-next'
import { useAuth } from './composables/useAuth'
import { useExamAttempt } from './composables/useExamAttempt'
import { useProfile } from './composables/useProfile'
import { useVariants } from './composables/useVariants'
import AppHeader from './components/AppHeader.vue'

type View = 'welcome' | 'exam' | 'result' | 'profile'
const view = ref<View>('welcome')
const accountMenuOpen = ref(false)
const { authUser, authMessage, connectTwitch, signOut: endSession } = useAuth()
const { userStatistics, loadStatistics } = useProfile()
const { variants, selectedSlug, selectedVariant, variantsError, isLoadingVariants, loadVariants } = useVariants()
const { questions, question, currentIndex, answers, secondsLeft, formattedTime, savedAt, answeredCount, maxPrimary, shortCount, primaryScore, secondaryScore, rank, activeTitle, serverReview, isSubmitting, isLoading, start, submit, setQuestion, reset: resetAttempt } = useExamAttempt()
const shortPoints = primaryScore

onMounted(loadVariants)

async function startExam() {
  if (!selectedVariant.value) { authMessage.value = 'Нет доступных вариантов. Попробуйте позже.'; return }
  try { await start(selectedVariant.value, () => void submitExam()); view.value = 'exam' }
  catch { authMessage.value = 'Не удалось начать вариант. Обновите страницу и попробуйте ещё раз.' }
}
async function submitExam() {
  if (await submit()) { view.value = 'result'; window.scrollTo({ top: 0, behavior: 'smooth' }) }
}
function previous() { if (currentIndex.value > 0) setQuestion(currentIndex.value - 1) }
function next() { if (currentIndex.value < questions.value.length - 1) setQuestion(currentIndex.value + 1) }
function reset() { resetAttempt(); view.value = 'welcome' }
async function openProfile() { accountMenuOpen.value = false; view.value = 'profile'; await loadStatistics() }
async function signOut() { await endSession(); accountMenuOpen.value = false; view.value = 'welcome' }
</script>

<template>
  <a class="skip-link" href="#content">К заданиям</a>
  <AppHeader :view="view" :formatted-time="formattedTime" :is-urgent="secondsLeft < 600" :user="authUser" :menu-open="accountMenuOpen" @home="view = 'welcome'" @connect="connectTwitch" @toggle-menu="accountMenuOpen = !accountMenuOpen" @profile="openProfile" @sign-out="signOut" />

  <main id="content">
    <section v-if="view === 'welcome'" class="welcome shell">
      <div class="eyebrow"><span class="cube" aria-hidden="true"></span> Пробный вариант · 2026</div>
      <h1>ЕГЭ по <span>кубам</span></h1>
      <p class="lede">Проверь, насколько хорошо ты знаешь Minecraft: {{ selectedVariant?.question_count ?? '—' }} заданий, {{ selectedVariant ? Math.round(selectedVariant.duration_seconds / 60) : '—' }} минут и подробный разбор после сдачи.</p>
      <div v-if="variants.length > 1" class="variant-picker" role="radiogroup" aria-label="Выбор варианта"><button v-for="item in variants" :key="item.slug" type="button" role="radio" :aria-checked="item.slug === selectedSlug" :class="{ active: item.slug === selectedSlug }" @click="selectedSlug = item.slug">{{ item.title }}</button></div>
      <div class="welcome-actions"><button class="button button-primary" type="button" :disabled="isLoading || isLoadingVariants || !selectedVariant" @click="startExam">{{ isLoading ? 'Загрузка…' : 'Начать вариант' }} <ChevronRight v-if="!isLoading" :size="18" aria-hidden="true" /></button><span>Результат сохранится в твоём профиле</span></div>
      <p v-if="authMessage || variantsError" class="auth-message" role="status">{{ authMessage || variantsError }}</p>
      <dl class="stats"><div><dt>{{ selectedVariant?.question_count ?? '—' }}</dt><dd>заданий</dd></div><div><dt>{{ selectedVariant ? Math.round(selectedVariant.duration_seconds / 60) : '—' }}</dt><dd>минут</dd></div><div><dt>{{ selectedVariant?.max_primary ?? '—' }}</dt><dd>первичных баллов</dd></div></dl>
      <div class="exam-note"><span class="note-icon" aria-hidden="true">!</span><p><strong>Без спойлеров.</strong> Ключи и эталонные решения появятся только после отправки варианта.</p></div>
    </section>

    <section v-else-if="view === 'exam'" class="exam-layout shell">
      <aside class="question-nav" aria-label="Навигация по заданиям">
        <div class="nav-head"><span>Задания</span><span>{{ answeredCount }}/{{ questions.length }}</span></div>
        <div class="number-grid">
          <button v-for="(item, index) in questions" :key="item.id" class="number-button" :class="{ active: index === currentIndex, done: answers[item.id]?.trim(), long: item.kind === 'long' }" type="button" :aria-label="`Задание ${item.id}`" :aria-current="index === currentIndex ? 'step' : undefined" @click="setQuestion(index)">{{ item.id }}</button>
        </div>
        <p v-if="savedAt" class="saved"><Check :size="14" aria-hidden="true" /> Сохранено {{ savedAt }}</p>
      </aside>
      <article class="question-card">
        <div class="question-meta"><span>Задание {{ question.id }} из {{ questions.length }}</span><span>{{ question.points }} {{ question.points === 1 ? 'балл' : question.points < 5 ? 'балла' : 'баллов' }}</span></div>
        <h1>{{ question.prompt }}</h1>
        <ol v-if="question.options" class="options"><li v-for="option in question.options" :key="option">{{ option }}</li></ol>
        <div class="answer-area">
          <label :for="`answer-${question.id}`">{{ question.kind === 'short' ? 'Ответ' : 'Развёрнутый ответ' }}</label>
          <input v-if="question.kind === 'short'" :id="`answer-${question.id}`" v-model="answers[question.id]" autocomplete="off" inputmode="text" maxlength="16" placeholder="Введите ответ" />
          <textarea v-else :id="`answer-${question.id}`" v-model="answers[question.id]" placeholder="Опишите ход решения и ответ" rows="8"></textarea>
          <p>{{ question.kind === 'short' ? 'Без пробелов и знаков препинания, если это не указано в задании.' : 'Развёрнутые ответы будут сохранены. Сверить их с эталоном можно после сдачи.' }}</p>
        </div>
        <div class="question-actions"><button class="button button-ghost" type="button" :disabled="currentIndex === 0" @click="previous"><ChevronLeft :size="18" aria-hidden="true" /> Назад</button><button v-if="currentIndex < questions.length - 1" class="button button-primary" type="button" @click="next">Дальше <ChevronRight :size="18" aria-hidden="true" /></button><button v-else class="button button-primary" type="button" @click="submitExam"><Send :size="17" aria-hidden="true" /> Сдать вариант</button></div>
      </article>
      <aside class="exam-side"><div class="progress-card"><span>Заполнено</span><strong>{{ answeredCount }}<small>/{{ questions.length }}</small></strong><div class="progress"><i :style="{ width: `${questions.length ? answeredCount / questions.length * 100 : 0}%` }"></i></div></div><button class="button button-outline" type="button" @click="submitExam">Сдать вариант</button></aside>
    </section>

    <section v-else-if="view === 'profile'" class="profile shell">
      <div class="profile-heading"><div class="profile-avatar"><img v-if="authUser?.avatarUrl" :src="authUser.avatarUrl" alt="" /><span v-else>{{ authUser?.label.slice(0, 1) }}</span></div><div><p class="eyebrow">Профиль Twitch</p><h1>{{ authUser?.label }}</h1><p v-if="authUser?.login">@{{ authUser.login }}</p></div></div>
      <div class="profile-stats"><div><span>Пройдено вариантов</span><strong>{{ userStatistics?.completed_attempts ?? '—' }}</strong></div><div><span>Лучший результат</span><strong>{{ userStatistics?.best_secondary_score ?? '—' }}<small v-if="userStatistics?.best_secondary_score">/100</small></strong></div><div><span>Средний результат</span><strong>{{ userStatistics?.average_secondary_score ?? '—' }}<small v-if="userStatistics?.average_secondary_score">/100</small></strong></div></div>
      <button class="button button-primary" type="button" @click="view = 'welcome'">Пройти вариант</button>
    </section>
    <section v-else class="result shell">
      <div class="result-hero"><div class="result-icon"><Trophy :size="28" aria-hidden="true" /></div><p class="eyebrow">{{ activeTitle || 'Вариант сдан' }}</p><h1>{{ secondaryScore }} <span>баллов</span></h1><p>Твоё звание — <strong>{{ rank }}</strong>. Краткие ответы проверены автоматически; развёрнутые можно сравнить с эталоном после ручной проверки.</p><button class="button button-outline" type="button" @click="reset">Пройти ещё раз</button></div>
      <div class="score-cards"><div><span>Первичный балл</span><strong>{{ primaryScore }}<small>/{{ maxPrimary }}</small></strong></div><div><span>Вторичный балл</span><strong>{{ secondaryScore }}<small>/100</small></strong></div><div><span>Краткие ответы</span><strong>{{ shortPoints }}<small>/{{ shortCount }}</small></strong></div></div>
      <section class="review"><div class="section-heading"><div><p class="eyebrow">Разбор</p><h2>Твои ответы</h2></div><span>{{ answeredCount }} из {{ questions.length }} заполнено</span></div><article v-for="item in questions" :key="item.id" class="review-item" :class="{ correct: serverReview[item.id]?.is_correct === true, missed: serverReview[item.id]?.is_correct === false }"><div class="review-number">{{ item.id }}</div><div><h3>{{ item.prompt }}</h3><p>Твой ответ: <strong>{{ answers[item.id] || 'нет ответа' }}</strong><template v-if="serverReview[item.id]?.correct_answer"> · Верный ответ: <strong>{{ serverReview[item.id].correct_answer }}</strong></template></p><details v-if="serverReview[item.id]?.solution"><summary>Показать эталонное решение</summary><p>{{ serverReview[item.id].solution }}</p></details></div><span class="status">{{ serverReview[item.id]?.is_correct === true ? 'Верно' : serverReview[item.id]?.is_correct === false ? 'Неверно' : 'Ручная проверка' }}</span></article></section>
    </section>
  </main>
</template>
