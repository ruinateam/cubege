<script setup lang="ts">
import { computed } from 'vue'
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
    summary: 'Результат сохранён и пока виден только тебе.',
  },
  private: {
    summary: 'Результат сохранён в профиле и не виден в рейтинге.',
  },
  published: {
    summary: props.nicknameStatus === 'visible' && props.nickname
      ? `В топе как ${props.nickname}.`
      : 'Результат опубликован в рейтинге.',
  },
})[props.publicationStatus])
</script>

<template>
  <section class="leaderboard-status" :class="`leaderboard-status--${publicationStatus}`" role="status">
    <div>
      <p class="leaderboard-status-label">Рейтинг</p>
      <p class="leaderboard-status-summary">{{ content.summary }}</p>
    </div>
    <div class="leaderboard-status-actions">
      <template v-if="publicationStatus === 'undecided'">
        <button class="button button-primary" type="button" :disabled="isSaving" @click="$emit('publish')">Опубликовать в топе</button>
        <button class="button button-ghost" type="button" :disabled="isSaving" @click="$emit('keepPrivate')">Оставить в профиле</button>
      </template>
      <button v-else-if="publicationStatus === 'private'" class="button button-outline" type="button" :disabled="isSaving" @click="$emit('publish')">Опубликовать в топе</button>
      <template v-else>
        <button class="button button-outline" type="button" @click="$emit('openTop')">Открыть топ</button>
        <button class="button button-ghost" type="button" :disabled="isSaving" @click="$emit('withdraw')">Убрать из топа</button>
      </template>
    </div>
  </section>
</template>
