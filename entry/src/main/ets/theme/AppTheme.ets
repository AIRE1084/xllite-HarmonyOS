
/**
 * 应用主题常量
 * 纯添加，不影响现有功能
 * 新代码可以使用，旧代码继续使用原来的方式
 */
export class AppTheme {
  static readonly colors = {
    primary: '#0078D4',
    primaryDark: '#005A9E',
    danger: '#E84040',
    success: '#52C41A',
    warning: '#FAAD14',
    background: '#F0F2F5',
    card: '#FFFFFF',
    textPrimary: '#333333',
    textSecondary: '#999999',
    textTertiary: '#CCCCCC'
  } as const

  static readonly spacing = {
    xs: 4,
    sm: 8,
    md: 16,
    lg: 24,
    xl: 32
  } as const

  static readonly radius = {
    sm: 4,
    md: 8,
    lg: 12
  } as const

  static readonly fontSize = {
    xs: 11,
    sm: 12,
    md: 14,
    lg: 16,
    xl: 20,
    xxl: 28
  } as const

  static readonly duration = {
    short: 200,
    medium: 300,
    long: 500
  } as const
}

