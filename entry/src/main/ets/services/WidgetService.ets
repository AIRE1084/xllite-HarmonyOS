import common from '@ohos.app.ability.common'
import fs from '@ohos.file.fs'
import { formProvider, formBindingData } from '@kit.FormKit'
import { ScheduleSnapshot, CampusWidgetData } from '../models/CampusCompanionTypes'
import { widgetData } from '../utils/CourseCalendar'

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
export function buildWidgetBinding(context: common.Context): formBindingData.FormBindingData {
  try {
    return formBindingData.createFormBindingData(widgetData(readWidgetSnapshot(context)))
  } catch (_error) {
    return formBindingData.createFormBindingData(widgetData(null))
  }
}
