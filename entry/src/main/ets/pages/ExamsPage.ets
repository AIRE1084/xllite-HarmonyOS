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
import { Exam } from '../models/JwTypes'
import { ListDataSource } from '../utils/ListDataSource'

@Entry
@Component
struct ExamsPage {
  @StorageLink('isDark') isDark: boolean = false
  @State exams: Exam[] = []
  private readonly rows: ListDataSource<Exam> = new ListDataSource<Exam>()

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
      const res = await callFeature('jw.exams', username, getPassword(), { '_forceRefresh': force })
      if (!this.alive || version !== this.requestVersion || epoch !== getCacheEpoch() || username !== getUsername()) return
      if (res.ok) {
        const data = res.data['exams'] as Exam[]
        this.exams = Array.isArray(data) ? data : []
        this.rows.replace(this.exams)
        this.loaded = true
      } else { this.errorMsg = res.error || '暂时无法更新，请稍后重试' }
    } catch (_error) {
      if (this.alive && version === this.requestVersion && epoch === getCacheEpoch() && username === getUsername()) this.errorMsg = '连接未完成，请稍后重试'
    } finally {
      if (this.alive && version === this.requestVersion) this.loading = false
    }
  }
  @Builder
  ExamLine(label: string, value: string) {
    Row({ space: 12 }) {
      Text(label).fontSize(Typography.bodySm.fontSize).fontColor(getColors(this.isDark).onSurfaceVariant).width(44)
      Text(value || '待公布').fontSize(Typography.body.fontSize).fontColor(getColors(this.isDark).onSurface).layoutWeight(1)
    }.width('100%').alignItems(VerticalAlign.Top)
  }

  build() {
    Stack() {
    DetailScaffold({ title: '考试安排', subtitle: '提前确认时间与考场，从容赴考', busy: this.loading,
      onBack: () => safeBack(this.getUIContext()), onAction: () => this.load(true) }) {
      if (!this.loaded && this.loading) {
        PageState({ kind: 'loading', title: '正在获取考试安排', message: '马上就好，请稍候' })
      } else if (!this.loaded && this.errorMsg.length > 0) {
        PageState({ kind: 'error', schoolFeature: 'jw.exams', title: '考试安排暂未更新', message: this.errorMsg,
          action: '重新加载', onAction: () => this.load(true) })
      } else {
        if (this.errorMsg.length > 0) {
          RefreshNotice({ message: '更新失败，已保留上次数据', busy: this.loading, onRetry: () => this.load(true) })
        }
        if (this.exams.length === 0) {
          PageState({ title: '暂无考试安排', message: '暂时没有已公布的考试，记得留意教务通知', action: '刷新看看', onAction: () => this.load(true) })
        } else {
          List({ space: 14 }) {
            LazyForEach(this.rows, (e: Exam) => {
              ListItem() {
                CampusCard({ contentPadding: 20 }) {
                  Column({ space: 14 }) {
                    Text(e.courseName).fontSize(Typography.title.fontSize).fontWeight(FontWeight.Bold)
                      .fontColor(getColors(this.isDark).onSurface).width('100%')
                    Divider().color(getColors(this.isDark).outline)
                    this.ExamLine('时间', e.examTime)
                    this.ExamLine('考场', e.examPlace)
                    this.ExamLine('座位', e.seatNo)
                    this.ExamLine('教师', e.teacher)
                  }.width('100%').alignItems(HorizontalAlign.Start)
                }
              }
            }, (e: Exam, index: number): string => e.courseCode + '|' + e.examTime + '|' + index)
          }.layoutWeight(1).width('100%').padding({ left: 20, right: 20, bottom: 24 }).scrollBar(BarState.Off)
        }
      }
    }
    }.width('100%').height('100%')
  }
}
