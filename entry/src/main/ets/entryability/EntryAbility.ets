import UIAbility from '@ohos.app.ability.UIAbility'
import { Configuration as AbilityConfiguration } from '@ohos.app.ability.Configuration'
import ConfigurationConstant from '@ohos.app.ability.ConfigurationConstant'
import resourceManager from '@ohos.resourceManager'
import window from '@ohos.window'
import { KeyboardAvoidMode } from '@ohos.arkui.UIContext'
import hilog from '@ohos.hilog'
import Want from '@ohos.app.ability.Want'
import { initCampusCompanion, setCompanionForeground } from '../services/CampusCompanionService'
import { setAuthContext } from '../services/AuthManager'
import { setTodoContext } from '../services/TodoService'
import { flushCachedValues } from '../services/MemoryCache'
import { initTheme, updateSystemTheme, observeTheme, setNativeThemeReady } from '../services/ThemeService'
const TAG: string = 'EntryAbility'
export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | null = null
  private avoidListener: ((options: window.AvoidAreaOptions) => void) | null = null
  onCreate(want: Want): void {
    this.onNewWant(want)
    initCampusCompanion(this.context, want?.bundleName ?? '').catch((_e: Error) => {})
    setAuthContext(this.context)
    setTodoContext(this.context)
    AppStorage.setOrCreate<number>('currentWeek', 1)
    AppStorage.setOrCreate<number>('totalWeeks', 20)
    AppStorage.setOrCreate<number>('safeAreaTop', 0)
    AppStorage.setOrCreate<number>('safeAreaBottom', 0)
    AppStorage.setOrCreate<boolean>('appActive', true)
    AppStorage.setOrCreate<boolean>('mainPageActive', true)
    updateSystemTheme(this.context.resourceManager.getConfigurationSync().colorMode === resourceManager.ColorMode.DARK)
    initTheme(this.context).catch((_e: Error) => {})
  }
  onNewWant(want: Want): void {
    const route = String(want?.parameters?.['campusRoute'] ?? '')
    if (route === 'schedule' || route === 'todo') AppStorage.setOrCreate<string>('campusRoute', route)
  }
  onConfigurationUpdate(config: AbilityConfiguration): void {
    if (config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ||
      config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT) {
      updateSystemTheme(config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK)
    }
  }
  private updateBars(isDark: boolean): void {
    if (this.mainWindow === null) return
    this.mainWindow.setWindowSystemBarProperties({
      statusBarColor: '#00000000', navigationBarColor: '#00000000',
      statusBarContentColor: isDark ? '#FFFFFFFF' : '#FF171A21',
      navigationBarContentColor: isDark ? '#FFFFFFFF' : '#FF171A21',
    }).catch((_e: Error) => {})
  }
  private updateSafeArea(): void {
    if (this.mainWindow === null) return
    try {
    const system = this.mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
    const navigation = this.mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
    const cutout = this.mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT)
    const ui = this.mainWindow.getUIContext()
    AppStorage.setOrCreate<number>('safeAreaTop', ui.px2vp(Math.max(system.topRect.height, cutout.topRect.height)))
    AppStorage.setOrCreate<number>('safeAreaBottom', ui.px2vp(Math.max(system.bottomRect.height, navigation.bottomRect.height)))
    } catch (_e) { hilog.warn(0, TAG, 'Safe area update failed') }
  }
  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.getMainWindow().then(async (mainWindow: window.Window) => {
      this.mainWindow = mainWindow
      await mainWindow.setWindowLayoutFullScreen(true)
      // 显式固定为 RESIZE：键盘弹出时缩短页面交给 Scroll 处理，而不是整页 OFFSET 上移把底部按钮推出可视区。
      mainWindow.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE)
      this.updateSafeArea()
      this.avoidListener = (_options: window.AvoidAreaOptions) => { this.updateSafeArea() }
      mainWindow.on('avoidAreaChange', this.avoidListener)
      observeTheme((isDark: boolean) => { this.updateBars(isDark) })
      this.updateBars(AppStorage.get<boolean>('isDark') ?? false)
    }).catch((_e: Error) => { hilog.warn(0, TAG, 'Window setup failed') })
    windowStage.loadContent('pages/LoginPage', (err) => {
      if (err.code) hilog.error(0, TAG, 'loadContent failed')
      else setNativeThemeReady(true)
    })
  }
  onWindowStageDestroy(): void {
    setNativeThemeReady(false)
    // 窗口可能已先于本回调销毁，此时 off() 抛 1300002 "window is not created or destroyed"，需兜底。
    try {
      if (this.mainWindow !== null && this.avoidListener !== null) this.mainWindow.off('avoidAreaChange', this.avoidListener)
    } catch (_e) {
      hilog.warn(0, TAG, 'Avoid area detach skipped')
    }
    observeTheme(null)
    this.mainWindow = null
    this.avoidListener = null
  }
  onForeground(): void {
    AppStorage.setOrCreate<boolean>('appActive', true)
    setCompanionForeground(true)
    updateSystemTheme(this.context.resourceManager.getConfigurationSync().colorMode === resourceManager.ColorMode.DARK)
  }
  onBackground(): void {
    AppStorage.setOrCreate<boolean>('appActive', false)
    setCompanionForeground(false)
    flushCachedValues().catch((_e: Error) => {})
  }
}
