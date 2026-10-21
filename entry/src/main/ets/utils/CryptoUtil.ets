import cryptoFramework from '@ohos.security.cryptoFramework'
import util from '@ohos.util'

// Public wire-format key from the school's current NewCapec web client.
// This decrypts card response envelopes; it is not a credential or a TLS substitute.
export async function decryptSchoolCardEnvelope(encoded: string): Promise<string> {
  try {
    const keyBytes = new util.TextEncoder().encodeInto('w687-9+3C_H&je_5')
    const generator = cryptoFramework.createSymKeyGenerator('SM4_128')
    const key = await generator.convertKey({ data: keyBytes })
    const cipher = cryptoFramework.createCipher('SM4_128|ECB|PKCS7')
    await cipher.init(cryptoFramework.CryptoMode.DECRYPT_MODE, key, null)
    const output = await cipher.doFinal({ data: new util.Base64Helper().decodeSync(encoded) })
    return new util.TextDecoder('utf-8', { fatal: true }).decodeToString(output.data)
  } catch (error) {
    // Device crypto providers fail with opaque codes; name the failing stage for the caller.
    throw new Error('一卡通响应解密失败：' + (error as Error).message)
  }
}
