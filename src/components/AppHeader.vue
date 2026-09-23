<script setup lang="ts">
import { ChevronDown, Clock3, LogIn, LogOut, UserRound } from 'lucide-vue-next'
import brandMark from '@/assets/brand.svg'
import type { AuthUser } from '@/composables/useAuth'

defineProps<{ view: string; formattedTime: string; isUrgent: boolean; user: AuthUser | null; menuOpen: boolean }>()
defineEmits<{ home: []; connect: []; toggleMenu: []; profile: []; signOut: [] }>()
</script>

<template>
  <header class="topbar">
    <a class="brand" href="#" aria-label="ЕГЭ по кубам — главная" @click.prevent="$emit('home')"><span class="brand-mark" aria-hidden="true"><img :src="brandMark" alt="" /></span><span class="brand-wordmark">егэ<span class="brand-muted">/</span>кубы</span></a>
    <div v-if="view === 'exam'" class="timer" :class="{ urgent: isUrgent }"><Clock3 :size="16" aria-hidden="true" /> {{ formattedTime }}</div>
    <button v-else-if="!user || user.isAnonymous" class="button button-ghost user-button" type="button" @click="$emit('connect')"><LogIn :size="17" aria-hidden="true" /> Войти через Twitch</button>
    <div v-else class="account-menu"><button class="account-trigger" type="button" :aria-expanded="menuOpen" aria-haspopup="menu" @click="$emit('toggleMenu')"><img v-if="user.avatarUrl" :src="user.avatarUrl" alt="" /><span v-else class="avatar-fallback" aria-hidden="true">{{ user.label.slice(0, 1) }}</span><span>{{ user.label }}</span><ChevronDown :size="15" aria-hidden="true" /></button><div v-if="menuOpen" class="account-popover" role="menu"><button type="button" role="menuitem" @click="$emit('profile')"><UserRound :size="16" aria-hidden="true" /> Профиль</button><button type="button" role="menuitem" @click="$emit('signOut')"><LogOut :size="16" aria-hidden="true" /> Выйти</button></div></div>
  </header>
</template>
