import { TodoItem } from '../models/TodoTypes'

export interface TodoWidgetData {
  openCount: number
  overdueCount: number
  firstTitle: string
  secondTitle: string
  thirdTitle: string
}

export function buildTodoWidgetData(items: TodoItem[], now: number = Date.now()): TodoWidgetData {
  const open = items.filter((item: TodoItem): boolean => !item.done)
  open.sort((a: TodoItem, b: TodoItem): number => {
    const aDue = a.dueAt === undefined ? Number.MAX_SAFE_INTEGER : a.dueAt
    const bDue = b.dueAt === undefined ? Number.MAX_SAFE_INTEGER : b.dueAt
    return aDue - bDue || a.createdAt - b.createdAt || a.id.localeCompare(b.id)
  })
  return {
    openCount: open.length,
    overdueCount: open.filter((item: TodoItem): boolean => item.dueAt !== undefined && item.dueAt < now).length,
    firstTitle: open.length > 0 ? open[0].title : '暂无待办',
    secondTitle: open.length > 1 ? open[1].title : '',
    thirdTitle: open.length > 2 ? open[2].title : '',
  }
}
