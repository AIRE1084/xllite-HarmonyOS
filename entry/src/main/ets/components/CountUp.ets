/**
 * CountUp - 数字滚动组件(Q6=B 动效)
 *
 * 数字变化时,从旧值滚动到新值(easeOutCubic 缓动)
 * 典型用途:GPA / 余额 / 倒计时
 *
 * 用法:
 *   CountUp({ value: 2.25, fontSize: 32, color: palette.primary })
 */
@Component
export struct CountUp {
  @Prop @Watch('onValueChange') value: number = 0
  @Prop duration: number = 600
  @Prop fontSize: number = 28
  @Prop fontWeight: number = 700
  @Prop color: string = ''

  @State displayValue: number = 0
  private startValue: number = 0
  private startTime: number = 0
  private timerId: number = -1

  aboutToAppear(): void {
    this.startValue = this.value
    this.displayValue = this.value
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) clearInterval(this.timerId)
  }

  onValueChange(): void {
    this.startValue = this.displayValue
    this.startTime = Date.now()
    if (this.timerId >= 0) clearInterval(this.timerId)
    this.timerId = setInterval(() => this.tick(), 16)
  }

  private tick(): void {
    const elapsed: number = Date.now() - this.startTime
    if (elapsed >= this.duration) {
      this.displayValue = this.value
      if (this.timerId >= 0) clearInterval(this.timerId)
      this.timerId = -1
      return
    }
    const t: number = elapsed / this.duration
    const eased: number = 1 - Math.pow(1 - t, 3)  // easeOutCubic
    this.displayValue = this.startValue + (this.value - this.startValue) * eased
  }

  build() {
    Text(this.displayValue.toFixed(0))
      .fontSize(this.fontSize)
      .fontWeight(this.fontWeight)
      .fontColor(this.color)
  }
}
