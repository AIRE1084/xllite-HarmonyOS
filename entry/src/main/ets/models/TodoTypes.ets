export interface TodoItem {
  id: string
  title: string
  note: string
  dueText: string
  done: boolean
  createdAt: number
  updatedAt: number
}

export interface TodoDraft {
  title: string
  note: string
  dueText: string
}
