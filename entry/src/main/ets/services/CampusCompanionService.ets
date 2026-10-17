import { cancelReminderGroup } from './ReminderGroups'
import common from '@ohos.app.ability.common'
import preferences from '@ohos.data.preferences'
import notificationManager from '@ohos.notificationManager'
import reminderAgentManager from '@ohos.reminderAgentManager'
import { BusinessError } from '@ohos.base'
import { Course } from '../models/JwTypes'
import { ScheduleSnapshot, CampusWidgetData } from '../models/CampusCompanionTypes'
import { buildOccurrences, widgetData, localDateText, parseLocalDate, weekOnDate } from '../utils/CourseCalendar'
import { readWidgetSnapshot, saveWidgetSnapshot, updateCampusWidgets } from './WidgetService'
import { isLiveViewSupported, startCourseLiveView, finishAllLiveViews, getCurrentHandle, setLiveViewBundleName } from './LiveViewService'
import { getCacheEpoch } from './MemoryCache'

let context: common.UIAbilityContext | null = null
let applicationBundleName: string = 'com.xjit.app'
let prefs: preferences.Preferences | null = null
let readyTask: Promise<void> = Promise.resolve()
let work: Promise<void> = Promise.resolve()
let snapshot: ScheduleSnapshot | null = null
let activeAccount: string = ''
let revision: number = 0
let lastPlan: string = ''
let foregroundTimer: number = -1
const REMINDER_LIMIT: number = 24

export function getCampusBundleName(): string { return applicationBundleName }
export function initCampusCompanion(ctx: common.UIAbilityContext, bundleName: string = ''): Promise<void> {
  context = ctx
  applicationBundleName = bundleName || ctx.applicationInfo?.name || ctx.abilityInfo?.bundleName || 'com.xjit.app'
  setLiveViewBundleName(applicationBundleName)
  AppStorage.setOrCreate<boolean>('campusWidgetEnabled', false)
  AppStorage.setOrCreate<boolean>('courseReminderEnabled', false)
  AppStorage.setOrCreate<boolean>('liveViewEnabled', false)
  AppStorage.setOrCreate<boolean>('scheduleWeekKnown', false)
  AppStorage.setOrCreate<string>('courseReminderStatus', '未开启')
  AppStorage.setOrCreate<string>('campusWidgetStatus', '未开启')
  AppStorage.setOrCreate<string>('liveViewStatus', '未开启')
  readyTask = (async (): Promise<void> => {
    prefs = await preferences.getPreferences(ctx, 'xjit_campus_companion')
    AppStorage.setOrCreate<boolean>('campusWidgetEnabled', (await prefs.get('widget', false)) === true)
    AppStorage.setOrCreate<boolean>('courseReminderEnabled', (await prefs.get('reminders', false)) === true)
    AppStorage.setOrCreate<boolean>('liveViewEnabled', (await prefs.get('live', false)) === true)
    snapshot = readWidgetSnapshot(ctx)
  })()
  return readyTask
}
function enqueue(action: () => Promise<void>): Promise<void> {
  const task = work.then(async () => { await readyTask; await action() })
  work = task.catch((_e: Error) => {})
  return task
}
function publishWeek(): void {
  if (snapshot === null) return
  const week = weekOnDate(snapshot, new Date())
  AppStorage.setOrCreate<boolean>('scheduleWeekKnown', snapshot.weekKnown && week >= 1 && week <= snapshot.totalWeeks)
  AppStorage.setOrCreate<number>('currentWeek', Math.min(snapshot.totalWeeks, Math.max(1, week || snapshot.currentWeek)))
  AppStorage.setOrCreate<number>('totalWeeks', snapshot.totalWeeks)
  AppStorage.setOrCreate<string>('term', snapshot.term)
}
async function persist(): Promise<void> {
  if (context === null || prefs === null) return
  if (snapshot !== null) snapshot.widgetEnabled = AppStorage.get<boolean>('campusWidgetEnabled') === true
  saveWidgetSnapshot(context, snapshot)
  await prefs.put('widget', AppStorage.get<boolean>('campusWidgetEnabled') === true)
  await prefs.put('reminders', AppStorage.get<boolean>('courseReminderEnabled') === true)
  await prefs.put('live', AppStorage.get<boolean>('liveViewEnabled') === true)
  await prefs.flush()
}
async function syncWidgets(): Promise<void> {
  if (context === null) return
  let phase: string = 'snapshot'
  try {
    if (snapshot !== null) snapshot.widgetEnabled = AppStorage.get<boolean>('campusWidgetEnabled') === true
    saveWidgetSnapshot(context, snapshot)
    phase = 'system-update'
    await updateCampusWidgets(widgetData(snapshot))
    phase = 'view-status'
    AppStorage.setOrCreate<number>('companionVersion', (AppStorage.get<number>('companionVersion') ?? 0) + 1)
    AppStorage.setOrCreate<string>('campusWidgetStatus', AppStorage.get<boolean>('campusWidgetEnabled') === true ? '已同步课程，添加后显示在桌面' : '已暂停桌面课程显示')
  } catch (error) {
    const failure = error as BusinessError
    console.warn('[CampusCompanion] widget sync failed phase=' + phase + ' code=' + String(failure.code) + ' message=' + failure.message)
    AppStorage.setOrCreate<string>('campusWidgetStatus', '桌面卡片更新失败，请重试')
  }
}
async function syncReminders(): Promise<void> {
  const version = revision
  const enabled = AppStorage.get<boolean>('courseReminderEnabled') === true
  const valid = snapshot !== null && snapshot.account === activeAccount && snapshot.weekKnown
  const upcoming = enabled && valid && snapshot !== null ? buildOccurrences(snapshot, new Date(), 7)
    .filter((item): boolean => item.startTime - 600000 > Date.now()) : []
  const items = upcoming.slice(0, REMINDER_LIMIT)
  const plan = enabled + '|' + localDateText(new Date()) + '|' + upcoming.length + '|' + items.map((item): string => item.key).join(';')
  if (plan === lastPlan) return
  try {
    // Recover orphan course reminders without deleting other feature groups.
    await cancelReminderGroup('campus_courses')
    if (version !== revision) return
    const ids: number[] = []
    let capacityFull: boolean = false
    if (enabled && valid) {
      if (!await notificationManager.isNotificationEnabled()) throw new Error('请允许通知后再开启课程提醒')
      for (const item of items) {
        if (version !== revision || AppStorage.get<boolean>('courseReminderEnabled') !== true) return
        if (item.startTime - 600000 <= Date.now()) continue
        const trigger = new Date(item.startTime - 600000)
        const request: reminderAgentManager.ReminderRequestCalendar = {
          reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
          dateTime: { year: trigger.getFullYear(), month: trigger.getMonth() + 1, day: trigger.getDate(),
            hour: trigger.getHours(), minute: trigger.getMinutes() },
          title: '10 分钟后上课 · ' + item.course.title,
          content: item.course.location + ' · ' + item.course.sections,
          expiredContent: '课程已开始 · ' + item.course.title,
          wantAgent: { pkgName: applicationBundleName, abilityName: 'EntryAbility', parameters: { campusRoute: 'schedule' } },
          notificationId: 8400 + ids.length, groupId: 'campus_courses',
          slotType: notificationManager.SlotType.SERVICE_INFORMATION, tapDismissed: true,
          ringDuration: 0, snoozeTimes: 0,
        }
        let id: number
        try {
          id = await reminderAgentManager.publishReminder(request)
        } catch (error) {
          if ((error as BusinessError).code !== 1700002) throw error as Error
          capacityFull = true
          break
        }
        if (version !== revision) { await reminderAgentManager.cancelReminder(id); return }
        ids.push(id)
        if (prefs !== null) { await prefs.put('reminderIds', JSON.stringify(ids)); await prefs.flush() }
      }
    }
    let capacityDetail: string = ''
    if (capacityFull) {
      try {
        const registered = await reminderAgentManager.getValidReminders()
        capacityDetail = '；系统登记数量 ' + registered.length + ' 条'
      } catch (_error) { capacityDetail = '；系统登记数量读取失败' }
      if (version !== revision) return
    }
    lastPlan = capacityFull ? '' : plan
    AppStorage.setOrCreate<string>('courseReminderStatus', !enabled ? '已关闭并取消课程提醒' :
      !valid ? '等待课表同步和当前周次校准' : capacityFull ?
         '系统提醒受限（1700002）：容量或系统提醒控制限制；已登记最近 ' + ids.length + ' 条' + capacityDetail + '；其余未登记，请检查系统提醒设置后重试' : upcoming.length > REMINDER_LIMIT ?
        '未来 7 天共 ' + upcoming.length + ' 条，已登记最近 ' + ids.length + ' 条；打开 APP 自动续订' :
        '已登记未来 7 天 ' + ids.length + ' 条课前提醒')
    if (prefs !== null) { await prefs.put('reminderIds', JSON.stringify(ids)); await prefs.flush() }
  } catch (error) {
    lastPlan = ''
    const err = error as BusinessError
    AppStorage.setOrCreate<string>('courseReminderStatus', err.code === 401 ? '提醒参数无效（401），请同步课表后重试' :
      err.code === 201 ? '提醒权限未授予（201）' : err.code === 1700001 ? '系统通知尚未开启（1700001）' :
      err.code !== undefined ? '提醒登记失败（' + err.code + '），请稍后重试' : (error as Error).message)
    throw error as Error
  }
}
async function syncLive(): Promise<void> {
  if (AppStorage.get<boolean>('liveViewEnabled') !== true) return
  if (snapshot === null || snapshot.account !== activeAccount || !snapshot.weekKnown) {
    AppStorage.setOrCreate<string>('liveViewStatus', '已开启，等待课表同步和当前周次校准')
    return
  }
  const next = buildOccurrences(snapshot, new Date(), 1).find((item): boolean => item.endTime > Date.now())
  if (next === undefined || next.startTime - Date.now() > 600000) {
    if (getCurrentHandle()?.targetType === 'course') await finishAllLiveViews()
    AppStorage.setOrCreate<string>('liveViewStatus', next === undefined ? '已开启，今天暂无后续课程' : '已开启，等待进入课前 10 分钟')
    return
  }
  await startCourseLiveView(next.course, next.startTime, next.endTime)
}
async function reconcile(requireReminderSuccess: boolean = false): Promise<void> {
  publishWeek()
  await persist()
  await syncWidgets()
  try { await syncReminders() } catch (error) { if (requireReminderSuccess) throw error as Error }
  await syncLive()
}
export function activateCampusCompanion(account: string): Promise<void> {
  return enqueue(async () => {
    activeAccount = account
    if (snapshot !== null && snapshot.account !== account) {
      revision++; snapshot = null; lastPlan = ''; await finishAllLiveViews()
    }
    await reconcile()
  })
}
export function acceptCampusSchedule(account: string, data: Record<string, Object>, epoch: number): Promise<void> {
  return enqueue(async () => {
    if (context === null || epoch !== getCacheEpoch() || account.length === 0 || (activeAccount.length > 0 && account !== activeAccount)) return
    const rawCourses: Object = data['courses']
    if (rawCourses === undefined || rawCourses === null || !Array.isArray(rawCourses)) {
      // Schedule source is not the native course list yet (e.g. gateway/legacy envelope);
      // keep the desktop widget, reminders and live view on the last valid snapshot
      // instead of overwriting them with an empty plan.
      publishWeek()
      return
    }
    const previous = snapshot !== null && snapshot.account === account && snapshot.term === String(data['term'] ?? '') ? snapshot : null
    const fetchedAt = Number(data['scheduleFetchedAt']) || Date.now()
    if (previous !== null && previous.updatedAt === fetchedAt) { publishWeek(); return }
    const sourceWeek = Number(data['currentWeek'] ?? data['week'])
    const primaryTotal = Number(data['totalWeeks'])
    const alternateTotal = Number(data['weeksTotal'])
    const total = Number.isInteger(primaryTotal) && primaryTotal >= 1 && primaryTotal <= 60 ? primaryTotal :
      Number.isInteger(alternateTotal) && alternateTotal >= 1 && alternateTotal <= 60 ? alternateTotal : previous?.totalWeeks ?? 20
    const weekKnown = Number.isInteger(sourceWeek) && sourceWeek >= 1 && sourceWeek <= total
    const start = parseLocalDate(String(data['termStartDate'] ?? ''))
    let week = weekKnown ? sourceWeek : previous?.currentWeek ?? 1
    let anchor = weekKnown ? localDateText(new Date(fetchedAt)) : previous?.anchorDate ?? localDateText(new Date(fetchedAt))
    let known = weekKnown || previous?.weekKnown === true
    const inheritedWeekValid = previous !== null && Number.isInteger(previous.currentWeek) && previous.currentWeek >= 1 && previous.currentWeek <= total
    if (!weekKnown && !inheritedWeekValid) { week = 1; known = false }
    const manual = previous?.manuallyCalibrated === true && inheritedWeekValid
    if (manual && previous !== null) {
      week = previous.currentWeek; anchor = previous.anchorDate; known = previous.weekKnown
    } else if (!weekKnown && start !== null) { week = 1; anchor = localDateText(start); known = true }
    snapshot = { account: account, term: String(data['term'] ?? ''), courses: (data['courses'] ?? []) as Course[],
      currentWeek: week, totalWeeks: total, weekKnown: known, anchorDate: anchor, manuallyCalibrated: manual, updatedAt: fetchedAt,
      widgetEnabled: AppStorage.get<boolean>('campusWidgetEnabled') === true }
    activeAccount = account; revision++
    await reconcile()
  })
}
export function getCampusWidgetData(): CampusWidgetData { return widgetData(snapshot) }
export function calibrateCampusWeek(week: number): Promise<void> {
  return enqueue(async () => {
    if (snapshot === null) throw new Error('请先同步真实课表')
    if (!Number.isInteger(week) || week < 1 || week > snapshot.totalWeeks) throw new Error('请选择有效教学周')
    revision++; snapshot.currentWeek = week; snapshot.anchorDate = localDateText(new Date()); snapshot.weekKnown = true; snapshot.manuallyCalibrated = true
    await reconcile()
  })
}
export async function setCampusOption(option: string, enabled: boolean): Promise<void> {
  await readyTask
  if (option === 'reminders' && enabled) {
    if (context === null) throw new Error('提醒服务尚未初始化')
    if (!await notificationManager.isNotificationEnabled()) {
      await notificationManager.requestEnableNotification(context)
      if (!await notificationManager.isNotificationEnabled()) throw new Error('未允许通知，课程提醒保持关闭')
    }
  }
  if (option === 'live' && enabled && !await isLiveViewSupported()) throw new Error('系统实况窗暂不可用，请检查系统设置')
  const key = option === 'widget' ? 'campusWidgetEnabled' : option === 'reminders' ? 'courseReminderEnabled' : 'liveViewEnabled'
  AppStorage.setOrCreate<boolean>(key, enabled); revision++
  let stopError: Error | null = null
  if (option === 'live' && !enabled) {
    try { await finishAllLiveViews() } catch (error) { stopError = error as Error }
  }
  await enqueue(async () => {
    try { await reconcile(option === 'reminders') } catch (error) {
      if (option === 'reminders' && enabled) {
        AppStorage.setOrCreate<boolean>('courseReminderEnabled', false)
        await cancelReminderGroup('campus_courses')
        lastPlan = ''; await persist()
      }
      throw error as Error
    }
  })
  if (stopError !== null) throw stopError
  if (option === 'live' && !enabled) AppStorage.setOrCreate<string>('liveViewStatus', '已关闭课程实况窗')
}
export function setCompanionForeground(active: boolean): void {
  if (foregroundTimer >= 0) clearInterval(foregroundTimer)
  foregroundTimer = -1
  if (!active) return
  const refresh = (): void => {
    if (activeAccount.length > 0) enqueue(async () => { publishWeek(); await syncWidgets(); await syncReminders(); await syncLive() }).catch((_e: Error) => {})
  }
  refresh()
  foregroundTimer = setInterval(refresh, 60000)
}
export function clearCampusCompanion(): Promise<void> {
  revision++; activeAccount = ''; snapshot = null; lastPlan = ''
  AppStorage.setOrCreate<boolean>('courseReminderEnabled', false)
  AppStorage.setOrCreate<boolean>('liveViewEnabled', false)
  AppStorage.setOrCreate<boolean>('scheduleWeekKnown', false)
  const stop = finishAllLiveViews().catch((_e: Error) => { AppStorage.setOrCreate<string>('liveViewStatus', '系统实况窗结束失败，请检查系统设置') })
  return enqueue(async () => {
    await stop
    AppStorage.setOrCreate<boolean>('courseReminderEnabled', false)
    AppStorage.setOrCreate<boolean>('liveViewEnabled', false)
    snapshot = null; activeAccount = ''
    await persist(); await syncWidgets(); await syncReminders()
  })
}
