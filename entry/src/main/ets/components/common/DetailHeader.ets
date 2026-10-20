import { getColors } from '../../theme/Colors'
import { Typography } from '../../theme/Typography'

@Component
export struct DetailHeader {
  @StorageLink('safeAreaTop') safeAreaTop: number = 0
  @StorageLink('isDark') isDark: boolean = false
  @Prop title: string = ''
  @Prop subtitle: string = ''
  @Prop action: string = ''
  @Prop busy: boolean = false
  @Prop showBack: boolean = true
  onBack: () => void = () => {}
  onAction: () => void = () => {}
  build() {
    Column({ space: 16 }) {
      Row() {
        if (this.showBack) {
          Button('‹ 返回').height(44).padding({ left: 14, right: 14 }).fontSize(Typography.label.fontSize)
            .fontColor(getColors(this.isDark).onSurface).backgroundColor(getColors(this.isDark).surface)
            .borderRadius(16).accessibilityText('返回上一页').onClick(() => this.onBack())
        }
        Blank()
        if (this.action.length > 0) {
          Button(this.busy ? '更新中' : this.action).height(44).padding({ left: 16, right: 16 })
            .fontSize(Typography.label.fontSize).fontColor(getColors(this.isDark).primary)
            .backgroundColor(getColors(this.isDark).primaryContainer).borderRadius(16)
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
