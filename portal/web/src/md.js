// Tiny markdown renderer for the SKILL.md preview (headings, code, lists,
// quotes, bold, links, inline code). Deliberately small — this is a preview,
// not a full CommonMark engine.
function esc(s) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}
function inline(t) {
  return esc(t)
    .replace(/`([^`]+)`/g, '<code>$1</code>')
    .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
    .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank" rel="noopener">$1</a>');
}
export function md(src) {
  const lines = src.split('\n');
  const out = [];
  let i = 0;
  while (i < lines.length) {
    const l = lines[i];
    if (/^```/.test(l)) {
      const buf = [];
      i++;
      while (i < lines.length && !/^```/.test(lines[i])) buf.push(lines[i++]);
      i++;
      out.push('<pre><code>' + esc(buf.join('\n')) + '</code></pre>');
      continue;
    }
    let m;
    if ((m = l.match(/^(#{1,4})\s+(.*)/))) {
      out.push(`<h${m[1].length}>${inline(m[2])}</h${m[1].length}>`);
      i++;
      continue;
    }
    if (/^>\s?/.test(l)) {
      const buf = [];
      while (i < lines.length && /^>\s?/.test(lines[i])) buf.push(lines[i++].replace(/^>\s?/, ''));
      out.push('<blockquote>' + md(buf.join('\n')) + '</blockquote>');
      continue;
    }
    if (/^\s*[-*]\s+/.test(l)) {
      const buf = [];
      while (i < lines.length && /^\s*[-*]\s+/.test(lines[i]))
        buf.push('<li>' + inline(lines[i++].replace(/^\s*[-*]\s+/, '')) + '</li>');
      out.push('<ul>' + buf.join('') + '</ul>');
      continue;
    }
    if (/^\s*\d+\.\s+/.test(l)) {
      const buf = [];
      while (i < lines.length && /^\s*\d+\.\s+/.test(lines[i]))
        buf.push('<li>' + inline(lines[i++].replace(/^\s*\d+\.\s+/, '')) + '</li>');
      out.push('<ol>' + buf.join('') + '</ol>');
      continue;
    }
    if (l.trim() === '') {
      i++;
      continue;
    }
    const buf = [l];
    i++;
    while (
      i < lines.length &&
      lines[i].trim() !== '' &&
      !/^(#{1,4}\s|>|\s*[-*]\s|\s*\d+\.\s|```)/.test(lines[i])
    )
      buf.push(lines[i++]);
    out.push('<p>' + inline(buf.join(' ')) + '</p>');
  }
  return out.join('\n');
}
