<script setup lang="ts">
import { computed } from 'vue'
import { BadgeCheck, CircleAlert, Clock3, EyeOff } from 'lucide-vue-next'
import type { LeaderboardVisibilityStatus } from '@/types/leaderboard'

const props = defineProps<{
  status: LeaderboardVisibilityStatus
  nickname?: string | null
  isTwitchUser?: boolean
}>()

defineEmits<{ openProfile: []; connectTwitch: []; openTop: [] }>()

const content = computed(() => ({
  visible_anonymous: {
    icon: EyeOff,
    title: 'Результат участвует в топе анонимно',
    text: 'Результат сохранён и уже виден в топе под автоматическим ником.',
    detail: 'Выбери ник, если хочешь отображаться в топе под своим именем.',
  },
  pending: {
    icon: Clock3,
    title: 'Ник проверяется',
    text: 'Ник отправлен на проверку, а результат уже виден в топе под автоматическим ником.',
    detail: 'После одобрения в топе будет показан выбранный ник.',
  },
  visible: {
    icon: BadgeCheck,
    title: 'Результат участвует в топе',
    text: props.nickname ? `В топе как ${props.nickname}.` : 'Результат опубликован в топе.',
    detail: 'Лучший результат обновляется автоматически.',
  },
  rejected: {
    icon: CircleAlert,
    title: 'Ник не прошёл проверку',
    text: 'Результат сохранён и виден в топе под автоматическим ником.',
    detail: 'Выбери другой ник и отправь его снова, чтобы отображаться под ним.',
  },
})[props.status])
</script>

<template>
  <section class="leaderboard-status-card" :class="`leaderboard-status--${status}`" role="status">
    <component :is="content.icon" class="leaderboard-status-icon" :size="22" aria-hidden="true" />
    <div class="leaderboard-status-copy">
      <p class="eyebrow">Статус в топе</p>
      <h2>{{ content.title }}</h2>
      <p>{{ content.text }}</p>
      <p class="leaderboard-status-detail">{{ content.detail }}</p>
      <div class="leaderboard-status-actions">
        <template v-if="status === 'visible_anonymous'">
          <button class="button button-outline" type="button" @click="$emit('openProfile')">Выбрать ник</button>
          <button v-if="!isTwitchUser" class="button button-ghost" type="button" @click="$emit('connectTwitch')">Привязать Twitch</button>
        </template>
        <button v-else-if="status === 'pending'" class="button button-outline" type="button" @click="$emit('openProfile')">Открыть профиль</button>
        <button v-else-if="status === 'visible'" class="button button-outline" type="button" @click="$emit('openTop')">Открыть топ</button>
        <button v-else class="button button-outline" type="button" @click="$emit('openProfile')">Изменить ник</button>
      </div>
    </div>
  </section>
</template>
