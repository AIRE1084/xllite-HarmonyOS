/**
 * 排版系统 - 字号 / 字重
 */
export interface TypeStyle {
  fontSize: number
  fontWeight: number
  letterSpacing?: number
  lineHeight?: number
}

export interface TypeScale {
  display: TypeStyle
  displayMd: TypeStyle
  headline: TypeStyle
  title: TypeStyle
  subtitle: TypeStyle
  body: TypeStyle
  bodyLg: TypeStyle
  bodySm: TypeStyle
  caption: TypeStyle
  label: TypeStyle
  mono: TypeStyle
}

export const Typography: TypeScale = {
  display:    { fontSize: 40, fontWeight: 700 } as TypeStyle,  // 大数字/展示
  displayMd:  { fontSize: 32, fontWeight: 700 } as TypeStyle,  // 倒计时
  headline:   { fontSize: 24, fontWeight: 700 } as TypeStyle,  // 页内大标题
  title:      { fontSize: 20, fontWeight: 600 } as TypeStyle,  // 卡片标题
  subtitle:   { fontSize: 17, fontWeight: 600 } as TypeStyle,  // 节标题
  body:       { fontSize: 15, fontWeight: 400 } as TypeStyle,  // 正文
  bodyLg:     { fontSize: 16, fontWeight: 400 } as TypeStyle,  // 较大正文
  bodySm:     { fontSize: 13, fontWeight: 400 } as TypeStyle,  // 较小正文
  caption:    { fontSize: 12, fontWeight: 400 } as TypeStyle,  // 辅助
  label:      { fontSize: 13, fontWeight: 600 } as TypeStyle,  // 标签
  mono:       { fontSize: 14, fontWeight: 500 } as TypeStyle,  // 等宽(数字)
}
