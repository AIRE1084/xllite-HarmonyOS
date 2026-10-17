import preferences from '@ohos.data.preferences'
import common from '@ohos.app.ability.common'
import { TodoDraft, TodoItem } from '../models/TodoTypes'

const PREFS_NAME: string = 'xjit_todos'
const KEY_ITEMS: string = 'items'

let todoContext: common.UIAbilityContext | null = null
let todoStore: TodoItem[] = []
let loaded: boolean = false
let loadTask: Promise<void> | null = null
let prefsTask: Promise<preferences.Preferences> | null = null
let persistenceTask: Promise<void> = Promise.resolve()

export function setTodoContext(ctx: common.UIAbilityContext): void {
  todoContext = ctx
}

function parseItems(raw: string): TodoItem[] {
  const data = JSON.parse(raw) as Object
  if (!Array.isArray(data)) return []
  const valid: TodoItem[] = []
  const ids: Set<string> = new Set<string>()
  for (const value of data as Object[]) {
    if (value === null || typeof value !== 'object') continue
    const item = value as TodoItem
    if (typeof item.id !== 'string' || item.id.length === 0 ||
      typeof item.title !== 'string' || item.title.trim().length === 0 ||
      typeof item.note !== 'string' || typeof item.dueText !== 'string' || typeof item.done !== 'boolean' ||
      !Number.isFinite(item.createdAt) || !Number.isFinite(item.updatedAt) ||
      item.createdAt < 0 || item.updatedAt < item.createdAt) continue
    if (ids.has(item.id)) continue
    ids.add(item.id)
    valid.push(item)
  }
  return valid
}
function cloneItems(items: TodoItem[]): TodoItem[] {
  return items.map((item: TodoItem): TodoItem => {
    return {
      id: item.id,
      title: item.title,
      note: item.note,
      dueText: item.dueText,
      done: item.done,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    }
  })
}

function getPrefs(): Promise<preferences.Preferences> | null {
  if (todoContext === null) return null
  if (prefsTask === null) {
    prefsTask = preferences.getPreferences(todoContext, PREFS_NAME).catch((e: Error) => {
      prefsTask = null
      throw e
    })
  }
  return prefsTask
}

function persist(): Promise<void> {
  const snapshot = JSON.stringify(todoStore)
  persistenceTask = persistenceTask.then(async () => {
    const task = getPrefs()
    if (task === null) return
    const prefs = await task
    await prefs.put(KEY_ITEMS, snapshot)
    await prefs.flush()
  }).catch((_e: Error) => {})
  return persistenceTask
}

export async function loadTodos(): Promise<TodoItem[]> {
  if (loaded) return cloneItems(todoStore)
  if (loadTask === null) {
    loadTask = (async (): Promise<void> => {
      try {
        const task = getPrefs()
        if (task === null) return
        const prefs = await task
        const raw = await prefs.get(KEY_ITEMS, '')
        if (typeof raw === 'string' && raw.length > 0) todoStore = parseItems(raw)
        loaded = true
      } catch (_e) { todoStore = [] }
    })()
  }
  const task = loadTask
  try { await task } finally { if (loadTask === task) loadTask = null }
  return cloneItems(todoStore)
}

export async function addTodo(draft: TodoDraft): Promise<TodoItem[]> {
  await loadTodos()
  const now = Date.now()
  const item: TodoItem = {
    id: now.toString() + '_' + Math.floor(Math.random() * 100000).toString(),
    title: draft.title.trim(),
    note: draft.note.trim(),
    dueText: draft.dueText.trim(),
    done: false,
    createdAt: now,
    updatedAt: now,
  }
  if (item.title.length === 0) {
    return cloneItems(todoStore)
  }
  todoStore.unshift(item)
  await persist()
  return cloneItems(todoStore)
}

export async function toggleTodo(id: string): Promise<TodoItem[]> {
  await loadTodos()
  const now = Date.now()
  todoStore = todoStore.map((item: TodoItem): TodoItem => {
    if (item.id !== id) {
      return item
    }
    return {
      id: item.id,
      title: item.title,
      note: item.note,
      dueText: item.dueText,
      done: !item.done,
      createdAt: item.createdAt,
      updatedAt: now,
    }
  })
  await persist()
  return cloneItems(todoStore)
}

export async function deleteTodo(id: string): Promise<TodoItem[]> {
  await loadTodos()
  todoStore = todoStore.filter((item: TodoItem): boolean => item.id !== id)
  await persist()
  return cloneItems(todoStore)
}

export function countOpenTodos(items: TodoItem[]): number {
  return items.filter((item: TodoItem): boolean => !item.done).length
}
