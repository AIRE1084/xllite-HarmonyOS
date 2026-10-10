import common from '@ohos.app.ability.common'
import fs from '@ohos.file.fs'
import { formProvider, formBindingData } from '@kit.FormKit'
import { ScheduleSnapshot, CampusWidgetData } from '../models/CampusCompanionTypes'
import { widgetData } from '../utils/CourseCalendar'

const FILE_NAME: string = '/campus_widget.json'
export function readWidgetSnapshot(context: common.Context): ScheduleSnapshot | null {
  try { return JSON.parse(fs.readTextSync(context.filesDir + FILE_NAME)) as ScheduleSnapshot } catch (_e) { return null }
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
  return formBindingData.createFormBindingData(widgetData(readWidgetSnapshot(context)))
}
