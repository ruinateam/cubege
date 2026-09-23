<script setup lang="ts">
import { Moon, Sun } from 'lucide-vue-next'
import { useTheme } from '@/composables/useTheme'

const { theme, toggle } = useTheme()
</script>

<template>
  <button
    class="theme-toggle"
    type="button"
    :aria-label="theme === 'dark' ? 'Светлая тема' : 'Тёмная тема'"
    :title="theme === 'dark' ? 'Светлая тема' : 'Тёмная тема'"
    @click="toggle($event)"
  >
    <Sun class="sun" :size="18" aria-hidden="true" />
    <Moon class="moon" :size="18" aria-hidden="true" />
  </button>
</template>
