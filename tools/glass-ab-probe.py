"""
A/B measurement harness for the HarmonyOS 6.0 glass fallback.

For each variant it patches the simulator staging copy of NativeGlass.ets,
builds, signs, installs, launches, screenshots and samples the pixels.

Only the staging copy is touched; the repository source is never modified.
Usage: python tools/glass-ab-probe.py <variant> <adaptiveColor> <saturation>
"""

from pathlib import Path
import re
import shutil
import subprocess
import sys
import json

REPO = Path(r"D:\整理_\01_项目代码\jiji\XJITApp")
STAGE = Path(r"D:\XJITApp-glass-ab")
TOOLCHAIN = Path(r"D:\data\devecostudionext\DevEco Studio\sdk\default\openharmony\toolchains")
DEVEco = Path(r"D:\data\devecostudionext\DevEco Studio")
JAVA = DEVEco / "jbr" / "bin" / "java.exe"
NODE = DEVEco / "tools" / "node" / "node.exe"
HVIGOR = DEVEco / "tools" / "hvigor" / "hvigor" / "bin" / "hvigor.js"
SIGNER = TOOLCHAIN / "lib" / "hap-sign-tool.jar"
KEYSTORE = TOOLCHAIN / "lib" / "OpenHarmony.p12"
SIGN_LIB = TOOLCHAIN / "lib"
HDC = TOOLCHAIN / "hdc.exe"
TARGET = "127.0.0.1:5555"
UDID = "454D55057494E058383602A8BB012601348119E1B6CC49F48475800000000000"


def run(cmd, cwd=None, env=None):
    p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, errors="replace", env=env)
    return p.returncode, p.stdout + p.stderr


def sync_stage():
    """Refresh the staging copy from the repository so each run starts clean."""
    for name in ("entry/src", "AppScope", "hvigor"):
        src = REPO / name
        dst = STAGE / name
        if dst.exists():
            shutil.rmtree(dst)
        shutil.copytree(src, dst)
    for f in ("build-profile.json5", "oh-package.json5", "hvigorfile.ts", "package.json",
              "local.properties"):
        shutil.copy2(REPO / f, STAGE / f)
    for f in ("build-profile.json5", "hvigorfile.ts", "oh-package.json5"):
        shutil.copy2(REPO / "entry" / f, STAGE / "entry" / f)
    # Go straight to the home tab: the glass card renders without a signed-in
    # account, and this probe is about pixels, not about the login flow.
    ea = STAGE / "entry/src/main/ets/entryability/EntryAbility.ets"
    src = ea.read_text(encoding="utf-8")
    if "loadContent('pages/LoginPage'" in src:
        src = src.replace("loadContent('pages/LoginPage'", "loadContent('pages/MainTabs'")
        ea.write_text(src, encoding="utf-8")


def force_fallback():
    """Force the API 23-25 fallback path on an API 26 device.

    The simulator runs API 26, so the normal gate would take the native
    systemMaterial path. `backgroundEffect` itself is @since 11 and renders
    identically on API 23, so forcing the gate exercises exactly the code the
    HarmonyOS 6.0 device would run. Only the staging copy is changed.
    """
    path = STAGE / "entry/src/main/ets/theme/Materials.ets"
    src = path.read_text(encoding="utf-8")
    patched = re.sub(r"api < 26", "api < 99", src)
    if patched == src:
        raise SystemExit("fallback gate anchor missing")
    path.write_text(patched, encoding="utf-8")


def patch_glass(adaptive: str, saturation: str):
    """Rewrite the fallback parameters in the staging copy only."""
    path = STAGE / "entry/src/main/ets/components/NativeGlass.ets"
    src = path.read_text(encoding="utf-8")
    src = re.sub(r"adaptiveColor: AdaptiveColor\.\w+", f"adaptiveColor: AdaptiveColor.{adaptive}", src)
    src = re.sub(r"(?s)(saturation: this\.prominent\s*\?\s*\(this\.isDark \? )[\d.]+( : )[\d.]+(\))",
                 rf"\g<1>{saturation} : {saturation}\g<3>", src)
    path.write_text(src, encoding="utf-8")
    return src


def build():
    env = dict(**__import__("os").environ)
    env["DEVECO_SDK_HOME"] = str(DEVEco / "sdk").replace("\\", "/")
    env["JAVA_HOME"] = str(DEVEco / "jbr").replace("\\", "/")
    build_record = json.loads((REPO / ".wolf/build-api26-inputs.json").read_text(encoding="utf-8"))
    env["NODE_PATH"] = build_record["nodeModulesPath"]
    code, out = run([str(NODE), str(HVIGOR), "--mode", "module", "-p", "product=default",
                     "-p", "module=entry@default", "-p", "buildMode=debug", "assembleHap",
                     "--no-daemon", "--no-parallel"], cwd=str(STAGE), env=env)
    hap = STAGE / "entry/build/default/outputs/default/entry-default-unsigned.hap"
    return code, out, (hap if hap.exists() else None)


def sign(hap: Path, out_path: Path):
    sign_root = STAGE / "signing"
    sign_root.mkdir(parents=True, exist_ok=True)
    # Reuse the certificate chain file that was verified to sign successfully,
    # rather than re-deriving the exact PEM layout the tool expects.
    known = Path(r"D:\XJITApp-glass-sign\signing\app-chain.pem")
    app_cert = sign_root / "app-chain.pem"
    if known.exists():
        shutil.copy2(known, app_cert)
    else:
        template = json.loads((SIGN_LIB / "UnsgnedDebugProfileTemplate.json").read_text(encoding="utf-8"))
        chain_items = re.findall(r"(?s)-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----",
                                 (SIGN_LIB / "OpenHarmonyProfileDebug.pem").read_text(encoding="utf-8"))
        ca = root = ""
        for item in chain_items:
            if "CN=OpenHarmony Application CA," in item:
                ca = item
            if "CN=OpenHarmony Application Root CA," in item:
                root = item
        chain = (template["bundle-info"]["development-certificate"].strip() + "\n\n" +
                 ca.strip() + "\n" + root.strip() + "\n")
        app_cert.write_text(chain, encoding="ascii", newline="\n")

    profile = json.loads((SIGN_LIB / "UnsgnedDebugProfileTemplate.json").read_text(encoding="utf-8"))
    profile["bundle-info"]["bundle-name"] = "com.xjit.app"
    profile["debug-info"]["device-ids"] = [UDID]
    import datetime
    now = int(datetime.datetime.now(datetime.timezone.utc).timestamp())
    profile["validity"]["not-before"] = now - 86400
    profile["validity"]["not-after"] = now + 30 * 86400
    profile["uuid"] = "00000000-0000-0000-0000-000000000001"
    pjson = sign_root / "profile.json"
    pjson.write_text(json.dumps(profile, indent=2), encoding="utf-8")
    p7b = sign_root / "profile.p7b"
    code, out = run([str(JAVA), "-jar", str(SIGNER), "sign-profile", "-mode", "localSign",
                     "-keyAlias", "openharmony application profile debug", "-keyPwd", "123456",
                     "-profileCertFile", str(SIGN_LIB / "OpenHarmonyProfileDebug.pem"),
                     "-inFile", str(pjson), "-signAlg", "SHA256withECDSA",
                     "-keystoreFile", str(KEYSTORE), "-keystorePwd", "123456", "-outFile", str(p7b)])
    if code != 0:
        return None, out
    code, out = run([str(JAVA), "-jar", str(SIGNER), "sign-app", "-mode", "localSign",
                     "-keyAlias", "openharmony application release", "-keyPwd", "123456",
                     "-appCertFile", str(app_cert), "-profileFile", str(p7b), "-inFile", str(hap),
                     "-signAlg", "SHA256withECDSA", "-keystoreFile", str(KEYSTORE),
                     "-keystorePwd", "123456", "-outFile", str(out_path), "-compatibleVersion", "26"])
    return (out_path if out_path.exists() else None), out


def install_launch_shot(signed: Path, label: str):
    run([str(HDC), "-t", TARGET, "uninstall", "com.xjit.app"])
    code, out = run([str(HDC), "-t", TARGET, "install", str(signed)])
    if "successfully" not in out:
        return None, "install failed: " + out[-300:]
    run([str(HDC), "-t", TARGET, "shell", "hilog -r"])
    run([str(HDC), "-t", TARGET, "shell", "aa start -a EntryAbility -b com.xjit.app"])
    import time
    time.sleep(9)
    shot = STAGE / f"shot-{label}.jpeg"
    run([str(HDC), "-t", TARGET, "shell", f"snapshot_display -f /data/local/tmp/{label}.jpeg"])
    import time as t
    t.sleep(2)
    run([str(HDC), "-t", TARGET, "file", "recv", f"/data/local/tmp/{label}.jpeg", str(shot)])
    lay = STAGE / f"layout-{label}.json"
    run([str(HDC), "-t", TARGET, "shell", "uitest dumpLayout -p /data/local/tmp/l.json"])
    t.sleep(2)
    run([str(HDC), "-t", TARGET, "file", "recv", "/data/local/tmp/l.json", str(lay)])
    logs = STAGE / f"log-{label}.txt"
    run([str(HDC), "-t", TARGET, "shell", "hilog -x > /data/local/tmp/h.txt"])
    t.sleep(1)
    run([str(HDC), "-t", TARGET, "file", "recv", "/data/local/tmp/h.txt", str(logs)])
    return (shot if shot.exists() else None), ""


def main():
    variant = sys.argv[1]
    adaptive = sys.argv[2]
    saturation = sys.argv[3]
    sync_stage()
    force_fallback()
    src = patch_glass(adaptive, saturation)
    m = re.search(r"backgroundEffect\(\{[^}]*\}", src, re.S)
    print("  patched:", " ".join((m.group(0) if m else "").split()))
    code, out, hap = build()
    if hap is None:
        print("  BUILD FAILED")
        print(out[-2500:])
        return 1
    print("  build ok")
    signed, sout = sign(hap, STAGE / f"signed-{variant}.hap")
    if signed is None:
        print("  SIGN FAILED")
        print(sout[-1500:])
        return 1
    print("  sign ok")
    shot, err = install_launch_shot(signed, variant)
    if shot is None:
        print("  LAUNCH/SHOT FAILED:", err)
        return 1
    print(f"  shot: {shot}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
