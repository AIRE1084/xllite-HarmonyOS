import { DetailScaffold } from '../components/common/DetailScaffold'
import { PageState } from '../components/common/PageState'
import { RefreshNotice } from '../components/common/RefreshNotice'
import { CampusCard } from '../components/common/CampusCard'
import { getCacheEpoch } from '../services/MemoryCache'
import { ListDataSource } from '../utils/ListDataSource'
import { getColors } from '../theme/Colors'
import { safeBack } from '../utils/RouterHelper'
import { callFeature, CallResult } from '../services/ApiService'
import { getUsername, getPassword } from '../services/AuthManager'
import { Course } from '../models/JwTypes'

@Entry
@Component
struct SchedulePage {
  @StorageLink('safeAreaTop') safeAreaTop: number = 0
  @StorageLink('safeAreaBottom') safeAreaBottom: number = 0
  @StorageLink('isDark') isDark: boolean = false
  @State term: string = ''
  @State courses: Course[] = []
  private readonly rows: ListDataSource<Course> = new ListDataSource<Course>()
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
      const res = await callFeature('jw.schedule', username, getPassword(), { '_forceRefresh': force })
      if (!this.alive || version !== this.requestVersion || epoch !== getCacheEpoch() || username !== getUsername()) return
      if (res.ok) {
        this.term = typeof res.data['term'] === 'string' ? res.data['term'] as string : ''
        this.courses = Array.isArray(res.data['courses']) ? res.data['courses'] as Course[] : []
        this.rows.replace(this.courses)
        this.loaded = true
      } else { this.errorMsg = res.error || '课表暂时无法更新' }
    } catch (_error) {
      if (this.alive && version === this.requestVersion && epoch === getCacheEpoch() && username === getUsername()) this.errorMsg = '连接未完成，请稍后重试'
    } finally {
      if (this.alive && version === this.requestVersion) this.loading = false
    }
  }

  build() {
    Stack() {
      DetailScaffold({ title: '课表查询', subtitle: this.term || '本学期的课程安排', busy: this.loading,
        onBack: () => safeBack(this.getUIContext()), onAction: () => this.load(true) }) {
        if (!this.loaded && this.loading) {
          PageState({ kind: 'loading', title: '正在获取课程', message: '正在同步本学期课表' })
        } else if (!this.loaded && this.errorMsg.length > 0) {
          PageState({ kind: 'error', schoolFeature: 'jw.schedule', title: '课表暂未更新', message: this.errorMsg, action: '重新加载', onAction: () => this.load(true) })
        } else {
          if (this.errorMsg.length > 0) RefreshNotice({ message: '更新失败，已保留上次课表', busy: this.loading, onRetry: () => this.load(true) })
          if (this.courses.length === 0) {
            PageState({ title: '暂无课程安排', message: '新的课程会在这里显示', action: '刷新看看', onAction: () => this.load(true) })
          } else {
            List({ space: 12 }) {
              LazyForEach(this.rows, (course: Course) => {
                ListItem() {
                  CampusCard({ contentPadding: 18 }) {
                    Column({ space: 8 }) {
                      Text(course.day + ' · ' + course.slot + ' · ' + course.weeks).fontSize(12).fontColor(getColors(this.isDark).onSurfaceVariant)
                      Text(course.title).fontSize(17).fontWeight(FontWeight.Bold).fontColor(getColors(this.isDark).onSurface)
                      Text(course.teacher + ' · ' + course.location).fontSize(14).fontColor(getColors(this.isDark).onSurfaceVariant)
                    }.width('100%').alignItems(HorizontalAlign.Start)
                  }
                }
              }, (course: Course, index: number): string => course.day + '|' + course.slot + '|' + course.title + '|' + index)
            }.layoutWeight(1).width('100%').padding({ left: 20, right: 20, bottom: 24 }).scrollBar(BarState.Off)
          }
        }
      }
    }.width('100%').height('100%')
  }
}
