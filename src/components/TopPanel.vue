<script setup lang="ts">
import { onMounted, ref } from 'vue'
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
    <p class="eyebrow">Топ игроков</p>
    <h1>Лучшие результаты</h1>
    <p class="top-note">Ники на проверке показаны зачарованным шрифтом.</p>
    <p v-if="error" class="auth-message" role="alert">{{ error }}</p>
    <p v-else-if="loading" class="admin-empty">Загрузка…</p>
    <p v-else-if="!rows.length" class="admin-empty">Пока пусто — стань первым.</p>
    <ol v-else class="top-list">
      <li v-for="(row, index) in rows" :key="row.nickname">
        <span class="top-place">{{ index + 1 }}</span>
        <span class="top-nick" :class="{ 'nickname-pending': row.pending }">{{ row.nickname }}</span>
        <span class="top-meta">{{ row.completed }} {{ row.completed === 1 ? 'попытка' : 'попыток' }}</span>
        <span class="top-score">{{ row.best_secondary }}<small>/100</small></span>
      </li>
    </ol>
  </section>
</template>
