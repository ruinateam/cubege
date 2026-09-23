import { computed, ref } from 'vue'
import { ensureAnonymousSession, getVariants, type ExamVariant } from '@/lib/supabase'

export function useVariants() {
  const variants = ref<ExamVariant[]>([])
  const selectedSlug = ref('')
  const variantsError = ref('')
  const isLoadingVariants = ref(false)

  const selectedVariant = computed(() => variants.value.find((item) => item.slug === selectedSlug.value) ?? null)

  async function loadVariants() {
    if (variants.value.length || isLoadingVariants.value) return
    isLoadingVariants.value = true
    try {
      try { await ensureAnonymousSession() } catch { /* Каталог вариантов публичный: anon-роль тоже имеет доступ. */ }
      variants.value = await getVariants()
      if (!selectedSlug.value && variants.value.length) selectedSlug.value = variants.value[0].slug
      if (!variants.value.length) variantsError.value = 'Опубликованных вариантов пока нет.'
    } catch {
      variantsError.value = 'Не удалось загрузить варианты. Обновите страницу и попробуйте ещё раз.'
    } finally {
      isLoadingVariants.value = false
    }
  }

  return { variants, selectedSlug, selectedVariant, variantsError, isLoadingVariants, loadVariants }
}
