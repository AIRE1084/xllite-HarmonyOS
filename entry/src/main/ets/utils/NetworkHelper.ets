
import connection from '@ohos.net.connection'
import { Logger } from './Logger'

const TAG = 'NetworkHelper'

/**
 * 网络状态工具
 * 纯添加，不影响现有功能
 */
export class NetworkHelper {
  private static isListening = false

  static async isNetworkAvailable(): Promise&lt;boolean&gt; {
    try {
      const netCapabilities = await connection.getDefaultNet()
      return netCapabilities !== null
    } catch (e) {
      Logger.warn(TAG, 'Check network failed', e)
      return false
    }
  }

  static async getNetworkType(): Promise&lt;string&gt; {
    try {
      const netCapabilities = await connection.getDefaultNet()
      if (netCapabilities) {
        const capabilities = await connection.getNetCapabilities(netCapabilities)
        if (capabilities.bearerTypes.includes(connection.NetBearType.BEARER_WIFI)) {
          return 'WiFi'
        }
        if (capabilities.bearerTypes.includes(connection.NetBearType.BEARER_CELLULAR)) {
          return 'Mobile'
        }
      }
      return 'Unknown'
    } catch (e) {
      Logger.warn(TAG, 'Get network type failed', e)
      return 'Unknown'
    }
  }
}

