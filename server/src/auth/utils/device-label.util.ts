const MAX_USER_AGENT_LENGTH = 512;

const BROWSERS: [RegExp, string][] = [
  [/Edg(A|iOS)?\//, 'Edge'],
  [/OPR\/|Opera/, 'Opera'],
  [/Firefox\/|FxiOS\//, 'Firefox'],
  [/Chrome\/|CriOS\//, 'Chrome'],
  [/Safari\//, 'Safari'],
];

const SYSTEMS: [RegExp, string][] = [
  [/Android/, 'Android'],
  [/iPhone|iPad|iPod/, 'iOS'],
  [/Windows/, 'Windows'],
  [/Mac OS X|Macintosh/, 'macOS'],
  [/CrOS/, 'ChromeOS'],
  [/Linux/, 'Linux'],
];

const SYSTEM_NAMES: Record<string, string> = {
  android: 'Android',
  ios: 'iOS',
  windows: 'Windows',
  macos: 'macOS',
  linux: 'Linux',
};

/** What a person would call the device, as "Chrome on Windows". */
export function describeDevice(userAgent: string | null | undefined): string {
  if (!userAgent) return 'Unknown device';
  // The Android app says "AnchorPlus/<system>".
  const app = /^AnchorPlus\/(\w+)/.exec(userAgent);
  if (app) return `Anchor+ app on ${SYSTEM_NAMES[app[1]] ?? app[1]}`;
  const system = SYSTEMS.find(([pattern]) => pattern.test(userAgent))?.[1];
  if (/Electron\//.test(userAgent))
    return system ? `Anchor+ desktop on ${system}` : 'Anchor+ desktop';
  const browser = BROWSERS.find(([pattern]) => pattern.test(userAgent))?.[1];
  if (browser && system) return `${browser} on ${system}`;
  return browser ?? system ?? 'Unknown device';
}

export function trimUserAgent(userAgent: string | undefined) {
  return userAgent?.slice(0, MAX_USER_AGENT_LENGTH) || null;
}
