import { onMounted, ref } from 'vue'

export type Theme = 'light' | 'dark'

const THEME_KEY = 'cubege-theme'
const DARK_META = '#161616'
const LIGHT_META = '#faf6ee'

const theme = ref<Theme>('light')
let initialized = false

function systemTheme(): Theme {
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
}

function storedTheme(): Theme | null {
  try {
    const value = localStorage.getItem(THEME_KEY)
    return value === 'light' || value === 'dark' ? value : null
  } catch {
    return null
  }
}

function apply(value: Theme) {
  theme.value = value
  document.documentElement.dataset.theme = value
  document.querySelector('meta[name="theme-color"]')?.setAttribute('content', value === 'dark' ? DARK_META : LIGHT_META)
}

function onSystemChange(event: MediaQueryListEvent) {
  if (!storedTheme()) apply(event.matches ? 'dark' : 'light')
}

export function useTheme() {
  function init() {
    if (initialized) return
    initialized = true
    apply(storedTheme() ?? systemTheme())
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', onSystemChange)
  }
  function toggle(event?: MouseEvent) {
    const next: Theme = theme.value === 'dark' ? 'light' : 'dark'
    try {
      localStorage.setItem(THEME_KEY, next)
    } catch {
      /* Приватный режим: выбор живёт до закрытия вкладки. */
    }
    const target = event?.currentTarget instanceof HTMLElement ? event.currentTarget : null
    const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    const doc = document as Document & { startViewTransition?: (update: () => void) => { ready: Promise<void> } }
    if (target && doc.startViewTransition && !reduceMotion) {
      const rect = target.getBoundingClientRect()
      const x = rect.left + rect.width / 2
      const y = rect.top + rect.height / 2
      const endRadius = Math.hypot(Math.max(x, window.innerWidth - x), Math.max(y, window.innerHeight - y))
      const transition = doc.startViewTransition(() => apply(next))
      transition.ready
        .then(() => {
          document.documentElement.animate(
            { clipPath: [`circle(0px at ${x}px ${y}px)`, `circle(${endRadius}px at ${x}px ${y}px)`] },
            { duration: 450, easing: 'cubic-bezier(0.2, 0, 0, 1)', pseudoElement: '::view-transition-new(root)' },
          )
        })
        .catch(() => {})
    } else {
      apply(next)
    }
  }
  onMounted(init)
  return { theme, toggle }
}
