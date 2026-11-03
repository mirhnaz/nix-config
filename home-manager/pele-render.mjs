import { readFileSync, writeFileSync } from 'node:fs';
import { parseArgs } from 'node:util';
import { render } from 'pele';

const help = `Usage: pele-render [input.mmd|-] [-o output.svg]

Render Mermaid source to SVG using Pele.
Reads stdin when no input or '-' is supplied; writes stdout unless -o is set.
Requires Node >=20 on PATH (Homebrew on macOS, mise on Omarchy).

Options:
  -o, --output FILE  Write SVG to FILE
  -h, --help         Show this help
`;

try {
  const { values, positionals } = parseArgs({
    options: {
      output: { type: 'string', short: 'o' },
      help: { type: 'boolean', short: 'h' },
    },
    allowPositionals: true,
  });
  if (values.help) {
    process.stdout.write(help);
  } else {
    if (Number(process.versions.node.split('.')[0]) < 20) {
      throw new Error('Node >=20 is required.');
    }
    if (positionals.length > 1) throw new Error('Expected at most one input file.');
    const input = positionals[0];
    if ((!input || input === '-') && process.stdin.isTTY) {
      throw new Error('Provide an input file or pipe Mermaid source on stdin. Use --help for usage.');
    }
    const source = readFileSync(!input || input === '-' ? 0 : input, 'utf8');
    const { svg } = render(source);
    if (values.output) writeFileSync(values.output, `${svg}\n`);
    else process.stdout.write(`${svg}\n`);
  }
} catch (error) {
  process.stderr.write(`pele-render: ${error.message}\n`);
  process.exitCode = 1;
}
