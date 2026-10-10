import { getColors } from '../../theme/Colors'
import { Typography } from '../../theme/Typography'

@Component
export struct CampusHeader {
  @StorageLink('safeAreaTop') safeAreaTop: number = 0
  @StorageLink('isDark') isDark: boolean = false
  @Prop title: string = ''
  @Prop subtitle: string = ''
  @Prop action: string = ''
  @Prop loading: boolean = false
  onAction: () => void = () => {}
  build() {
    Row({ space: 12 }) {
      Column({ space: 7 }) {
        if (this.subtitle.length > 0) {
          Text(this.subtitle).fontSize(Typography.bodySm.fontSize).fontColor(getColors(this.isDark).onSurfaceVariant)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        Text(this.title).fontSize(25).fontWeight(FontWeight.Bold)
          .fontColor(getColors(this.isDark).onSurface)
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      if (this.action.length > 0) {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 6 }) {
            if (this.loading) { LoadingProgress().width(16).height(16).color(getColors(this.isDark).primary) }
            Text(this.loading ? '更新中' : this.action).fontSize(Typography.label.fontSize).fontWeight(FontWeight.Medium)
              .fontColor(getColors(this.isDark).primary)
          }
        }.height(44).padding({ left: 14, right: 14 }).backgroundColor(getColors(this.isDark).primaryContainer)
          .borderRadius(16).enabled(!this.loading).onClick(() => this.onAction())
      }
    }.width('100%').padding({ left: 20, right: 20, top: this.safeAreaTop + 12, bottom: 16 })
  }
}
