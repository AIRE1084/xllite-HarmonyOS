import reminderAgentManager from '@ohos.reminderAgentManager'

export async function cancelReminderGroup(groupId: string): Promise<void> {
  if (groupId.length === 0) throw new Error('提醒分组不能为空')
  const reminders = await reminderAgentManager.getAllValidReminders()
  for (const reminder of reminders) {
    if (reminder.reminderReq.groupId === groupId) {
      await reminderAgentManager.cancelReminder(reminder.reminderId)
    }
  }
}
