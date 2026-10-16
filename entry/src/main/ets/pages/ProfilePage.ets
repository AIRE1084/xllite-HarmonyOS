import { DetailScaffold } from '../components/common/DetailScaffold'
import { PageState } from '../components/common/PageState'
import { RefreshNotice } from '../components/common/RefreshNotice'
import { CampusCard } from '../components/common/CampusCard'
import { getCacheEpoch } from '../services/MemoryCache'
import { getColors } from '../theme/Colors'
import { safeBack } from '../utils/RouterHelper'
import { callFeature, CallResult } from '../services/ApiService'
import { getUsername, getPassword } from '../services/AuthManager'
import { ProfileData } from '../models/JwTypes'
import { Motion, motionDuration } from '../theme/Motion'

@Entry
@Component
struct ProfilePage {
  @StorageLink('safeAreaTop') safeAreaTop: number = 0
  @StorageLink('safeAreaBottom') safeAreaBottom: number = 0
  @StorageLink('isDark') isDark: boolean = false
  @State studentId: string = ''
  @State name: string = ''
  @State gender: string = ''
  @State college: string = ''
  @State major: string = ''
  @State className: string = ''
  @State grade: string = ''
  private alive: boolean = false
  private requestVersion: number = 0
  @State loaded: boolean = false
  @State loading: boolean = false
  @State errorMsg: string = ''

  aboutToAppear(): void { this.alive = true; this.load() }
  aboutToDisappear(): void { this.alive = false; this.requestVersion++; this.loading = false }
  async load(force: boolean = false): Promise<void> {
    if (!this.alive || this.loading) return
    this.loading = true
    this.errorMsg = ''
    const version = ++this.requestVersion
    const epoch = getCacheEpoch()
    const username = getUsername()
    try {
      const res = await callFeature('jw.profile', username, getPassword(), { '_forceRefresh': force })
      if (!this.alive || version !== this.requestVersion || epoch !== getCacheEpoch() || username !== getUsername()) return
      if (res.ok) {
        const p: ProfileData = res.data as Object as ProfileData
        this.studentId = p.studentId || ''
        this.name = p.name || ''
        this.gender = p.gender || ''
        this.college = p.college || ''
        this.major = p.major || ''
        this.className = p.className || ''
        this.grade = p.grade || ''
        this.loaded = true
      } else { this.errorMsg = res.error || '个人信息暂时无法更新' }
    } catch (_error) {
      if (this.alive && version === this.requestVersion && epoch === getCacheEpoch() && username === getUsername()) this.errorMsg = '连接未完成，请稍后重试'
    } finally {
      if (this.alive && version === this.requestVersion) this.loading = false
    }
  }

  @Builder
  profileRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(14).fontColor(getColors(this.isDark).onSurfaceVariant).width(80)
      Text(value || '—').layoutWeight(1).fontColor(getColors(this.isDark).onSurface).fontSize(15).fontWeight(FontWeight.Medium)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
  }

  build() {
    Stack() {
      DetailScaffold({ title: '个人信息', subtitle: '你的学籍与校园身份', busy: this.loading,
        onBack: () => safeBack(this.getUIContext()), onAction: () => this.load(true) }) {
        if (!this.loaded && this.loading) {
          PageState({ kind: 'loading', title: '正在获取个人信息', message: '正在同步教务资料' })
        } else if (!this.loaded && this.errorMsg.length > 0) {
          PageState({ kind: 'error', schoolFeature: 'jw.profile', title: '个人信息暂未更新', message: this.errorMsg, action: '重新加载', onAction: () => this.load(true) })
        } else {
          if (this.errorMsg.length > 0) RefreshNotice({ message: '更新失败，已保留上次数据', busy: this.loading, onRetry: () => this.load(true) })
          Scroll() {
            Column() {
              CampusCard({ contentPadding: 20 }) {
                Column() {
                  this.profileRow('学号', this.studentId)
                  Divider().color(getColors(this.isDark).outline)
                  this.profileRow('姓名', this.name)
                  Divider().color(getColors(this.isDark).outline)
                  this.profileRow('性别', this.gender)
                  Divider().color(getColors(this.isDark).outline)
                  this.profileRow('学院', this.college)
                  Divider().color(getColors(this.isDark).outline)
                  this.profileRow('专业', this.major)
                  Divider().color(getColors(this.isDark).outline)
                  this.profileRow('班级', this.className)
                  Divider().color(getColors(this.isDark).outline)
                  this.profileRow('年级', this.grade)
                }.width('100%')
              }
            }.width('100%').padding({ left: 20, right: 20, top: 12, bottom: 28 })
          }.layoutWeight(1).width('100%').align(Alignment.Top).scrollBar(BarState.Off)
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
