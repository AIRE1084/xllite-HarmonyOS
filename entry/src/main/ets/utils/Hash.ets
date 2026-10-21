/**
 * 稳定的字符串哈希。同一门课在日视图、周视图和周看板里必须落到同一个配色槽位，
 * 所以哈希算法只能有一份——此前 ScheduleGrid 与 WeekOverview 各写了一遍 31 乘法，
 * 且取模基数不同（5 与 4），同一门课在两个视图里颜色和序号都对不上。
 */
export function stableHash(text: string): number {
  let hash = 0
  for (let i = 0; i < text.length; i++) hash = (hash * 31 + text.charCodeAt(i)) | 0
  return Math.abs(hash)
}
