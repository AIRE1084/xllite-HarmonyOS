/**
 * 间距系统 - 4 / 8 整数倍
 */
export interface SpacingType {
  xxs: number
  xs: number
  sm: number
  md: number
  lg: number
  xl: number
  xxl: number
  xxxl: number
  huge: number
}
export const Spacing: SpacingType = {
  xxs:  2,
  xs:   4,
  sm:   8,
  md:   12,
  lg:   16,
  xl:   20,
  xxl:  24,
  xxxl: 32,
  huge: 48,
}

export interface InsetsType {
  screen: number
  card: number
  section: number
  tab: number
  pageTop: number
}
export const Insets: InsetsType = {
  screen:  16,
  card:    16,
  section: 24,
  tab:     8,
  pageTop: 60,
}
