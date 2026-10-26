const fs = require('node:fs/promises');
const path = require('node:path');
const PDFDocument = require('pdfkit');
const SVGtoPDF = require('svg-to-pdfkit');

async function main() {
    const sources = path.resolve('Assets/BrandSources');
    for (const name of (await fs.readdir(sources)).filter(name => name.endsWith('.svg'))) {
        const slug = path.basename(name, '.svg');
        const output = path.resolve(`Assets.xcassets/Brand-${slug}.imageset`);
        await fs.mkdir(output, {recursive: true});
        const document = new PDFDocument({size: [128, 128], margin: 0, compress: true});
        const chunks = [];
        const finished = new Promise((resolve, reject) => {
            document.on('data', chunk => chunks.push(chunk));
            document.on('end', resolve);
            document.on('error', reject);
        });
        SVGtoPDF(document, await fs.readFile(path.join(sources, name), 'utf8'), 0, 0,
            {width: 128, height: 128, preserveAspectRatio: 'xMidYMid meet'});
        document.end();
        await finished;
        await fs.writeFile(path.join(output, 'icon.pdf'), Buffer.concat(chunks));
        await fs.writeFile(path.join(output, 'Contents.json'), JSON.stringify({
            images: [{idiom: 'universal', filename: 'icon.pdf'}],
            info: {author: 'xcode', version: 1},
            properties: {'preserves-vector-representation': true}
        }, null, 2) + '\n');
        await fs.rm(path.join(output, 'icon.png'), {force: true});
        await fs.rm(path.join(output, 'icon.svg'), {force: true});
    }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
