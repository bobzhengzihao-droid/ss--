/**
 * 混淆 index.html 中的内联 JS，部署阶段由 GitHub Actions 调用。
 * 跳过外部脚本（<script src="...">）和模板/JSON 块。
 */
const fs = require('fs');
const path = require('path');
const JavaScriptObfuscator = require('javascript-obfuscator');

const filePath = path.join(__dirname, '..', 'index.html');
let html = fs.readFileSync(filePath, 'utf8');

const opts = {
  compact: true,
  controlFlowFlattening: true,
  controlFlowFlatteningThreshold: 0.5,
  deadCodeInjection: true,
  deadCodeInjectionThreshold: 0.2,
  stringArray: true,
  stringArrayEncoding: ['base64'],
  stringArrayThreshold: 0.5,
  renameGlobals: false,
  selfDefending: true,
  debugProtection: false,
  disableConsoleOutput: false,
  transformObjectKeys: false,
  identifierNamesGenerator: 'hexadecimal',
  numbersToExpressions: true,
  simplify: true,
  splitStrings: true,
  splitStringsChunkLength: 8,
};

// 只处理内联 <script> 块（不含 src 属性）
const scriptRe = /(<script\b[^>]*>)([\s\S]*?)(<\/script>)/gi;

html = html.replace(scriptRe, (match, openTag, code, closeTag) => {
  // 外部脚本不处理
  if (/\bsrc\s*=/i.test(openTag)) return match;
  const trimmed = code.trim();
  if (!trimmed) return match;
  // 模板/配置类块跳过（仅包含 JSON 或单行声明的）
  if (/^\s*\/\/|^\s*const\s+\w+\s*=/.test(trimmed) && trimmed.length < 200) return match;
  try {
    const result = JavaScriptObfuscator.obfuscate(trimmed, opts);
    return openTag + '\n' + result.getObfuscatedCode() + '\n' + closeTag;
  } catch (e) {
    console.warn('Obfuscation skipped a block:', e.message);
    return match;
  }
});

fs.writeFileSync(filePath, html, 'utf8');
console.log('Obfuscation complete.');
