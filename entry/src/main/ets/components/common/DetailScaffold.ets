import { AmbientBackground } from '../AmbientBackground'
import { DetailHeader } from './DetailHeader'
import { ThemeWash } from './ThemeWash'

@Component
export struct DetailScaffold {
  @StorageLink('safeAreaBottom') safeAreaBottom: number = 0
  @Prop title: string = ''
  @Prop subtitle: string = ''
  @Prop action: string = '刷新'
  @Prop busy: boolean = false
  onBack: () => void = () => {}
  onAction: () => void = () => {}
  @BuilderParam content: () => void
  build() {
    Stack() {
      AmbientBackground()
      Column() {
        DetailHeader({ title: this.title, subtitle: this.subtitle, action: this.action, busy: this.busy,
          onBack: () => this.onBack(), onAction: () => this.onAction() })
        this.content()
      }.width('100%').height('100%').padding({ bottom: this.safeAreaBottom })
      ThemeWash()
    }.width('100%').height('100%')
  }
}
