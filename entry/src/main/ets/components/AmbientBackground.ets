@Component
export struct AmbientBackground {
  @StorageLink('isDark') isDark: boolean = false
  build() {
    Column()
      .width('100%').height('100%')
      .linearGradient({ angle: 155,
        colors: this.isDark
          ? [['#182B4C', 0], ['#101A2C', 0.46], ['#152039', 1]]
          : [['#E7EEFC', 0], ['#F5F7FC', 0.46], ['#EAF0FB', 1]],
      })
      .hitTestBehavior(HitTestMode.None)
      .accessibilityLevel('no')
  }
}
