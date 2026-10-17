import reminderAgentManager from '@ohos.reminderAgentManager'

export async function cancelReminderGroup(groupId: string): Promise<void> {
  if (groupId.length === 0) throw new Error('提醒分组不能为空')
  const reminders = await reminderAgentManager.getAllValidReminders()
  let firstError: Error | null = null
  for (const reminder of reminders) {
    if (reminder.reminderReq.groupId === groupId) {
      try { await reminderAgentManager.cancelReminder(reminder.reminderId) }
      catch (error) { if (firstError === null) firstError = error as Error }
    }
  }
  if (firstError !== null) throw firstError
}
