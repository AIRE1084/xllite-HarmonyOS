import { liveViewManager } from '@kit.LiveViewKit'
import wantAgent from '@ohos.app.ability.wantAgent'
import { BusinessError } from '@ohos.base'
import { Course } from '../models/JwTypes'
import { TodoItem } from '../models/TodoTypes'
import { LiveViewHandle, LiveViewResult, LiveViewTarget } from '../models/LiveViewTypes'

export type { LiveViewHandle }
let currentView: liveViewManager.LiveView | null = null
let currentHandle: LiveViewHandle | null = null
let currentKey: string = ''
let revision: number = 0
let operation: Promise<void> = Promise.resolve()
let supportReason: string = '开启后检查系统实况窗能力'
let applicationBundleName: string = 'com.xjit.app'

export function setLiveViewBundleName(bundleName: string): void {
  applicationBundleName = bundleName.length > 0 ? bundleName : 'com.xjit.app'
}

function reasonFor(error: BusinessError): string {
  if (error.code === 1003500005) return '应用尚未获批华为实况窗 TIMER 场景权限'
  if (error.code === 1003500004) return '请在系统设置中允许新理工显示实况窗'
  if (error.code === 801 || error.code === 1003500003) return '当前设备不支持或无法连接实况窗服务'
  return '实况窗暂不可用（' + error.code + '）'
}
function setReason(reason: string): void {
  supportReason = reason
  AppStorage.setOrCreate<string>('liveViewStatus', reason)
}
export function getLiveViewSupportReason(): string { return supportReason }
export async function isLiveViewSupported(): Promise<boolean> {
  try {
    const enabled = await liveViewManager.isLiveViewEnabled()
    setReason(enabled ? '系统实况窗已允许，显示时仍需场景权限' : '系统实况窗未开启')
    return enabled
  } catch (error) { setReason(reasonFor(error as BusinessError)); return false }
}
export function buildCourseLiveTarget(course: Course, startTime: number, endTime: number): LiveViewTarget {
  return { type: 'course', title: course.title, text: course.sections, extra: course.location + ' · ' + course.teacher,
    startTime: startTime, endTime: endTime }
}
export function buildTodoLiveTarget(todo: TodoItem): LiveViewTarget {
  return { type: 'todo', title: todo.title, text: todo.dueText || '待办计时', extra: todo.note,
    startTime: Date.now(), endTime: Date.now() + 3600000 }
}
async function stopCurrent(): Promise<void> {
  if (currentView === null) return
  const view = currentView
  view.sequence = (view.sequence ?? 0) + 1
  if (view.liveViewData.capsule !== undefined) view.liveViewData.capsule.status = -1
  view.liveViewData.primary.keepTime = 0
  try {
    const result = await liveViewManager.stopLiveView(view)
    if (result.resultCode !== 0) throw new Error('系统结束实况窗失败：' + result.resultCode)
  } catch (error) {
    const code = (error as BusinessError).code
    if (code !== 1003500009 && code !== 1003500010) throw error as Error
  }
  currentView = null; currentHandle = null; currentKey = ''
}
async function startTarget(target: LiveViewTarget, captured: number): Promise<LiveViewResult> {
  if (AppStorage.get<boolean>('liveViewEnabled') !== true) return { ok: false, reason: '请先在「桌面与提醒」开启实况窗' }
  if (target.endTime <= Date.now() || target.startTime < 1000000000000) return { ok: false, reason: '课程时间无效或已结束' }
  if (!await isLiveViewSupported()) return { ok: false, reason: supportReason }
  if (captured !== revision || AppStorage.get<boolean>('liveViewEnabled') !== true) return { ok: false, reason: '实况窗已关闭' }
  const key = target.type + '|' + target.title + '|' + target.startTime
  if (currentKey === key && currentHandle !== null && currentView !== null) {
    if (target.startTime <= Date.now() && currentView.liveViewData.capsule?.content === '距上课') {
      currentView.sequence = (currentView.sequence ?? 0) + 1
      currentView.timer = { time: Math.max(0, target.endTime - Date.now()), isCountdown: true }
      currentView.liveViewData.capsule = { type: liveViewManager.CapsuleType.CAPSULE_TYPE_TIMER,
        status: 1, content: '上课中', time: Math.max(0, target.endTime - Date.now()), isCountdown: true }
      try {
        const result = await liveViewManager.updateLiveView(currentView)
        if (result.resultCode !== 0) { setReason('实况窗更新失败（' + result.resultCode + '）'); return { ok: false, reason: supportReason } }
      } catch (error) { setReason(reasonFor(error as BusinessError)); return { ok: false, reason: supportReason } }
    }
    setReason('实况窗已显示')
    return { ok: true, handle: currentHandle }
  }
  await stopCurrent()
  if (captured !== revision) return { ok: false, reason: '实况窗已关闭' }
  try {
    const action = await wantAgent.getWantAgent({ wants: [{ bundleName: applicationBundleName, abilityName: 'EntryAbility',
      parameters: { campusRoute: target.type === 'course' ? 'schedule' : 'todo' } }],
      operationType: wantAgent.OperationType.START_ABILITY, requestCode: 8201,
      wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG] })
    const deadline = target.startTime > Date.now() ? target.startTime : target.endTime
    const duration = Math.max(0, deadline - Date.now())
    const view: liveViewManager.LiveView = {
      id: Math.floor(Date.now() / 1000), event: 'TIMER', sequence: 0, isMute: true,
      lifeCycleMode: liveViewManager.LifeCycleMode.AUTO_STOP_WHEN_APP_TERMINATE,
      timer: { time: duration, isCountdown: true },
      liveViewData: {
        primary: { title: target.title.slice(0, 40), content: [{ text: target.extra.slice(0, 60) }],
          clickAction: action, aliveTime: Math.max(15, Math.min(28800, Math.ceil((target.endTime - Date.now()) / 1000))) },
        capsule: { type: liveViewManager.CapsuleType.CAPSULE_TYPE_TIMER, status: 1,
          content: target.startTime > Date.now() ? '距上课' : '上课中', time: duration, isCountdown: true,
          backgroundColor: '#FF315FC4' },
      },
    }
    if (captured !== revision || AppStorage.get<boolean>('liveViewEnabled') !== true) return { ok: false, reason: '实况窗已关闭' }
    const result = await liveViewManager.startLiveView(view)
    if (result.resultCode !== 0) {
      // Partial result may still leave a primary area: retain and stop it.
      currentView = view
      await stopCurrent()
      setReason('实况窗显示不完整（' + result.resultCode + '）')
      return { ok: false, reason: supportReason }
    }
    currentView = view; currentKey = key
    currentHandle = { id: String(view.id), startTime: target.startTime, targetType: target.type }
    if (captured !== revision || AppStorage.get<boolean>('liveViewEnabled') !== true) {
      await stopCurrent(); return { ok: false, reason: '实况窗已关闭' }
    }
    setReason('实况窗已显示')
    return { ok: true, handle: currentHandle }
  } catch (error) { setReason(reasonFor(error as BusinessError)); return { ok: false, reason: supportReason } }
}
export function startLiveView(target: LiveViewTarget): Promise<LiveViewResult> {
  const captured = revision
  const task = operation.then(() => startTarget(target, captured))
  operation = task.then(() => {}).catch((_e: Error) => {})
  return task
}
export function startCourseLiveView(course: Course, startTime: number, endTime: number): Promise<LiveViewResult> {
  return startLiveView(buildCourseLiveTarget(course, startTime, endTime))
}
export function startTodoLiveView(todo: TodoItem): Promise<LiveViewResult> {
  if (todo.done) return Promise.resolve<LiveViewResult>({ ok: false, reason: '任务已完成，无需启动实况窗' })
  return startLiveView(buildTodoLiveTarget(todo))
}
export async function updateLiveView(_handle: LiveViewHandle, course: Course, now: number): Promise<void> {
  const task = operation.then(async () => {
    if (currentView === null) return
    currentView.sequence = (currentView.sequence ?? 0) + 1
    currentView.liveViewData.primary.title = course.title.slice(0, 40)
    const result = await liveViewManager.updateLiveView(currentView)
    if (result.resultCode !== 0) setReason('实况窗更新失败（' + result.resultCode + '）')
  })
  operation = task.catch((_e: Error) => {})
  return task
}
export function finishLiveView(_handle: LiveViewHandle): Promise<void> { return finishAllLiveViews() }
export function finishAllLiveViews(): Promise<void> {
  revision++
  const task = operation.then(() => stopCurrent())
  operation = task.catch((_e: Error) => {})
  return task
}
export function getCurrentHandle(): LiveViewHandle | null { return currentHandle }
