export type Question = {
  id: number
  kind: 'short' | 'long'
  points: number
  prompt: string
  options?: string[]
}

export const scoreScale = [0, 7, 14, 20, 27, 34, 40, 43, 46, 48, 51, 54, 56, 59, 62, 64, 67, 70, 72, 75, 78, 80, 83, 86, 88, 91, 94, 97, 100]
