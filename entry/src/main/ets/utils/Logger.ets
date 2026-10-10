import hilog from '@ohos.hilog'

const DOMAIN: number = 0x0001
const APP_TAG: string = 'XJITApp'

/**
 * 应用日志工具类
 * 纯添加，不影响现有功能
 */
export class Logger {
  static debug(tag: string, message: string, ...args: Object[]): void {
    hilog.debug(DOMAIN, `${APP_TAG}[${tag}]`, message, args)
  }

  static info(tag: string, message: string, ...args: Object[]): void {
    hilog.info(DOMAIN, `${APP_TAG}[${tag}]`, message, args)
  }

  static warn(tag: string, message: string, ...args: Object[]): void {
    hilog.warn(DOMAIN, `${APP_TAG}[${tag}]`, message, args)
  }

  static error(tag: string, message: string, error?: Error, ...args: Object[]): void {
    hilog.error(DOMAIN, `${APP_TAG}[${tag}]`, message, args)
    if (error) {
      hilog.error(DOMAIN, `${APP_TAG}[${tag}]`, 'Error stack: %{public}s', [error.stack as string])
    }
  }
}