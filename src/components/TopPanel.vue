<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { BadgeCheck } from 'lucide-vue-next'
import { getLeaderboard, type LeaderboardRow } from '@/lib/supabase'

const rows = ref<LeaderboardRow[]>([])
const loading = ref(false)
const error = ref('')

onMounted(async () => {
  loading.value = true
  try {
    rows.value = await getLeaderboard()
  } catch {
    error.value = 'Не удалось загрузить топ.'
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <section class="top shell">
    <p class="eyebrow">Рейтинг</p>
    <h1>Лучшие результаты</h1>
    <p class="top-note">Здесь показаны лучшие опубликованные результаты. Если ник не выбран, используется игровой идентификатор.</p>
    <p v-if="error" class="auth-message" role="alert">{{ error }}</p>
    <p v-else-if="loading" class="admin-empty">Загрузка…</p>
    <p v-else-if="!rows.length" class="admin-empty">Пока пусто — стань первым.</p>
    <ol v-else class="top-list">
      <li v-for="(row, index) in rows" :key="row.nickname" :class="{ 'top-row--current': row.is_current_user }">
        <span class="top-place">{{ index + 1 }}</span>
        <span v-if="row.verified" class="verified-badge" title="Twitch привязан" aria-label="Twitch привязан"><BadgeCheck :size="15" aria-hidden="true" /></span>
        <span class="top-nick" :class="{ 'nickname-generated': row.generated_nickname }">{{ row.nickname }}</span>
        <span class="top-meta">{{ row.completed }} {{ row.completed === 1 ? 'попытка' : 'попыток' }}</span>
        <span class="top-score">{{ row.best_secondary }}<small>/100</small></span>
      </li>
    </ol>
  </section>
</template>
