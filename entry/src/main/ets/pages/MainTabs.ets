import { activateCampusCompanion } from '../services/CampusCompanionService'
import { safePush } from '../utils/RouterHelper'
import { HomeTab } from './HomeTab'
import { ScheduleTab } from './ScheduleTab'
import { ProfileTab } from './ProfileTab'
import { BlurTabBar } from '../components/BlurTabBar'
import { AmbientBackground } from '../components/AmbientBackground'
import { getUsername } from '../services/AuthManager'
import { prewarmCampusData } from '../services/ApiService'
import { Motion, motionDuration } from '../theme/Motion'
import { ThemeWash } from '../components/common/ThemeWash'

@Entry
@Component
struct MainTabs {
  @StorageLink('campusRoute') @Watch('applyRequestedRoute') campusRoute: string = ''
  @State currentIndex: number = 0
  @State leavingTab: number = -1
  @State scheduleVisited: boolean = false
  @State profileVisited: boolean = false
  private leaveTimer: number = -1
  @StorageLink('isDark') isDark: boolean = false
  @StorageLink('safeAreaBottom') safeAreaBottom: number = 0
  @StorageLink('mainPageActive') mainPageActive: boolean = true
  @StorageLink('appActive') @Watch('onActivityChange') appActive: boolean = true
  private warmupStarted: boolean = false
  private alive: boolean = false
  private warmupTimer: number = -1
  aboutToAppear(): void { this.alive = true; activateCampusCompanion(getUsername()).catch((_e: Error) => {}); this.applyRequestedRoute(); this.onActivityChange() }
  onPageShow(): void { this.mainPageActive = true; this.applyRequestedRoute(); this.onActivityChange() }
  onPageHide(): void { this.mainPageActive = false; this.cancelWarmupTimer() }
  aboutToDisappear(): void {
    this.alive = false
    this.mainPageActive = false
    this.cancelWarmupTimer()
    this.clearLeaveTimer()
  }
  private clearLeaveTimer(): void {
    if (this.leaveTimer >= 0) clearTimeout(this.leaveTimer)
    this.leaveTimer = -1
  }
  private cancelWarmupTimer(): void {
    if (this.warmupTimer >= 0) clearTimeout(this.warmupTimer)
    this.warmupTimer = -1
  }
  onActivityChange(): void {
    this.cancelWarmupTimer()
    if (!this.alive || !this.mainPageActive || !this.appActive || this.warmupStarted) return
    this.warmupTimer = setTimeout(() => {
      this.warmupTimer = -1
      if (!this.alive || !this.mainPageActive || !this.appActive) return
      this.warmupStarted = true
      prewarmCampusData(getUsername()).catch((_e: Error) => {})
    }, 400)
  }
  applyRequestedRoute(): void {
    if (!this.alive || !this.mainPageActive) return
    const route = this.campusRoute
    if (route === 'schedule') { this.campusRoute = ''; this.selectTab(1) }
    else if (route === 'todo') { this.campusRoute = ''; safePush(this.getUIContext(), { url: 'pages/TodoPage' }) }
  }
  private selectTab(index: number): void {
    if (!Number.isInteger(index) || index < 0 || index > 2 || index === this.currentIndex) return
    const previous: number = this.currentIndex
    if (index === 1) this.scheduleVisited = true
    if (index === 2) this.profileVisited = true
    // Keep the outgoing instance briefly; opacity switches instantly to avoid text ghosting.
    this.clearLeaveTimer()
    const duration: number = motionDuration(Motion.duration.fast)
    this.leavingTab = duration > 0 ? previous : -1
    this.currentIndex = index
    if (duration === 0) return
    this.leaveTimer = setTimeout(() => {
      this.leaveTimer = -1
      if (this.leavingTab === previous && this.currentIndex !== previous) this.leavingTab = -1
    }, motionDuration(Motion.duration.fast))
  }
  private tabVisible(index: number): boolean {
    return this.currentIndex === index || this.leavingTab === index
  }
  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      AmbientBackground()
      HomeTab({ active: this.currentIndex === 0 })
        .visibility(this.tabVisible(0) ? Visibility.Visible : Visibility.Hidden)
        .opacity(this.currentIndex === 0 ? 1 : 0)
          .hitTestBehavior(this.currentIndex === 0 ? HitTestMode.Default : HitTestMode.None)

      if (this.scheduleVisited) {
        ScheduleTab({ active: this.currentIndex === 1 })
          .visibility(this.tabVisible(1) ? Visibility.Visible : Visibility.Hidden)
          .opacity(this.currentIndex === 1 ? 1 : 0)
          .hitTestBehavior(this.currentIndex === 1 ? HitTestMode.Default : HitTestMode.None)

      }
      if (this.profileVisited) {
        ProfileTab({ active: this.currentIndex === 2 })
          .visibility(this.tabVisible(2) ? Visibility.Visible : Visibility.Hidden)
          .opacity(this.currentIndex === 2 ? 1 : 0)
          .hitTestBehavior(this.currentIndex === 2 ? HitTestMode.Default : HitTestMode.None)

      }
      // A separate passive scrim protects dock labels when scrolling text moves underneath.
      // Keep custom backgrounds off the node that owns the native material.
      Column()
        .width('100%').height(this.safeAreaBottom + 88)
        .linearGradient({ angle: 180,
          colors: this.isDark
            ? [['#00152039', 0], ['#FF152039', 0.25], ['#FF152039', 1]]
            : [['#00EAF0FB', 0], ['#FFEAF0FB', 0.25], ['#FFEAF0FB', 1]],
        })
        .hitTestBehavior(HitTestMode.None)
      Column() {
        BlurTabBar({ currentIndex: this.currentIndex,
          onTabChange: (index: number) => { this.selectTab(index) } })
      }
      .width('100%')
      .padding({ left: 24, right: 24, bottom: Math.max(0, this.safeAreaBottom - 8) })
      ThemeWash()
    }
    .width('100%').height('100%')
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

