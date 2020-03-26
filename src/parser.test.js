const { parse } = require('.');
const fs = require('fs');
const fsPromise = fs.promises;
const path = require('path');

describe('parser', () => {
    it('should parse basic HTML', async () => {
        const actual = await parseFile('basic_html');
        expect(actual).toMatchSnapshot();
    });

    it('should parse variable access', async () => {
        const actual = await parseFile('variables');
        expect(actual).toMatchSnapshot();
    });

    it('should parse helpers', async () => {
        const actual = await parseFile('helpers');
        expect(actual).toMatchSnapshot();
    });

    it('should parse block helpers', async () => {
        const actual = await parseFile('block_helpers');
        expect(actual).toMatchSnapshot();
    });

    it('should parse else blocks', async () => {
        const actual = await parseFile('else_blocks');
        expect(actual).toMatchSnapshot();
    });

    it('should parse html attributes', async () => {
        const actual = await parseFile('html_attributes');
        expect(actual).toMatchSnapshot();
    });

    it('should parse processing instructions', async () => {
        const actual = await parseFile('processing_instructions');
        expect(actual).toMatchSnapshot();
    });

    it('should parse css module usages', async () => {
        const actual = await parseFile('css_modules');
        expect(actual).toMatchSnapshot();
    });

    it('should parse scoped CSS', async () => {
        const actual = await parseFile('scoped_css');
        expect(actual).toMatchSnapshot();
    });

    it('should parse render props', async () => {
        const actual = await parseFile('render_props');
        expect(actual).toMatchSnapshot();
    });
});

async function parseFile(fileName) {
    const content = await fs.promises.readFile(path.join(__dirname, '__fixtures__', `${fileName}.hbs`));
    return parse(content.toString());
}