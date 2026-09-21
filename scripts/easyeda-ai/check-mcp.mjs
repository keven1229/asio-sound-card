import assert from 'node:assert/strict';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';

const packageRoot = path.dirname(fileURLToPath(import.meta.url));
const client = new Client({ name: 'asio-sound-card-environment-check', version: '1.0.0' });
try {
  await client.connect(new StdioClientTransport({
    command: process.execPath,
    args: [path.join(packageRoot, 'launcher.mjs')],
    env: { ...process.env, EASYEDA_BIN: path.resolve(packageRoot, '..', 'easyeda_windows_amd64.exe') },
  }));
  const list = await client.listTools();
  assert.equal(list.tools.length, 11);
  const actions = await client.callTool({ name: 'easyeda_actions', arguments: {} });
  assert.equal(actions.isError, false);
  assert.ok(actions.structuredContent.count > 0);
  assert.ok(!actions.structuredContent.actions.some(action => action.domain === 'debug'));
  const health = await client.callTool({ name: 'easyeda_health', arguments: {} });
  assert.equal(health.isError, false);
  process.stdout.write(JSON.stringify({
    mcpInitialized: true,
    server: client.getServerVersion(),
    toolCount: list.tools.length,
    toolNames: list.tools.map(tool => tool.name),
    typedActionCount: actions.structuredContent.count,
    daemonHealth: health.structuredContent || health.content,
  }, null, 2) + '\n');
} finally { await client.close(); }
