import common from '@ohos.app.ability.common'
import fs from '@ohos.file.fs'
import { formProvider, formBindingData } from '@kit.FormKit'
import { ScheduleSnapshot, CampusWidgetData } from '../models/CampusCompanionTypes'
import { widgetData } from '../utils/CourseCalendar'

import { TodoWidgetData } from '../utils/TodoWidgetData'

export function saveTodoWidgetSnapshot(context: common.Context, data: TodoWidgetData): void {
  const path = context.filesDir + '/todo_widget.json'
  const file = fs.openSync(path + '.tmp', fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC)
  try { fs.writeSync(file.fd, JSON.stringify(data)) } finally { fs.closeSync(file) }
  fs.renameSync(path + '.tmp', path)
}
export async function publishTodoWidgets(context: common.Context, data: TodoWidgetData): Promise<void> {
  saveTodoWidgetSnapshot(context, data)
  const forms = await formProvider.getPublishedRunningFormInfos()
  for (const form of forms) {
    if (form.formName === 'CampusTodoCard') {
      await formProvider.updateForm(form.formId, formBindingData.createFormBindingData(data))
    }
  }
}
function readTodoWidgetSnapshot(context: common.Context): TodoWidgetData {
  try {
    const data = JSON.parse(fs.readTextSync(context.filesDir + '/todo_widget.json')) as TodoWidgetData
    if (data !== null && Number.isSafeInteger(data.openCount) && data.openCount >= 0 &&
      Number.isSafeInteger(data.overdueCount) && data.overdueCount >= 0 && data.overdueCount <= data.openCount &&
      typeof data.firstTitle === 'string' && typeof data.secondTitle === 'string' && typeof data.thirdTitle === 'string') return data
  } catch (_error) {}
  return { openCount: 0, overdueCount: 0, firstTitle: '打开应用同步待办', secondTitle: '', thirdTitle: '' }
}
const FILE_NAME: string = '/campus_widget.json'
export function readWidgetSnapshot(context: common.Context): ScheduleSnapshot | null {
  try {
    const saved = JSON.parse(fs.readTextSync(context.filesDir + FILE_NAME)) as ScheduleSnapshot | null
    if (saved === null || typeof saved.account !== 'string' || typeof saved.term !== 'string' ||
      !Array.isArray(saved.courses) || !Number.isInteger(saved.totalWeeks) || saved.totalWeeks < 1 || saved.totalWeeks > 60 ||
      !Number.isInteger(saved.currentWeek) || saved.currentWeek < 1 || saved.currentWeek > saved.totalWeeks ||
      typeof saved.weekKnown !== 'boolean' || typeof saved.widgetEnabled !== 'boolean' ||
      typeof saved.anchorDate !== 'string' || !Number.isFinite(saved.updatedAt)) return null
    for (const course of saved.courses) {
      if (course === null || typeof course.day !== 'string' || typeof course.title !== 'string' ||
        typeof course.weeks !== 'string' || typeof course.sections !== 'string' || typeof course.location !== 'string') return null
    }
    return saved
  } catch (_e) { return null }
}
export function saveWidgetSnapshot(context: common.Context, snapshot: ScheduleSnapshot | null): void {
  const path = context.filesDir + FILE_NAME
  const file = fs.openSync(path + '.tmp', fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC)
  try { fs.writeSync(file.fd, JSON.stringify(snapshot)) } finally { fs.closeSync(file) }
  fs.renameSync(path + '.tmp', path)
}
export async function updateCampusWidgets(data: CampusWidgetData): Promise<void> {
  const forms = await formProvider.getPublishedRunningFormInfos()
  for (const form of forms) {
    if (form.formName === 'CampusScheduleCard') {
      await formProvider.updateForm(form.formId, formBindingData.createFormBindingData(data))
    }
  }
}
export function buildFormBinding(context: common.Context, formName: string): formBindingData.FormBindingData {
  try {
    if (formName === 'CampusTodoCard') {
      return formBindingData.createFormBindingData(readTodoWidgetSnapshot(context))
    }
    return buildWidgetBinding(context)
  } catch (_error) {
    // Binding construction must never fail form creation; fall back to the pending-state card.
    const fallback: formBindingData.FormBindingData = { data: widgetData(null) }
    return fallback
  }
}
export function buildWidgetBinding(context: common.Context): formBindingData.FormBindingData {
  try {
    return formBindingData.createFormBindingData(widgetData(readWidgetSnapshot(context)))
  } catch (_error) {
    return formBindingData.createFormBindingData(widgetData(null))
  }
}
