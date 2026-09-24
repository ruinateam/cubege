<script setup lang="ts">
import { ChevronDown, ClipboardCheck, Clock3, LogIn, LogOut, Trophy, UserRound } from 'lucide-vue-next'
import brandMark from '@/assets/brand.svg'
import ThemeToggle from './ThemeToggle.vue'
import type { AuthUser } from '@/composables/useAuth'

defineProps<{ view: string; formattedTime: string; timerState: 'normal' | 'warning' | 'critical'; user: AuthUser | null; menuOpen: boolean }>()
defineEmits<{ home: []; connect: []; toggleMenu: []; profile: []; admin: []; top: []; signOut: [] }>()
</script>

<template>
  <header class="topbar">
    <a class="brand" href="#" aria-label="ЕГЭ по кубам — главная" @click.prevent="$emit('home')"><span class="brand-mark" aria-hidden="true"><img :src="brandMark" alt="" /></span><span class="brand-wordmark">егэ<span class="brand-muted">/</span>кубы</span></a>
    <div class="topbar-actions">
      <button class="button button-ghost top-link" type="button" @click="$emit('top')"><Trophy :size="17" aria-hidden="true" /> Топ</button>
      <ThemeToggle />
      <div v-if="view === 'exam'" class="timer" :class="`timer--${timerState}`"><Clock3 :size="16" aria-hidden="true" /> {{ formattedTime }}</div>
      <button v-else-if="!user" class="button button-ghost user-button" type="button" @click="$emit('connect')"><LogIn :size="17" aria-hidden="true" /> Войти через Twitch</button>
      <div v-else class="account-menu"><button class="account-trigger" type="button" :aria-expanded="menuOpen" aria-haspopup="menu" @click="$emit('toggleMenu')"><img v-if="user.avatarUrl" :src="user.avatarUrl" alt="" /><span v-else class="avatar-fallback" aria-hidden="true">{{ user.label.slice(0, 1) }}</span><span>{{ user.label }}</span><ChevronDown :size="15" aria-hidden="true" /></button><div v-if="menuOpen" class="account-popover" role="menu"><button type="button" role="menuitem" @click="$emit('profile')"><UserRound :size="16" aria-hidden="true" /> Профиль</button><button v-if="user.isAdmin" type="button" role="menuitem" @click="$emit('admin')"><ClipboardCheck :size="16" aria-hidden="true" /> Проверка</button><button v-if="user.isAnonymous" type="button" role="menuitem" @click="$emit('connect')"><LogIn :size="16" aria-hidden="true" /> Привязать Twitch</button><button v-if="!user.isAnonymous" type="button" role="menuitem" @click="$emit('signOut')"><LogOut :size="16" aria-hidden="true" /> Выйти</button></div></div>
    </div>
  </header>
</template>
