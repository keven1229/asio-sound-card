// Read-only end-to-end MCP verification of the saved environment fixture.
// Keep ASIO_AI_ENV_SMOKE.eprj2 open in EasyEDA Pro before running this script.
import assert from 'node:assert/strict';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { writeFile } from 'node:fs/promises';

const installRoot = process.env.EASYEDA_INSTALL_ROOT || path.join(process.env.LOCALAPPDATA, 'easyeda-agent', 'v1.3.0');
const sdk = path.join(installRoot, 'mcp', 'node_modules', '@modelcontextprotocol', 'sdk', 'dist', 'esm', 'client');
const { Client } = await import(pathToFileURL(path.join(sdk, 'index.js')).href);
const { StdioClientTransport } = await import(pathToFileURL(path.join(sdk, 'stdio.js')).href);
const client = new Client({ name: 'asio-native-schematic-check', version: '1.0.0' });
try {
  await client.connect(new StdioClientTransport({
    command: process.execPath,
    args: [path.join(installRoot, 'mcp', 'launcher.mjs')],
    env: { ...process.env, EASYEDA_BIN: path.join(installRoot, 'easyeda_windows_amd64.exe') },
  }));
  const reply = await client.callTool({
    name: 'easyeda_schematic',
    arguments: { action: 'schematic.read', project: 'ASIO_AI_ENV_SMOKE', doc: 'DIVIDER' },
  });
  assert.equal(reply.isError, false, 'MCP tool failed');
  let response = reply.structuredContent;
  if (response?.warnings && response.result) response = response.result;
  assert.equal(response.ok, true, 'EDA bridge failed');
  assert.equal(response.context.projectName, 'ASIO_AI_ENV_SMOKE');
  const snapshot = response.result;
  const parts = snapshot.components.filter(part => part.componentType === 'part');
  assert.deepEqual(parts.map(part => part.designator).sort(), ['R1', 'R2']);
  assert.ok(parts.every(part => part.supplierId === 'C25804'));
  const pinNets = Object.fromEntries(parts.flatMap(part => part.pins.map(pin => [`${part.designator}.${pin.number}`, pin.net])));
  assert.deepEqual(pinNets, { 'R1.1': 'VIN', 'R1.2': 'VOUT', 'R2.1': 'VOUT', 'R2.2': 'GND' });
  assert.deepEqual(snapshot.nets.map(net => net.net).sort(), ['GND', 'VIN', 'VOUT']);
  assert.equal(snapshot.check.passed, true);
  const report = {
    checkedAt: new Date().toISOString(),
    protocol: 'MCP stdio -> CLI -> daemon -> EasyEDA Pro connector',
    project: response.context.projectName,
    doc: response.context.documentUuid,
    componentCount: parts.length,
    pinNets,
    schematicReadbackPassed: true,
    structuralCheck: snapshot.check,
    nativeDrc: 'See gate-final.txt: 0 fatal, 0 error, 2 single-pin-net warnings (VIN/GND). Strict gate remains FAIL.',
  };
  const json = JSON.stringify(report, null, 2) + '\n';
  if (process.argv[2]) await writeFile(process.argv[2], json, 'utf8');
  process.stdout.write(json);
} finally {
  await client.close();
}
