import { DetailScaffold } from '../components/common/DetailScaffold'
import { safeBack } from '../utils/RouterHelper'
import { safeToast } from '../utils/ToastHelper'
import { TodoItem } from '../models/TodoTypes'
import { addTodo, countOpenTodos, deleteTodo, loadTodos, toggleTodo } from '../services/TodoService'
import { startTodoLiveView } from '../services/LiveViewService'
import { LiquidGlass } from '../components/LiquidGlass'
import { getColors, ColorPalette } from '../theme/Colors'
import { Radius } from '../theme/Radius'

@Entry
@Component
struct TodoPage {
  @StorageLink('safeAreaTop') safeAreaTop: number = 0
  @StorageLink('safeAreaBottom') safeAreaBottom: number = 0
  @State todos: TodoItem[] = []
  @State titleInput: string = ''
  @State noteInput: string = ''
  @State dueInput: string = ''
  @State filter: number = 0
  @StorageLink('isDark') @Watch('onThemeChange') isDark: boolean = false
  @State palette: ColorPalette = getColors(false)

  async aboutToAppear(): Promise<void> {
    this.palette = getColors(this.isDark)
    this.todos = await loadTodos()
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

  private async handleAdd(): Promise<void> {
    if (this.titleInput.trim().length === 0) {
      safeToast(this.getUIContext(), '先写下要做什么')
      return
    }
    this.todos = await addTodo({
      title: this.titleInput,
      note: this.noteInput,
      dueText: this.dueInput,
    })
    this.titleInput = ''
    this.noteInput = ''
    this.dueInput = ''
  }

  private async handleToggle(item: TodoItem): Promise<void> {
    this.todos = await toggleTodo(item.id)
  }

  private async handleDelete(item: TodoItem): Promise<void> {
    this.todos = await deleteTodo(item.id)
  }

  private async handleLiveView(item: TodoItem): Promise<void> {
    const result = await startTodoLiveView(item)
    safeToast(this.getUIContext(), result.ok ? '系统实况窗已更新' : (result.reason !== undefined ? result.reason : '当前不可用'))
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
                TextInput({ placeholder: '时间', text: this.dueInput })
                  .fontColor(this.palette.onSurface).placeholderColor(this.palette.onSurfaceVariant)
                  .caretColor(this.palette.primary)
                  .layoutWeight(1)
                  .height(38)
                  .fontSize(13)
                  .backgroundColor(this.palette.surfaceVariant)
                  .borderRadius(Radius.sm)
                  .onChange((value: string) => { this.dueInput = value })
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
}
