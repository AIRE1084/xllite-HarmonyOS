/**
 * Ambient light field behind every glass surface.
 *
 * Glass only reads as glass when there is something to refract. A near-flat
 * gradient (the previous #E7EEFC -> #F5F7FC -> #EAF0FB) blurred into a void, so
 * cards looked like plain grey slabs. These soft indigo/cyan/violet blooms give
 * the material real colour to pull through while staying low enough contrast to
 * keep body text readable.
 */
@Component
export struct AmbientBackground {
  @StorageLink('isDark') isDark: boolean = false
  build() {
    Stack() {
      Column()
        .width('100%').height('100%')
        .linearGradient({ angle: 155,
          colors: this.isDark
            ? [['#13203A', 0], ['#0B1322', 0.5], ['#141E33', 1]]
            : [['#EEF3FC', 0], ['#F7F9FD', 0.5], ['#EDF1FB', 1]],
        })
      Column()
        .width('100%').height('100%')
        .radialGradient({ center: ['14%', '8%'], radius: '82%',
          colors: this.isDark
            ? [['#66315EDA', 0], ['#00315EDA', 1]]
            : [['#52315EDA', 0], ['#00315EDA', 1]],
        })
      Column()
        .width('100%').height('100%')
        .radialGradient({ center: ['94%', '24%'], radius: '70%',
          colors: this.isDark
            ? [['#5912B5C9', 0], ['#0012B5C9', 1]]
            : [['#4712B5C9', 0], ['#0012B5C9', 1]],
        })
      Column()
        .width('100%').height('100%')
        .radialGradient({ center: ['22%', '88%'], radius: '76%',
          colors: this.isDark
            ? [['#527B5CE6', 0], ['#007B5CE6', 1]]
            : [['#457B5CE6', 0], ['#007B5CE6', 1]],
        })
    }
    .width('100%').height('100%')
    .hitTestBehavior(HitTestMode.None)
    .accessibilityLevel('no')
  }
}
