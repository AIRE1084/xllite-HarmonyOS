import reminderAgentManager from '@ohos.reminderAgentManager'
import notificationManager from '@ohos.notificationManager'
import { TodoItem } from '../models/TodoTypes'
import { buildTodoReminderPlans } from '../utils/TodoReminderPlan'
import { cancelReminderGroup } from './ReminderGroups'

let reminderQueue: Promise<void> = Promise.resolve()
let reminderVersion: number = 0

export function clearTodoReminders(): Promise<void> {
  reminderVersion++
  const task = reminderQueue.then(() => cancelReminderGroup('campus_todos'))
  reminderQueue = task.catch((_error: Error) => {})
  return task
}

export function syncTodoReminders(items: TodoItem[], bundleName: string): Promise<number> {
  const snapshot = items.map((item: TodoItem): TodoItem => ({ id: item.id, title: item.title, note: '', dueText: '',
    dueAt: item.dueAt, done: item.done, createdAt: item.createdAt, updatedAt: item.updatedAt }))
  const version = reminderVersion
  const task = reminderQueue.then(() => version === reminderVersion ? replaceTodoReminders(snapshot, bundleName) : 0)
  reminderQueue = task.then(() => {}).catch((_error: Error) => {})
  return task
}
async function replaceTodoReminders(items: TodoItem[], bundleName: string): Promise<number> {
  const plans = buildTodoReminderPlans(items)
  if (plans.length > 0 && !await notificationManager.isNotificationEnabled()) throw new Error('请允许通知后再登记待办提醒')
  await cancelReminderGroup('campus_todos')
  let count: number = 0
  try {
    for (const plan of plans) {
      const trigger = new Date(plan.triggerAt)
      const request: reminderAgentManager.ReminderRequestCalendar = {
        reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
        dateTime: { year: trigger.getFullYear(), month: trigger.getMonth() + 1, day: trigger.getDate(),
          hour: trigger.getHours(), minute: trigger.getMinutes() },
        title: '待办任务 · ' + plan.title, content: '点击查看并管理任务', expiredContent: '任务时间已到',
        wantAgent: { pkgName: bundleName, abilityName: 'EntryAbility', parameters: { campusRoute: plan.route } },
        notificationId: 9400 + count, groupId: 'campus_todos',
        slotType: notificationManager.SlotType.SERVICE_INFORMATION, tapDismissed: true,
        ringDuration: 0, snoozeTimes: 0,
      }
      await reminderAgentManager.publishReminder(request)
      count++
    }
  } catch (error) {
    await cancelReminderGroup('campus_todos')
    throw error as Error
  }
  return count
}
