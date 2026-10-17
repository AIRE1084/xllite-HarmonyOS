import preferences from '@ohos.data.preferences'
import common from '@ohos.app.ability.common'
import { TodoDraft, TodoItem } from '../models/TodoTypes'
import { buildTodoWidgetData } from '../utils/TodoWidgetData'
import { syncTodoReminders } from './TodoReminderService'
import { publishTodoWidgets } from './WidgetService'

const PREFS_NAME: string = 'xjit_todos'
const KEY_ITEMS: string = 'items'

let todoContext: common.UIAbilityContext | null = null
let todoStore: TodoItem[] = []
let loaded: boolean = false
let loadTask: Promise<void> | null = null
let prefsTask: Promise<preferences.Preferences> | null = null
let persistenceTask: Promise<void> = Promise.resolve()
let sessionVersion: number = 0

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
    if (item.dueAt !== undefined && (!Number.isSafeInteger(item.dueAt) || item.dueAt <= 0 || item.dueAt > 8640000000000000)) item.dueAt = undefined
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
      dueAt: item.dueAt,
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

function mutate(change: (items: TodoItem[]) => TodoItem[], version: number = sessionVersion): Promise<TodoItem[]> {
  const writeTask = persistenceTask.then(async (): Promise<TodoItem[]> => {
    await loadTodos()
    if (version !== sessionVersion) throw new Error('待办会话已变化，请重新进入')
    const next = change(cloneItems(todoStore))
    const snapshot = JSON.stringify(next)
    const task = getPrefs()
    if (task === null) throw new Error('待办存储尚未初始化')
    const prefs = await task
    await prefs.put(KEY_ITEMS, snapshot)
    await prefs.flush()
    todoStore = next
    if (todoContext !== null) {
      try { await publishTodoWidgets(todoContext, buildTodoWidgetData(todoStore)) }
      catch (_error) { console.warn('XJITTodo: task saved; widget refresh pending') }
    }
    return cloneItems(todoStore)
  })
  persistenceTask = writeTask.then(() => {}).catch((_e: Error) => {})
  return writeTask
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
  if (draft.dueAt !== undefined && (!Number.isSafeInteger(draft.dueAt) || draft.dueAt <= 0 || draft.dueAt > 8640000000000000)) {
    throw new Error('请选择有效的任务时间')
  }
  const version = sessionVersion
  await loadTodos()
  const now = Date.now()
  const item: TodoItem = {
    id: now.toString() + '_' + Math.floor(Math.random() * 100000).toString(),
    title: draft.title.trim(),
    note: draft.note.trim(),
    dueText: draft.dueText.trim(),
    dueAt: draft.dueAt,
    done: false,
    createdAt: now,
    updatedAt: now,
  }
  if (item.title.length === 0) {
    return cloneItems(todoStore)
  }
  return mutate((items: TodoItem[]): TodoItem[] => { items.unshift(item); return items }, version)
}

export async function toggleTodo(id: string): Promise<TodoItem[]> {
  const version = sessionVersion
  await loadTodos()
  const now = Date.now()
  return mutate((items: TodoItem[]): TodoItem[] => items.map((item: TodoItem): TodoItem => {
    if (item.id !== id) {
      return item
    }
    return {
      id: item.id,
      title: item.title,
      note: item.note,
      dueText: item.dueText,
      dueAt: item.dueAt,
      done: !item.done,
      createdAt: item.createdAt,
      updatedAt: now,
    }
  }), version)
}

export async function deleteTodo(id: string): Promise<TodoItem[]> {
  const version = sessionVersion
  await loadTodos()
  return mutate((items: TodoItem[]): TodoItem[] => items.filter((item: TodoItem): boolean => item.id !== id), version)
}

export function registerTodoReminders(): Promise<number> {
  const version = sessionVersion
  const task = persistenceTask.then(async (): Promise<number> => {
    await loadTodos()
    if (version !== sessionVersion || todoContext === null) throw new Error('待办会话已变化，请重新进入')
    return syncTodoReminders(cloneItems(todoStore), todoContext.abilityInfo.bundleName)
  })
  persistenceTask = task.then(() => {}).catch((_error: Error) => {})
  return task
}
export function refreshTodoWidgets(): Promise<void> {
  const version = sessionVersion
  const refresh = persistenceTask.then(async () => {
    await loadTodos()
    if (version !== sessionVersion || todoContext === null) return
    await publishTodoWidgets(todoContext, buildTodoWidgetData(todoStore))
  })
  persistenceTask = refresh.catch((_error: Error) => {})
  return refresh
}
export async function clearTodos(): Promise<void> {
  sessionVersion++
  if (todoContext === null) return
  await mutate((_items: TodoItem[]): TodoItem[] => [])
}
export function countOpenTodos(items: TodoItem[]): number {
  return items.filter((item: TodoItem): boolean => !item.done).length
}
