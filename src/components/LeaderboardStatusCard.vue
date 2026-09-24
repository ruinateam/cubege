<script setup lang="ts">
import { computed } from 'vue'
import { BadgeCheck, EyeOff } from 'lucide-vue-next'
import type { LeaderboardVisibilityStatus, ResultPublicationStatus } from '@/types/leaderboard'

const props = defineProps<{
  nicknameStatus: LeaderboardVisibilityStatus
  nickname?: string | null
  publicationStatus: ResultPublicationStatus
  isSaving?: boolean
}>()

defineEmits<{
  publish: []
  keepPrivate: []
  withdraw: []
  openTop: []
}>()

const content = computed(() => ({
  undecided: {
    icon: EyeOff,
    title: 'Опубликовать результат в топе?',
    text: 'Результат сохранён. Пока его видишь только ты.',
    detail: props.nicknameStatus === 'visible' && props.nickname
      ? `После публикации в топе будет показан ник ${props.nickname}.`
      : 'Без одобренного ника в топе будет показан автоматический идентификатор.',
  },
  private: {
    icon: EyeOff,
    title: 'Результат не опубликован',
    text: 'Он сохранён в твоём профиле и не виден другим игрокам.',
    detail: 'Ты можешь опубликовать его в топе в любой момент на этом экране.',
  },
  published: {
    icon: BadgeCheck,
    title: 'Результат опубликован в топе',
    text: props.nicknameStatus === 'visible' && props.nickname
      ? `В топе как ${props.nickname}.`
      : 'В топе он показан под автоматическим идентификатором.',
    detail: 'В рейтинг попадает лучший из опубликованных результатов.',
  },
})[props.publicationStatus])
</script>

<template>
  <section class="leaderboard-status-card" :class="`leaderboard-status--${publicationStatus}`" role="status">
    <component :is="content.icon" class="leaderboard-status-icon" :size="22" aria-hidden="true" />
    <div class="leaderboard-status-copy">
      <p class="eyebrow">Статус в топе</p>
      <h2>{{ content.title }}</h2>
      <p>{{ content.text }}</p>
      <p class="leaderboard-status-detail">{{ content.detail }}</p>
      <div class="leaderboard-status-actions">
        <template v-if="publicationStatus === 'undecided'">
          <button class="button button-primary" type="button" :disabled="isSaving" @click="$emit('publish')">Опубликовать в топе</button>
          <button class="button button-outline" type="button" :disabled="isSaving" @click="$emit('keepPrivate')">Не публиковать</button>
        </template>
        <button v-else-if="publicationStatus === 'private'" class="button button-primary" type="button" :disabled="isSaving" @click="$emit('publish')">Опубликовать в топе</button>
        <template v-else>
          <button class="button button-outline" type="button" @click="$emit('openTop')">Открыть топ</button>
          <button class="button button-ghost" type="button" :disabled="isSaving" @click="$emit('withdraw')">Убрать из топа</button>
        </template>
      </div>
    </div>
  </section>
</template>
