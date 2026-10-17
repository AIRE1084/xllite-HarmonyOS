import { TodoItem } from '../models/TodoTypes'

export interface TodoReminderPlan {
  taskId: string
  title: string
  triggerAt: number
  route: string
}

export function buildTodoReminderPlans(items: TodoItem[], now: number = Date.now()): TodoReminderPlan[] {
  const plans: TodoReminderPlan[] = []
  for (const item of items) {
    if (item.done || item.dueAt === undefined || !Number.isSafeInteger(item.dueAt) ||
      item.dueAt <= now || item.dueAt > 8640000000000000) continue
    // Calendar reminders accept minute precision; never deliver before the selected time.
    const triggerAt = Math.ceil(item.dueAt / 60000) * 60000
    if (triggerAt > 8640000000000000) continue
    plans.push({ taskId: item.id, title: item.title, triggerAt: triggerAt, route: 'todo' })
  }
  return plans.sort((a: TodoReminderPlan, b: TodoReminderPlan): number => a.triggerAt - b.triggerAt || a.taskId.localeCompare(b.taskId))
}
