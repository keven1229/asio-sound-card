import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const installRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
process.env.EASYEDA_BIN ||= path.join(installRoot, 'easyeda_windows_amd64.exe');
let health;
try {
  const response = await fetch('http://127.0.0.1:60832/health', { signal: AbortSignal.timeout(1500) });
  if (response.ok) health = await response.json();
} catch { /* Start the installed daemon below if it is offline. */ }
if (!health) {
  const powershell = path.join(process.env.SystemRoot || 'C:\\Windows', 'System32', 'WindowsPowerShell', 'v1.0', 'powershell.exe');
  await promisify(execFile)(powershell, [
    '-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
    '-File', path.join(installRoot, 'start-easyeda-ai.ps1'), '-InstallRoot', installRoot,
  ], { windowsHide: true, timeout: 25000, encoding: 'utf8' });
} else if (health.service !== 'easyeda-agent' || health.version.replace(/^v/, '') !== '1.3.0') {
  throw new Error('Port 60832 is occupied by an unexpected service or EasyEDA version.');
}
await import('./src/server.mjs');
