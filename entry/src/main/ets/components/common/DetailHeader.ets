import { getColors } from '../../theme/Colors'
import { Typography } from '../../theme/Typography'

@Component
export struct DetailHeader {
  @StorageLink('safeAreaTop') safeAreaTop: number = 0
  @StorageLink('isDark') isDark: boolean = false
  @Prop title: string = ''
  @Prop subtitle: string = ''
  @Prop action: string = ''
  @Prop actionGlyph: string = ''
  @Prop busy: boolean = false
  @Prop showBack: boolean = true
  onBack: () => void = () => {}
  onAction: () => void = () => {}
  build() {
    Column({ space: 16 }) {
      Row({ space: 12 }) {
        if (this.showBack) {
          Button({ type: ButtonType.Circle }) {
            Text('‹').fontSize(26).fontWeight(FontWeight.Medium)
              .fontColor(getColors(this.isDark).onSurface).offset({ y: -1 })
          }
          .width(36).height(36).backgroundColor(getColors(this.isDark).surface)
          .accessibilityText('返回上一页').onClick(() => this.onBack())
        }
        Blank()
        if (this.action.length > 0) {
          Button({ type: ButtonType.Circle }) {
            if (this.actionGlyph.length > 0) {
              Text(this.actionGlyph).fontSize(22).fontWeight(FontWeight.Medium)
                .fontColor(getColors(this.isDark).primary).offset({ y: -1 })
            } else if (this.busy) {
              LoadingProgress().width(20).height(20).color(getColors(this.isDark).primary)
            } else {
              Progress({ value: 78, total: 100, type: ProgressType.Ring })
                .width(20).height(20).color(getColors(this.isDark).primary)
                .style({ strokeWidth: 2.4 })
            }
          }
          .width(40).height(40).backgroundColor(getColors(this.isDark).primaryContainer)
          .enabled(!this.busy).accessibilityText(this.busy ? '正在更新' : this.action)
          .onClick(() => this.onAction())
        }
      }.width('100%')
      Column({ space: 6 }) {
        Text(this.title).fontSize(Typography.headline.fontSize).fontWeight(FontWeight.Bold)
          .fontColor(getColors(this.isDark).onSurface).width('100%')
        if (this.subtitle.length > 0) {
          Text(this.subtitle).fontSize(Typography.bodySm.fontSize)
            .fontColor(getColors(this.isDark).onSurfaceVariant).width('100%')
        }
      }.width('100%').alignItems(HorizontalAlign.Start)
    }.width('100%').padding({ left: 20, right: 20, top: this.safeAreaTop + 12, bottom: 20 })
  }
}
