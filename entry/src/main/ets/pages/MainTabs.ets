import { activateCampusCompanion } from '../services/CampusCompanionService'
import { safePush } from '../utils/RouterHelper'
import { HomeTab } from './HomeTab'
import { ScheduleTab } from './ScheduleTab'
import { ProfileTab } from './ProfileTab'
import { BlurTabBar } from '../components/BlurTabBar'
import { AmbientBackground } from '../components/AmbientBackground'
import { getUsername, getPassword } from '../services/AuthManager'
import { prewarmCampusData } from '../services/ApiService'

@Entry
@Component
struct MainTabs {
  @StorageLink('campusRoute') @Watch('applyRequestedRoute') campusRoute: string = ''
  @State currentIndex: number = 0
  @State scheduleVisited: boolean = false
  @State profileVisited: boolean = false
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
      prewarmCampusData(getUsername(), getPassword()).catch((_e: Error) => {})
    }, 400)
  }
  applyRequestedRoute(): void {
    if (!this.alive || !this.mainPageActive) return
    const route = this.campusRoute
    if (route === 'schedule') { this.campusRoute = ''; this.selectTab(1) }
    else if (route === 'todo') { this.campusRoute = ''; safePush(this.getUIContext(), { url: 'pages/TodoPage' }) }
  }
  private selectTab(index: number): void {
    if (index === 1) this.scheduleVisited = true
    if (index === 2) this.profileVisited = true
    this.currentIndex = index
  }
  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      AmbientBackground()
      HomeTab({ active: this.currentIndex === 0 })
        .visibility(this.currentIndex === 0 ? Visibility.Visible : Visibility.Hidden)
      if (this.scheduleVisited) {
        ScheduleTab({ active: this.currentIndex === 1 })
          .visibility(this.currentIndex === 1 ? Visibility.Visible : Visibility.Hidden)
      }
      if (this.profileVisited) {
        ProfileTab({ active: this.currentIndex === 2 })
          .visibility(this.currentIndex === 2 ? Visibility.Visible : Visibility.Hidden)
      }
      // A separate passive scrim protects dock labels when scrolling text moves underneath.
      // Keep custom backgrounds off the node that owns the native material.
      Column()
        .width('100%').height(this.safeAreaBottom + 88)
        .linearGradient({ angle: 180,
          colors: this.isDark
            ? [['#00152039', 0], ['#40152039', 0.45], ['#B8152039', 1]]
            : [['#00EAF0FB', 0], ['#40EAF0FB', 0.45], ['#B8EAF0FB', 1]],
        })
        .hitTestBehavior(HitTestMode.None)
      Column() {
        BlurTabBar({ currentIndex: this.currentIndex,
          onTabChange: (index: number) => { this.selectTab(index) } })
      }
      .width('100%')
      .padding({ left: 24, right: 24, bottom: this.safeAreaBottom + 10 })
    }
    .width('100%').height('100%')
  }
}

