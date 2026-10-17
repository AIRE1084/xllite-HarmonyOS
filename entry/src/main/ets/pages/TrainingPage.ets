import { getColors } from '../theme/Colors'
import { Typography } from '../theme/Typography'
import { safeBack } from '../utils/RouterHelper'
import { callFeature } from '../services/ApiService'
import { getUsername, getPassword } from '../services/AuthManager'
import { getCacheEpoch } from '../services/MemoryCache'
import { DetailScaffold } from '../components/common/DetailScaffold'
import { PageState } from '../components/common/PageState'
import { RefreshNotice } from '../components/common/RefreshNotice'
import { CampusCard } from '../components/common/CampusCard'
import { TrainingItem } from '../models/JwTypes'
import { ListDataSource } from '../utils/ListDataSource'
import { Motion, motionDuration } from '../theme/Motion'

@Entry
@Component
struct TrainingPage {
  @StorageLink('isDark') isDark: boolean = false
  @State items: TrainingItem[] = []
  private readonly rows: ListDataSource<TrainingItem> = new ListDataSource<TrainingItem>()

  @State loading: boolean = false
  @State loaded: boolean = false
  @State errorMsg: string = ''
  private alive: boolean = false
  private requestVersion: number = 0
  aboutToAppear(): void { this.alive = true; this.load() }
  aboutToDisappear(): void { this.alive = false; this.requestVersion++; this.loading = false }
  async load(force: boolean = false): Promise<void> {
    if (this.loading || !this.alive) return
    this.loading = true
    this.errorMsg = ''
    const version = ++this.requestVersion
    const epoch = getCacheEpoch()
    const username = getUsername()
    try {
      const res = await callFeature('jw.training', username, getPassword(), { '_forceRefresh': force })
      if (!this.alive || version !== this.requestVersion || epoch !== getCacheEpoch() || username !== getUsername()) return
      if (res.ok) {
        const data = res.data['training'] as TrainingItem[]
        this.items = Array.isArray(data) ? data : []
        this.rows.replace(this.items)
        this.loaded = true
      } else { this.errorMsg = res.error || '暂时无法更新，请稍后重试' }
    } catch (_error) {
      if (this.alive && version === this.requestVersion && epoch === getCacheEpoch() && username === getUsername()) this.errorMsg = '连接未完成，请稍后重试'
    } finally {
      if (this.alive && version === this.requestVersion) this.loading = false
    }
  }
  @Builder
  TrainingLine(label: string, value: string) {
    Column({ space: 7 }) {
      Text(label).fontSize(Typography.caption.fontSize).fontColor(getColors(this.isDark).onSurfaceVariant)
      Text(value).fontSize(Typography.bodyLg.fontSize).fontWeight(FontWeight.Medium).fontColor(getColors(this.isDark).onSurface)
    }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 12, bottom: 12 })
  }

  build() {
    Stack() {
    DetailScaffold({ title: '毕业完成情况', subtitle: '学业与毕业信息，一处查看', busy: this.loading,
      onBack: () => safeBack(this.getUIContext()), onAction: () => this.load(true) }) {
      if (!this.loaded && this.loading) {
        PageState({ kind: 'loading', title: '正在获取毕业完成情况', message: '马上就好，请稍候' })
      } else if (!this.loaded && this.errorMsg.length > 0) {
        PageState({ kind: 'error', schoolFeature: 'jw.training', title: '毕业完成情况暂未更新', message: this.errorMsg,
          action: '重新加载', onAction: () => this.load(true) })
      } else {
        if (this.errorMsg.length > 0) {
          RefreshNotice({ message: '更新失败，已保留上次数据', busy: this.loading, onRetry: () => this.load(true) })
        }
        if (this.items.length === 0) {
          PageState({ title: '暂无毕业完成情况', message: '教务系统尚未提供可显示的信息', action: '刷新看看', onAction: () => this.load(true) })
        } else {
          List({ space: 14 }) {
            LazyForEach(this.rows, (item: TrainingItem) => {
              ListItem() {
                CampusCard({ contentPadding: 20 }) {
                  this.TrainingLine('毕业届别', item.graduationYear || '待公布')
                  Divider().color(getColors(this.isDark).outline)
                  this.TrainingLine('毕业类型', item.graduationType || '待公布')
                  Divider().color(getColors(this.isDark).outline)
                  this.TrainingLine('毕业结论', item.graduationConclusion || '待公布')
                  Divider().color(getColors(this.isDark).outline)
                  this.TrainingLine('毕业时间', item.graduationTime || '未毕业')
                  Divider().color(getColors(this.isDark).outline)
                  this.TrainingLine('证书编号', item.certificateNo || '尚未发放')
                }
              }
            }, (item: TrainingItem, index: number): string => item.graduationYear + '|' + item.certificateNo + '|' + index)
          }.layoutWeight(1).width('100%').padding({ left: 20, right: 20, bottom: 24 }).scrollBar(BarState.Off)
        }
      }
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
