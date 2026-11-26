// Shows the docs dev server's rendering of the active content/ page in a
// webview beside the editor. The preview follows the active file, and jumps
// to the heading at the top of the editor's visible range.
const vscode = require('vscode');
const path = require('path');

let panel;
let autoOpened = false;
let current = { page: '', anchor: '' };
let timer;

function config() {
  return vscode.workspace.getConfiguration('windsorDocs');
}

// content/contexts/overview.md -> /contexts/overview
function routeFor(doc) {
  if (!doc || doc.languageId !== 'markdown' || doc.uri.scheme !== 'file') return undefined;
  const folder = vscode.workspace.getWorkspaceFolder(doc.uri);
  if (!folder) return undefined;
  const rel = path.relative(folder.uri.fsPath, doc.uri.fsPath).split(path.sep).join('/');
  if (!rel.startsWith('content/') || !rel.endsWith('.md')) return undefined;
  return '/' + rel.slice('content/'.length, -'.md'.length);
}

// Same ids github-slugger gives the site's headings.
function slug(text) {
  return text
    .trim()
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s_-]/gu, '')
    .replace(/\s/g, '-');
}

function anchorFor(editor) {
  if (!config().get('followSection') || !editor.visibleRanges.length) return '';
  const top = editor.visibleRanges[0].start.line;
  let inFence = false;
  let found = '';
  for (let i = 0; i <= Math.min(top + 2, editor.document.lineCount - 1); i++) {
    const line = editor.document.lineAt(i).text;
    if (/^\s*(```|~~~)/.test(line)) inFence = !inFence;
    if (inFence) continue;
    const m = /^#{2,6}\s+(.*?)\s*#*\s*$/.exec(line);
    if (m) found = slug(m[1]);
  }
  return found;
}

async function siteUrl(page, anchor) {
  const base = config().get('siteUrl').replace(/\/$/, '');
  const external = await vscode.env.asExternalUri(vscode.Uri.parse(base));
  return external.toString(true).replace(/\/$/, '') + page + (anchor ? '#' + anchor : '');
}

function html(webview, frameSrc) {
  const nonce = String(Math.random()).slice(2);
  return `<!doctype html>
<html><head><meta charset="utf-8">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; frame-src http: https:; style-src 'unsafe-inline'; script-src 'nonce-${nonce}';">
<style>
  html, body { margin: 0; padding: 0; height: 100%; overflow: hidden; background: var(--vscode-editor-background); }
  iframe { border: 0; width: 100%; height: 100%; background: white; }
</style></head>
<body>
<iframe id="site" src="${frameSrc}"></iframe>
<script nonce="${nonce}">
  const frame = document.getElementById('site');
  window.addEventListener('message', (e) => {
    const msg = e.data;
    if (msg.type === 'navigate') frame.src = msg.url;
    if (msg.type === 'reload') { const u = frame.src; frame.src = 'about:blank'; setTimeout(() => { frame.src = u; }, 50); }
  });
</script>
</body></html>`;
}

async function show(editor, { reveal } = { reveal: false }) {
  const page = routeFor(editor && editor.document);
  if (!page) return;
  const anchor = anchorFor(editor);
  const url = await siteUrl(page, anchor);
  if (!panel) {
    panel = vscode.window.createWebviewPanel(
      'windsorDocsPreview',
      'Site preview',
      { viewColumn: vscode.ViewColumn.Beside, preserveFocus: true },
      { enableScripts: true, retainContextWhenHidden: true },
    );
    panel.onDidDispose(() => { panel = undefined; current = { page: '', anchor: '' }; });
    panel.webview.html = html(panel.webview, url);
  } else if (page !== current.page || anchor !== current.anchor) {
    panel.webview.postMessage({ type: 'navigate', url });
  }
  if (reveal) panel.reveal(undefined, true);
  panel.title = 'Preview: ' + path.posix.basename(page);
  current = { page, anchor };
}

function schedule(editor) {
  if (!panel || !editor) return;
  clearTimeout(timer);
  timer = setTimeout(() => show(editor), 250);
}

function maybeAutoOpen(editor) {
  if (autoOpened || panel || !config().get('openOnStartup')) return;
  if (!routeFor(editor && editor.document)) return;
  autoOpened = true;
  show(editor);
}

function activate(context) {
  context.subscriptions.push(
    vscode.commands.registerCommand('windsorDocs.preview', () => show(vscode.window.activeTextEditor, { reveal: true })),
    vscode.commands.registerCommand('windsorDocs.reload', () => panel && panel.webview.postMessage({ type: 'reload' })),
    vscode.window.onDidChangeActiveTextEditor((editor) => { maybeAutoOpen(editor); schedule(editor); }),
    vscode.window.onDidChangeTextEditorVisibleRanges((e) => {
      if (e.textEditor === vscode.window.activeTextEditor) schedule(e.textEditor);
    }),
  );
  maybeAutoOpen(vscode.window.activeTextEditor);
}

function deactivate() {}

module.exports = { activate, deactivate };
