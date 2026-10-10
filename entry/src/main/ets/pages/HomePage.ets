import { safePush, safeReplace } from '../utils/RouterHelper'
import { FEATURES, systemLabel } from '../utils/Constants'
import { FeatureDef } from '../models/Types'
import { getUsername, clearSession } from '../services/AuthManager'

@Entry
@Component
struct HomePage {
  @State username: string = ''

  aboutToAppear(): void {
    this.username = getUsername()
    if (this.username.length === 0) {
      safeReplace(this.getUIContext(), { url: 'pages/LoginPage' })
    }
  }

  openFeature(f: FeatureDef): void {
    safePush(this.getUIContext(), {
      url: 'pages/' + f.page,
      params: { 'feature': f.name, 'title': f.title } as Record<string, Object>,
    })
  }

  async handleLogout(): Promise<void> {
    await clearSession()
    safeReplace(this.getUIContext(), { url: 'pages/LoginPage' })
  }

  @Builder
  sectionHeader(sys: string) {
    Text(systemLabel(sys))
      .fontSize(16)
      .fontWeight(FontWeight.Medium)
      .width('100%')
      .padding({ left: 16, top: 20, bottom: 10 })
  }

  @Builder
  featureCard(item: FeatureDef) {
    Column() {
      Text(item.icon).fontSize(28)
      Text(item.title)
        .fontSize(11)
        .margin({ top: 6 })
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ top: 16, bottom: 16, left: 4, right: 4 })
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .onClick(() => { this.openFeature(item) })
  }

  build() {
    Column() {
      Row() {
        Text('掌上新理工')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
        Text(this.username)
          .fontSize(12)
          .fontColor('#999999')
          .margin({ left: 12 })
        Blank()
        Text('退出')
          .fontSize(13)
          .fontColor('#0078D4')
          .onClick(() => { this.handleLogout() })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 8 })

      Scroll() {
        Column() {
          this.sectionHeader('newcard')
          Grid() {
            ForEach(FEATURES.filter((f: FeatureDef): boolean => f.system === 'newcard'), (item: FeatureDef) => {
              GridItem() {
                this.featureCard(item)
              }
            }, (item: FeatureDef): string => item.name)
          }
          .columnsTemplate('1fr 1fr 1fr')
          .rowsGap(10)
          .columnsGap(10)
          .padding({ left: 16, right: 16 })
          .height(220)

          this.sectionHeader('jw')
          Grid() {
            ForEach(FEATURES.filter((f: FeatureDef): boolean => f.system === 'jw'), (item: FeatureDef) => {
              GridItem() {
                this.featureCard(item)
              }
            }, (item: FeatureDef): string => item.name)
          }
          .columnsTemplate('1fr 1fr 1fr')
          .rowsGap(10)
          .columnsGap(10)
          .padding({ left: 16, right: 16 })
          .height(220)
        }
        .padding({ bottom: 24 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F0F2F5')
  }
}
