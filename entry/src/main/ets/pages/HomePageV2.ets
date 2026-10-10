
import { safePush, safeReplace } from '../utils/RouterHelper'
import { FEATURES, systemLabel } from '../utils/Constants'
import { FeatureDef } from '../models/Types'
import { getUsername, clearSession } from '../services/AuthManager'
import { AppCard } from '../components/common/AppCard'
import { AppTheme } from '../theme/AppTheme'
import { Logger } from '../utils/Logger'

const TAG = 'HomePageV2'

@Entry
@Component
struct HomePageV2 {
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
      params: { 'feature': f.name, 'title': f.title } as Record&lt;string, Object&gt;,
    })
  }

  async handleLogout(): Promise&lt;void&gt; {
    await clearSession()
    safeReplace(this.getUIContext(), { url: 'pages/LoginPage' })
  }

  @Builder
  sectionHeader(sys: string) {
    Text(systemLabel(sys))
      .fontSize(AppTheme.fontSize.lg)
      .fontWeight(FontWeight.Medium)
      .width('100%')
      .padding({ left: 16, top: 20, bottom: 10 })
  }

  @Builder
  featureCard(item: FeatureDef) {
    AppCard({
      onClick: () => this.openFeature(item),
      padding: { top: 16, bottom: 16, left: 4, right: 4 }
    }) {
      Column() {
        Text(item.icon).fontSize(28)
        Text(item.title)
          .fontSize(AppTheme.fontSize.xs)
          .margin({ top: 6 })
          .textAlign(TextAlign.Center)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
    }
  }

  build() {
    Column() {
      // 顶部信息栏
      AppCard({
        padding: { left: 16, right: 16, top: 16, bottom: 16 }
      }) {
        Row() {
          Column() {
            Text('掌上新理工')
              .fontSize(AppTheme.fontSize.xl)
              .fontWeight(FontWeight.Bold)
            Text(this.username)
              .fontSize(AppTheme.fontSize.sm)
              .fontColor(AppTheme.colors.textSecondary)
              .margin({ top: 4 })
          }
          .flexGrow(1)

          AppButton({
            text: '退出',
            type: 'text',
            onButtonClick: () => this.handleLogout()
          })
          .width(80)
        }
      }

      // 滚动内容
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

          this.sectionHeader('local')
          Grid() {
            ForEach(FEATURES.filter((f: FeatureDef): boolean => f.system === 'local'), (item: FeatureDef) => {
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
    .backgroundColor(AppTheme.colors.background)
  }
}

