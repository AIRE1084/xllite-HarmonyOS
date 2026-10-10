
import { Logger } from './Logger'

const TAG = 'PerformanceMonitor'

interface PerformanceMark {
  name: string
  startTime: number
  endTime?: number
}

/**
 * 性能监控工具
 * 纯添加，不影响现有功能
 */
export class PerformanceMonitor {
  private static marks: Map&lt;string, PerformanceMark&gt; = new Map()

  static start(name: string): void {
    this.marks.set(name, {
      name,
      startTime: Date.now()
    })
    Logger.debug(TAG, 'Start: %{public}s', name)
  }

  static end(name: string): number {
    const mark = this.marks.get(name)
    if (!mark) {
      Logger.warn(TAG, 'Mark not found: %{public}s', name)
      return 0
    }

    const duration = Date.now() - mark.startTime
    this.marks.delete(name)

    Logger.info(TAG, 'End: %{public}s, duration: %{public}dms', name, duration)

    if (duration &gt; 1000) {
      Logger.warn(TAG, 'Slow operation detected: %{public}s (%{public}dms)', name, duration)
    }

    return duration
  }

  static measure&lt;T&gt;(name: string, fn: () =&gt; T): T {
    this.start(name)
    try {
      return fn()
    } finally {
      this.end(name)
    }
  }

  static async measureAsync&lt;T&gt;(name: string, fn: () =&gt; Promise&lt;T&gt;): Promise&lt;T&gt; {
    this.start(name)
    try {
      return await fn()
    } finally {
      this.end(name)
    }
  }
}

