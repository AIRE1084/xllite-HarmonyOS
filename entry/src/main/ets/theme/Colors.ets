/**
 * 主题色板 - 浅色 + 深色双套(Q5=A 跟随系统)
 *
 * 优先级:
 *   1. theme/Colors.ets (代码色板 - 浅深双套 + 玻璃色)
 *   2. resources/base/element/color.json (系统色 - 启动窗背景等)
 *
 * 浅深色由 isDark 决定,组件用 @StorageLink('isDark') 监听。
 */
export interface ColorPalette {
  // 基础层
  background: string
  surface: string
  surfaceVariant: string
  onSurface: string
  onSurfaceVariant: string
  outline: string

  // 品牌
  primary: string
  onPrimary: string
  primaryContainer: string
  onPrimaryContainer: string

  accent: string
  onAccent: string
  accentContainer: string
  onAccentContainer: string

  // 语义
  success: string
  warning: string
  error: string
  info: string

  // 玻璃(LiquidGlass / GlassCard / LiquidGlassPro 专用)
  glassBase: string         // 玻璃底层背景 rgba
  glassBaseStrong: string   // 玻璃高密度背景 rgba
  glassBorder: string       // 玻璃描边
  glassHighlight: string    // 玻璃高光
  glassShadow: string       // 玻璃阴影
  glassSpecular: string     // iOS26 顶部高光条中心色
  glassRimTop: string       // iOS26 玻璃描边顶部色
  glassRimBottom: string    // iOS26 玻璃描边底部色

  // 课程类型(课表卡片色块,5 种)
  courseColors: string[]
}

export const LightColors: ColorPalette = {
  background: '#EEF3FA',
  surface: '#FFFFFF',
  surfaceVariant: '#EFF3FA',
  onSurface: '#171A21',
  onSurfaceVariant: '#526176',
  outline: '#E5E7EB',

  primary: '#315EDA',
  onPrimary: '#FFFFFF',
  primaryContainer: '#E5EDFF',
  onPrimaryContainer: '#244BB4',

  accent: '#007570',
  onAccent: '#FFFFFF',
  accentContainer: '#D8F5F4',
  onAccentContainer: '#005754',

  success: '#18794E',
  warning: '#F59E0B',
  error: '#BA2A3B',
  info: '#3B82F6',

  glassBase: 'rgba(255,255,255,0.55)',
  glassBaseStrong: 'rgba(255,255,255,0.78)',
  glassBorder: 'rgba(255,255,255,0.6)',
  glassHighlight: 'rgba(255,255,255,0.92)',
  glassShadow: 'rgba(15, 23, 42, 0.10)',
  // iOS 26 Liquid Glass 额外色 (LiquidGlassPro 使用)
  glassSpecular: 'rgba(255,255,255,1)',         // 顶部高光条中心色
  glassRimTop: 'rgba(255,255,255,0.95)',         // 描边顶部
  glassRimBottom: 'rgba(15, 23, 42, 0.10)',     // 描边底部 (柔和暗边)

  courseColors: ['#315EDA', '#007570', '#A55F05', '#BE286E', '#7443D6'],
}

export const DarkColors: ColorPalette = {
  background: '#0B1322',
  surface: '#142033',
  surfaceVariant: '#1E2D43',
  onSurface: '#F1F5FB',
  onSurfaceVariant: '#B3C0D3',
  outline: '#33455C',

  primary: '#9FB6FF',
  onPrimary: '#0B0E14',
  primaryContainer: '#1D2E52',
  onPrimaryContainer: '#C5D2FA',

  accent: '#4FD1CE',
  onAccent: '#0B0E14',
  accentContainer: '#0F3D3C',
  onAccentContainer: '#B8F0EE',

  success: '#34D399',
  warning: '#FBBF24',
  error: '#F87171',
  info: '#60A5FA',

  glassBase: 'rgba(22,26,35,0.55)',
  glassBaseStrong: 'rgba(22,26,35,0.72)',
  glassBorder: 'rgba(255,255,255,0.14)',
  glassHighlight: 'rgba(255,255,255,0.22)',
  glassShadow: 'rgba(0, 0, 0, 0.45)',
  glassSpecular: 'rgba(255,255,255,0.6)',
  glassRimTop: 'rgba(255,255,255,0.25)',
  glassRimBottom: 'rgba(0, 0, 0, 0.25)',

  courseColors: ['#7B95F0', '#4FD1CE', '#FBBF24', '#F472B6', '#A78BFA'],
}

export function getColors(isDark: boolean): ColorPalette {
  return isDark ? DarkColors : LightColors
}
