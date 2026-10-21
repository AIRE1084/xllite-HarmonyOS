import { DetailHeader } from '../components/common/DetailHeader'
import { AddFormMenuItem } from '@ohos.arkui.advanced.FormMenu'
import { formBindingData, formInfo } from '@kit.FormKit'
import Want from '@ohos.app.ability.Want'
import { NativeGlass } from '../components/NativeGlass'
import { CampusCard } from '../components/common/CampusCard'
import { AmbientBackground } from '../components/AmbientBackground'
import { getColors, ColorPalette } from '../theme/Colors'
import { setCampusOption, calibrateCampusWeek, getCampusWidgetData, getCampusBundleName } from '../services/CampusCompanionService'
import { callFeature } from '../services/ApiService'
import { getUsername } from '../services/AuthManager'
import { CampusWidgetData } from '../models/CampusCompanionTypes'
import { safeBack } from '../utils/RouterHelper'
import { safeToast } from '../utils/ToastHelper'
import { Motion, motionDuration } from '../theme/Motion'

interface CampusSwitchRow {
  title: string
  subtitle: string
  enabled: boolean
  option: string
}
interface CampusStatusLine {
  status: string
}

@Entry
@Component
struct CampusSettingsPage {
  @StorageLink('isDark') @Watch('onThemeChange') isDark: boolean = false
  @StorageLink('safeAreaTop') safeAreaTop: number = 0
  @StorageLink('safeAreaBottom') safeAreaBottom: number = 0
  @StorageLink('campusWidgetEnabled') @Watch('refreshPreview') widgetEnabled: boolean = false
  @StorageLink('courseReminderEnabled') remindersEnabled: boolean = false
  @StorageLink('liveViewEnabled') liveEnabled: boolean = false
  @StorageLink('campusWidgetStatus') widgetStatus: string = '未开启'
  @StorageLink('courseReminderStatus') reminderStatus: string = '未开启'
  @StorageLink('liveViewStatus') liveStatus: string = '未开启'
  @StorageLink('scheduleWeekKnown') weekKnown: boolean = false
  @StorageLink('currentWeek') @Watch('updateWeekDraft') currentWeek: number = 1
  @StorageLink('totalWeeks') totalWeeks: number = 20
  @StorageLink('companionVersion') @Watch('refreshPreview') companionVersion: number = 0
  @StorageLink('campusInitError') initError: string = ''
  @State weekDraft: number = 1
  @State busy: boolean = false
  @State palette: ColorPalette = getColors(false)
  @State preview: CampusWidgetData = getCampusWidgetData()
  private readonly formWant: Want = {
    bundleName: 'com.xjit.app', abilityName: 'CampusFormAbility',
    parameters: { 'ohos.extra.param.key.form_name': 'CampusScheduleCard',
      'ohos.extra.param.key.form_dimension': formInfo.FormDimension.Dimension_2_2, 'ohos.extra.param.key.module_name': 'entry' },
  }
  aboutToAppear(): void {
    this.palette = getColors(this.isDark)
    this.weekDraft = this.currentWeek
    this.refreshPreview()
    this.formWant.bundleName = getCampusBundleName()
  }
  onThemeChange(): void { this.palette = getColors(this.isDark) }
  updateWeekDraft(): void { this.weekDraft = this.currentWeek; this.refreshPreview() }
  refreshPreview(): void { this.preview = getCampusWidgetData() }
  async change(option: string, enabled: boolean): Promise<void> {
    if (this.busy) return
    this.busy = true
    try { await setCampusOption(option, enabled); this.refreshPreview() }
    catch (error) { safeToast(this.getUIContext(), (error as Error).message || '设置未完成，请重试') }
    finally { this.busy = false }
  }
  async calibrate(): Promise<void> {
    if (this.busy) return
    this.busy = true
    try { await calibrateCampusWeek(this.weekDraft); safeToast(this.getUIContext(), '当前教学周已更新') }
    catch (error) { safeToast(this.getUIContext(), (error as Error).message) }
    finally { this.busy = false }
  }
  async syncSchedule(): Promise<void> {
    if (this.busy) return
    this.busy = true
    try {
      const result = await callFeature('jw.schedule', getUsername(), { '_forceRefresh': true })
      safeToast(this.getUIContext(), result.ok ? '课表已同步' : result.error)
      this.refreshPreview()
    } finally { this.busy = false }
  }
  @Builder
  SwitchRow($$: CampusSwitchRow) {
    Row({ space: 12 }) {
      Column({ space: 6 }) {
        Text($$.title).fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.palette.onSurface)
        Text($$.subtitle).fontSize(12).fontColor(this.palette.onSurfaceVariant)
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: $$.enabled }).selectedColor(this.palette.primary).enabled(!this.busy)
        .accessibilityText($$.title + ($$.enabled ? '，已开启' : '，已关闭'))
        .onChange((value: boolean) => { this.change($$.option, value) })
    }.width('100%')
  }
  @Builder
  AddCardMenu() {
    Menu() {
    AddFormMenuItem(this.formWant, 'campus-card-preview', {
      formBindingData: formBindingData.createFormBindingData(this.preview),
      style: { options: { content: '添加课表到桌面' } },
      callback: (error, formId: string) => {
        safeToast(this.getUIContext(), error === undefined || error.code === 0 ? '桌面卡片已添加' : '未添加桌面卡片，请在系统窗口确认')
      },
    })
    }
  }
  @Builder
  StatusLine($$: CampusStatusLine) {
    Row({ space: 7 }) {
      Row().width(5).height(5).borderRadius(2.5).backgroundColor($$.status.indexOf('失败') >= 0 ? this.palette.error : this.palette.primary)
      Text($$.status).fontSize(12).fontColor($$.status.indexOf('失败') >= 0 ? this.palette.error : this.palette.onSurfaceVariant)
        .layoutWeight(1)
    }.width('100%').margin({ top: 12 })
  }
  build() {
    Stack() {
      AmbientBackground()
      Column() {
        DetailHeader({ title: '桌面与提醒', subtitle: '把下一节课，放在随手可见的地方', action: '同步课表', busy: this.busy,
          onBack: () => safeBack(this.getUIContext()), onAction: () => this.syncSchedule() })
        Scroll() {
          Column({ space: 20 }) {
            if (this.initError.length > 0) {
              Text(this.initError).fontSize(13).fontColor(this.palette.error).width('100%')
                .padding(14).backgroundColor(this.palette.surfaceVariant).borderRadius(14)
            }
            CampusCard({ contentPadding: 18 }) {
              Column() {
                this.SwitchRow({ title: '桌面课表卡片', subtitle: '在桌面查看今天的下一节课', enabled: this.widgetEnabled, option: 'widget' })
                this.StatusLine({ status: this.widgetStatus })
              }.width('100%')
            }
            Column() {
              NativeGlass({ contentPadding: 20, radius: 24, prominent: true }) {
                Column({ space: 10 }) {
                  Row() {
                    Text(this.preview.heading).fontSize(12).fontColor(this.palette.onSurfaceVariant).layoutWeight(1)
                    Text(this.preview.status).fontSize(12).fontColor(this.palette.primary)
                  }.width('100%')
                  Text(this.preview.courseTitle).fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.palette.onSurface).width('100%')
                  Text(this.preview.courseTime + '  ' + this.preview.courseRoom).fontSize(14).fontColor(this.palette.onSurfaceVariant).width('100%')
                  Text(this.preview.following).fontSize(12).fontColor(this.palette.onSurfaceVariant).width('100%')
                }.width('100%')
              }
            }.width('100%').id('campus-card-preview')
            Button('添加课表到桌面').height(48).width('100%').fontColor(this.palette.onPrimary)
              .backgroundColor(this.palette.primary).borderRadius(16).enabled(this.widgetEnabled && !this.busy).bindMenu(this.AddCardMenu)
            CampusCard({ contentPadding: 18 }) {
              Column() {
                this.SwitchRow({ title: '课前 10 分钟提醒', subtitle: '登记未来 7 天内最近 24 条，由系统提醒；打开 APP 自动续订', enabled: this.remindersEnabled, option: 'reminders' })
                this.StatusLine({ status: this.reminderStatus })
              }.width('100%')
            }
            CampusCard({ contentPadding: 18 }) {
              Column() {
                this.SwitchRow({ title: '课程实况窗', subtitle: '课前 10 分钟内打开 APP，显示状态栏倒计时', enabled: this.liveEnabled, option: 'live' })
                this.StatusLine({ status: this.liveStatus })
              }.width('100%')
            }
            CampusCard({ contentPadding: 18 }) {
              Column({ space: 12 }) {
                Text('当前教学周').fontSize(17).fontWeight(FontWeight.Bold).fontColor(this.palette.onSurface)
                Text(this.weekKnown ? '当前为第 ' + this.currentWeek + ' 周，校准后每周自动递增' : '接口尚未提供当前周次，请按学校校历确认后开启课程提醒')
                  .fontSize(14).fontColor(this.palette.onSurfaceVariant)
                Row({ space: 12 }) {
                  Button('−').width(44).height(44).fontColor(this.palette.onSurface).backgroundColor(this.palette.surfaceVariant)
                    .enabled(!this.busy && this.weekDraft > 1).onClick(() => { this.weekDraft-- })
                  Text('第 ' + this.weekDraft + ' 周').layoutWeight(1).textAlign(TextAlign.Center).fontColor(this.palette.onSurface)
                  Button('+').width(44).height(44).fontColor(this.palette.onSurface).backgroundColor(this.palette.surfaceVariant)
                    .enabled(!this.busy && this.weekDraft < this.totalWeeks).onClick(() => { this.weekDraft++ })
                }.width('100%')
                Button('确认本周').height(48).width('100%').fontColor(this.palette.onPrimary).backgroundColor(this.palette.primary)
                  .enabled(!this.busy).onClick(() => this.calibrate())
              }.width('100%').alignItems(HorizontalAlign.Start)
            }
            Text('关闭桌面开关会隐藏课程；移除卡片请在桌面长按操作。').fontSize(12).fontColor(this.palette.onSurfaceVariant).width('100%')
          }.width('100%').padding({ left: 20, right: 20, top: 6, bottom: this.safeAreaBottom + 24 })
        }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
      }.width('100%').height('100%')
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
