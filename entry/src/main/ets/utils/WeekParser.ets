/**
 * 周次字符串解析
 * 支持格式:
 *   "1-16周"        → 第 1-16 周全上
 *   "1-8,10-16周"   → 第 1-8 + 10-16 周
 *   "1-16周单"      → 第 1-16 周单周
 *   "1-16周双"      → 第 1-16 周双周
 *   "1,3,5"         → 第 1, 3, 5 周
 * 解析失败回退"全周"
 */
export function parseWeeks(weeks: string, totalWeeks: number = 20): boolean[] {
  const result: boolean[] = new Array<boolean>(totalWeeks).fill(false)
  if (!weeks || weeks.length === 0) {
    return result.fill(true)
  }

  try {
    // 去掉"周"字
    let body = weeks.replace(/[周\s\[\]（）()]/g, '').replace(/[，、]/g, ',').replace(/[–—~至]/g, '-').trim()
    // 单/双周
    let singleOdd = false
    let singleEven = false
    if (body.endsWith('单')) {
      singleOdd = true
      body = body.slice(0, -1)
    } else if (body.endsWith('双')) {
      singleEven = true
      body = body.slice(0, -1)
    }
    // 拆分逗号
    const parts = body.split(',')
    for (const part of parts) {
      const trimmed = part.trim()
      if (trimmed.length === 0) continue
      if (trimmed.indexOf('-') >= 0) {
        const ab = trimmed.split('-')
        const a = parseInt(ab[0], 10)
        const b = parseInt(ab[1], 10)
        if (isNaN(a) || isNaN(b)) continue
        const lo = Math.max(1, Math.min(a, b))
        const hi = Math.min(totalWeeks, Math.max(a, b))
        for (let i = lo; i <= hi; i++) {
          if (i >= 1 && i <= totalWeeks) {
            if (singleOdd && i % 2 === 0) continue
            if (singleEven && i % 2 === 1) continue
            result[i - 1] = true
          }
        }
      } else {
        const n = parseInt(trimmed, 10)
        if (isNaN(n)) continue
        if (n >= 1 && n <= totalWeeks) {
          if (singleOdd && n % 2 === 0) continue
          if (singleEven && n % 2 === 1) continue
          result[n - 1] = true
        }
      }
    }
    return result
  } catch {
    return result
  }
}

/**
 * 课程是否在指定周次有课
 */
export function isCourseInWeek(weeks: string, week: number, totalWeeks: number = 20): boolean {
  if (week < 1 || week > totalWeeks) return false
  const mask = parseWeeks(weeks, totalWeeks)
  return mask[week - 1] === true
}
