import { getUsername } from '../services/AuthManager'
import { getCacheEpoch } from '../services/MemoryCache'
import notificationManager from '@ohos.notificationManager'
import common from '@ohos.app.ability.common'
import { DetailScaffold } from '../components/common/DetailScaffold'
import { safeBack } from '../utils/RouterHelper'
import { safeToast } from '../utils/ToastHelper'
import { TodoItem } from '../models/TodoTypes'
import { addTodo, countOpenTodos, deleteTodo, loadTodos, toggleTodo, refreshTodoWidgets, registerTodoReminders, disableTodoReminders, getTodoReminderStatus, restoreTodoReminderStatus } from '../services/TodoService'
import { startTodoLiveView } from '../services/LiveViewService'
import { LiquidGlass } from '../components/LiquidGlass'
import { getColors, ColorPalette } from '../theme/Colors'
import { Radius } from '../theme/Radius'
import { Motion, motionDuration } from '../theme/Motion'

@Entry
@Component
struct TodoPage {
  @StorageLink('safeAreaTop') safeAreaTop: number = 0
  @StorageLink('safeAreaBottom') safeAreaBottom: number = 0
  @State todos: TodoItem[] = []
  @State titleInput: string = ''
  @State noteInput: string = ''
  @State dueInput: string = ''
  @State dueAt: number | undefined = undefined
  @State filter: number = 0
  @State reminderStatus: string = '尚未登记任务提醒'
  @StorageLink('isDark') @Watch('onThemeChange') isDark: boolean = false
  @State palette: ColorPalette = getColors(false)

  private alive: boolean = false
  private loadVersion: number = 0
  aboutToDisappear(): void { this.alive = false; this.loadVersion++ }
  async aboutToAppear(): Promise<void> {
    this.alive = true
    this.saving = false
    this.reminderBusy = false
    const version = ++this.loadVersion
    const epoch = getCacheEpoch()
    const username = getUsername()
    this.palette = getColors(this.isDark)
    const items = await loadTodos()
    if (!this.alive || version !== this.loadVersion || epoch !== getCacheEpoch() || username !== getUsername()) return
    this.todos = items
    await restoreTodoReminderStatus()
    if (!this.alive || version !== this.loadVersion || epoch !== getCacheEpoch() || username !== getUsername()) return
    this.reminderStatus = getTodoReminderStatus()
    try { await refreshTodoWidgets() }
    catch (_error) {
      if (this.alive && version === this.loadVersion && epoch === getCacheEpoch() && username === getUsername()) {
        safeToast(this.getUIContext(), '任务已读取，桌面卡片暂未刷新')
      }
    }
  }

  onThemeChange(): void {
    this.palette = getColors(this.isDark)
  }

  private visibleTodos(): TodoItem[] {
    if (this.filter === 1) {
      return this.todos.filter((item: TodoItem): boolean => !item.done)
    }
    if (this.filter === 2) {
      return this.todos.filter((item: TodoItem): boolean => item.done)
    }
    return this.todos
  }

  selectDueTime(date: Date, hour: number, minute: number): void {
    if (!Number.isFinite(date.getTime()) || !Number.isInteger(hour) || !Number.isInteger(minute) || hour < 0 || hour > 23 || minute < 0 || minute > 59) return
    const value = new Date(date.getFullYear(), date.getMonth(), date.getDate(), hour, minute).getTime()
    if (value <= Date.now()) { safeToast(this.getUIContext(), '请选择未来时间'); return }
    this.dueAt = value
    this.dueInput = date.getFullYear() + '-' + (date.getMonth() + 1) + '-' + date.getDate() + ' ' + hour.toString().padStart(2, '0') + ':' + minute.toString().padStart(2, '0')
  }
  clearDueTime(): void { this.dueAt = undefined; this.dueInput = '' }
  chooseDueTime(): void {
    const selected = this.dueAt === undefined ? new Date() : new Date(this.dueAt)
    this.getUIContext().showDatePickerDialog({ selected: selected,
      onAccept: (result: DatePickerResult) => {
        if (result.year === undefined || result.month === undefined || result.day === undefined) return
        const date = new Date(result.year, result.month, result.day)
        this.getUIContext().showTimePickerDialog({ selected: selected, useMilitaryTime: true,
          onAccept: (time: TimePickerResult) => {
            if (time.hour !== undefined && time.minute !== undefined) this.selectDueTime(date, time.hour, time.minute)
          } })
      } })
  }
  @State saving: boolean = false
  private async handleAdd(): Promise<void> {
    if (this.saving) return
    if (this.dueAt !== undefined && this.dueAt <= Date.now()) {
      safeToast(this.getUIContext(), '任务时间已过，请重新选择'); return
    }
    if (this.titleInput.trim().length === 0) {
      safeToast(this.getUIContext(), '先写下要做什么')
      return
    }
    this.saving = true
    const version = this.loadVersion
    const epoch = getCacheEpoch()
    const username = getUsername()
    try {
      const items = await addTodo({
        title: this.titleInput,
        note: this.noteInput,
        dueText: this.dueInput,
        dueAt: this.dueAt,
      })
      if (!this.alive || version !== this.loadVersion || epoch !== getCacheEpoch() || username !== getUsername()) return
      this.todos = items
      this.titleInput = ''
      this.noteInput = ''
      this.clearDueTime()
    } catch (_error) {
      if (this.alive && version === this.loadVersion && epoch === getCacheEpoch() && username === getUsername()) {
        safeToast(this.getUIContext(), '任务保存未完成，请重试')
      }
    } finally {
      if (this.alive && version === this.loadVersion && epoch === getCacheEpoch() && username === getUsername()) {
        this.saving = false; this.reminderStatus = getTodoReminderStatus()
      }
    }
  }

  private isCurrentOperation(version: number, epoch: number, username: string): boolean {
    return this.alive && version === this.loadVersion && epoch === getCacheEpoch() && username === getUsername()
  }
  private async handleToggle(item: TodoItem): Promise<void> {
    await this.updateTask(item, false)
  }

  private async handleDelete(item: TodoItem): Promise<void> {
    await this.updateTask(item, true)
  }
  private async updateTask(item: TodoItem, deleting: boolean): Promise<void> {
    const version = this.loadVersion
    const epoch = getCacheEpoch()
    const username = getUsername()
    try {
      const items = deleting ? await deleteTodo(item.id) : await toggleTodo(item.id)
      if (this.isCurrentOperation(version, epoch, username)) this.todos = items
    } catch (_error) {
      if (this.isCurrentOperation(version, epoch, username)) {
        safeToast(this.getUIContext(), deleting ? '任务删除未完成，请重试' : '任务状态未保存，请重试')
      }
    } finally {
      if (this.isCurrentOperation(version, epoch, username)) this.reminderStatus = getTodoReminderStatus()
    }
  }

  @State reminderBusy: boolean = false
  async handleDisableReminders(): Promise<void> {
    if (this.reminderBusy) return
    this.reminderBusy = true
    const version = this.loadVersion
    const epoch = getCacheEpoch()
    const username = getUsername()
    try {
      await disableTodoReminders()
      if (this.isCurrentOperation(version, epoch, username)) safeToast(this.getUIContext(), '已取消任务提醒，任务仍保留')
    } catch (_error) {
      if (this.isCurrentOperation(version, epoch, username)) safeToast(this.getUIContext(), '自动同步已关闭，系统提醒取消未完成，请重试')
    } finally {
      if (this.isCurrentOperation(version, epoch, username)) { this.reminderBusy = false; this.reminderStatus = getTodoReminderStatus() }
    }
  }
  async handleReminders(): Promise<void> {
    if (this.reminderBusy) return
    this.reminderBusy = true
    const version = this.loadVersion
    const epoch = getCacheEpoch()
    const username = getUsername()
    try {
      const enabled = await notificationManager.isNotificationEnabled()
      if (!this.isCurrentOperation(version, epoch, username)) return
      if (!enabled) {
        await notificationManager.requestEnableNotification(this.getUIContext().getHostContext() as common.UIAbilityContext)
        if (!this.isCurrentOperation(version, epoch, username)) return
      }
      const count = await registerTodoReminders()
      if (this.isCurrentOperation(version, epoch, username)) safeToast(this.getUIContext(), '已登记 ' + count + ' 条任务提醒；本次会话内随任务变更同步')
    } catch (_error) {
      if (this.isCurrentOperation(version, epoch, username)) safeToast(this.getUIContext(), '任务保留，提醒登记未完成，请检查通知设置后重试')
    } finally {
      if (this.isCurrentOperation(version, epoch, username)) { this.reminderBusy = false; this.reminderStatus = getTodoReminderStatus() }
    }
  }
  private async handleLiveView(item: TodoItem): Promise<void> {
    const version = this.loadVersion
    const epoch = getCacheEpoch()
    const username = getUsername()
    try {
      const result = await startTodoLiveView(item)
      if (this.isCurrentOperation(version, epoch, username)) {
        safeToast(this.getUIContext(), result.ok ? '系统实况窗已更新' : (result.reason !== undefined ? result.reason : '当前不可用'))
      }
    } catch (_error) {
      if (this.isCurrentOperation(version, epoch, username)) safeToast(this.getUIContext(), '实况窗更新未完成，请稍后重试')
    }
  }

  @Builder
  BackButton() {
    Text('返回')
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.palette.primary)
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .backgroundColor(this.palette.primaryContainer)
      .borderRadius(Radius.sm)
      .onClick(() => { safeBack(this.getUIContext()) })
  }

  @Builder
  FilterChip(label: string, value: number) {
    Text(label)
      .fontSize(12)
      .fontWeight(this.filter === value ? FontWeight.Bold : FontWeight.Regular)
      .fontColor(this.filter === value ? this.palette.onPrimary : this.palette.onSurfaceVariant)
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .height(34)
      .backgroundColor(this.filter === value ? this.palette.primary : 'rgba(0,0,0,0)')
      .borderRadius(Radius.sm)
      .onClick(() => { this.filter = value })
  }

  @Builder
  StatusDot(done: boolean) {
    Text(done ? '✓' : '')
      .fontSize(15)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.palette.onPrimary)
      .textAlign(TextAlign.Center)
      .width(28)
      .height(28)
      .backgroundColor(done ? this.palette.success : this.palette.surfaceVariant)
      .borderRadius(14)
      .border({
        width: done ? 0 : 1,
        color: this.palette.outline,
      })
  }

  @Builder
  TodoRow(item: TodoItem) {
    Column() {
      LiquidGlass({ contentPadding: 14, radius: 18, glassBlur: 42 }) {
        Row() {
          Column() {
            this.StatusDot(item.done)
          }
          .onClick(() => { this.handleToggle(item) })

        Column() {
          Text(item.title)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(item.done ? this.palette.onSurfaceVariant : this.palette.onSurface)
            .decoration({ type: item.done ? TextDecorationType.LineThrough : TextDecorationType.None })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (item.note.length > 0 || item.dueText.length > 0) {
            Text((item.dueText.length > 0 ? item.dueText : '待安排') + (item.note.length > 0 ? ' · ' + item.note : ''))
              .fontSize(12)
              .fontColor(this.palette.onSurfaceVariant)
              .margin({ top: 5 })
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 12, right: 10 })
        .onClick(() => { this.handleToggle(item) })

        Text('窗')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.palette.primary)
          .width(32)
          .height(32)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.palette.primaryContainer)
          .borderRadius(16)
          .onClick(() => { this.handleLiveView(item) })

        Text('删')
          .fontSize(12)
          .fontColor(this.palette.error)
          .width(32)
          .height(32)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.isDark ? 'rgba(248,113,113,0.12)' : 'rgba(239,68,68,0.10)')
          .borderRadius(16)
          .margin({ left: 8 })
          .onClick(() => { this.handleDelete(item) })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
    }
    .margin({ left: 16, right: 16, top: 10 })
  }

  build() {
    Stack() {
      DetailScaffold({ title: '待办任务', subtitle: countOpenTodos(this.todos).toString() + ' 项待完成 · 安排好今天的每一件事', action: '',
        onBack: () => safeBack(this.getUIContext()) }) {
      Scroll() {
        Column() {
          Column() {
            LiquidGlass({ contentPadding: 16, radius: 22, glassBlur: 54 }) {
              Column() {
              TextInput({ placeholder: '新增待办', text: this.titleInput })
                .fontColor(this.palette.onSurface).placeholderColor(this.palette.onSurfaceVariant)
                .caretColor(this.palette.primary)
                .height(42)
                .fontSize(15)
                .backgroundColor(this.palette.surfaceVariant)
                .borderRadius(Radius.sm)
                .onChange((value: string) => { this.titleInput = value })

              Row({ space: 8 }) {
                Button(this.dueInput.length > 0 ? this.dueInput : '选择任务时间')
                  .fontColor(this.palette.onSurfaceVariant).layoutWeight(1).height(38).fontSize(12)
                  .backgroundColor(this.palette.surfaceVariant).borderRadius(Radius.sm)
                  .onClick(() => this.chooseDueTime())
                if (this.dueAt !== undefined) {
                  Button('清除').fontSize(12).backgroundColor(Color.Transparent)
                    .fontColor(this.palette.onSurfaceVariant).onClick(() => this.clearDueTime())
                }
                TextInput({ placeholder: '备注', text: this.noteInput })
                  .fontColor(this.palette.onSurface).placeholderColor(this.palette.onSurfaceVariant)
                  .caretColor(this.palette.primary)
                  .layoutWeight(1)
                  .height(38)
                  .fontSize(13)
                  .backgroundColor(this.palette.surfaceVariant)
                  .borderRadius(Radius.sm)
                  .onChange((value: string) => { this.noteInput = value })
              }
              .width('100%')
              .margin({ top: 10 })

              Text('添加')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.palette.onPrimary)
                .textAlign(TextAlign.Center)
                .width('100%')
                .height(42)
                .backgroundColor(this.palette.primary)
                .borderRadius(Radius.md)
                .margin({ top: 12 })
                .onClick(() => { this.handleAdd() })
              }
              .width('100%')
            }
          }
          .margin({ left: 16, right: 16, top: 4 })

          Button(this.reminderBusy ? '登记中…' : '登记任务提醒').enabled(!this.reminderBusy)
            .fontSize(13).fontColor(this.palette.primary).backgroundColor(this.palette.primaryContainer)
            .margin({ left: 16, right: 16, top: 12 }).onClick(() => this.handleReminders())
          Text(this.reminderStatus).fontSize(12).fontColor(this.palette.onSurfaceVariant)
            .margin({ left: 16, right: 16, top: 8 })
          Button('取消任务提醒').enabled(!this.reminderBusy).fontSize(12)
            .fontColor(this.palette.onSurfaceVariant).backgroundColor(Color.Transparent)
            .onClick(() => this.handleDisableReminders())
          Row() {
            this.FilterChip('全部', 0)
            this.FilterChip('未完成', 1)
            this.FilterChip('已完成', 2)
          }
          .height(42)
          .padding(4)
          .margin({ left: 16, right: 16, top: 14 })
          .backgroundColor(this.palette.surfaceVariant)
          .borderRadius(Radius.md)

          if (this.visibleTodos().length === 0) {
            Column() {
              LiquidGlass({ contentPadding: 20, radius: 22, glassBlur: 42 }) {
                Column() {
                  Text('这里很干净')
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.palette.onSurface)
                  Text('把课程作业、社团事项和生活提醒放在这里。')
                    .fontSize(12)
                    .fontColor(this.palette.onSurfaceVariant)
                    .margin({ top: 8 })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }
            }
            .margin({ left: 16, right: 16, top: 16 })
          } else {
            ForEach(this.visibleTodos(), (item: TodoItem) => {
              this.TodoRow(item)
            }, (item: TodoItem): string => item.id)
          }
        }
        .width('100%')
        .padding({ bottom: 28 })
      }
      .layoutWeight(1).align(Alignment.TopStart)

      }
    }.width('100%').height('100%')
  }

  // 统一页面过渡：前进时新页右侧 30% 淡入、底层静止；返回时镜像右出淡出。
  // 减少动效偏好下时长为 0（同时禁用设备默认页面动画，保持瞬时切换）。
  pageTransition(): void {
    PageTransitionEnter({ type: RouteType.Push, duration: motionDuration(Motion.duration.base), curve: Motion.curve.decelerate })
      .translate({ x: motionDuration(Motion.duration.base) > 0 ? '30%' : '0%' }).opacity(motionDuration(Motion.duration.base) > 0 ? 0 : 1)
    PageTransitionExit({ type: RouteType.Push, duration: motionDuration(Motion.duration.base) })
    PageTransitionEnter({ type: RouteType.Pop, duration: motionDuration(Motion.duration.base) })
    PageTransitionExit({ type: RouteType.Pop, duration: motionDuration(Motion.duration.base), curve: Motion.curve.accelerate })
      .translate({ x: motionDuration(Motion.duration.base) > 0 ? '30%' : '0%' }).opacity(motionDuration(Motion.duration.base) > 0 ? 0 : 1)
  }

}
