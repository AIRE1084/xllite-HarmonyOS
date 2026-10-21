/**
 * Live View 实时窗 - 数据类型
 */
export interface LiveViewContent {
  title: string
  text: string
  additionalText?: string
}

export interface LiveViewHandle {
  id: string
  startTime: number   // Unix timestamp in milliseconds
  targetType?: string
}

export interface LiveViewResult {
  ok: boolean
  handle?: LiveViewHandle
  reason?: string
}

export interface LiveViewTarget {
  todoId?: string
  type: string
  title: string
  text: string
  extra: string
  startTime: number
  endTime: number
}

/**
 * 构造 Live View 卡片内容
 */
export function buildLiveViewContent(
  courseTitle: string,
  teacher: string,
  location: string,
  remainMinutes: number,
): LiveViewContent {
  return {
    title: courseTitle,
    text: remainMinutes > 0 ? `${remainMinutes} 分钟后` : '已开课',
    additionalText: `${teacher} · ${location}`,
  }
}
