const { Document } = require('flexsearch')
const fs = require('fs')
const process = require('process')
const path = require('path')

var flexsearchIdx = new Document({
    document: {
        id: 'id',
        store: ['title', 'pagetitle', 'ref'],
        index: [
            {
                field: 'content',
                tokenize: 'forward',
                minlength: 3,
                resolution: 5
            }
        ]
    },
    encoder: 'advanced',
    fastupdate: false,
    optimize: true,
    context: false,
});

const idx = require(process.cwd() + '/index.json')

idx.forEach(doc => {
    flexsearchIdx.add(doc)
})

fs.mkdirSync(path.join(process.cwd(), 'search-data'))
flexsearchIdx.export((key, data) => {
    if (data) {
        const p = path.join(process.cwd(), 'search-data', key + '.json')
        try {
            fs.writeFileSync(p, data)
            console.log('  ' + key)
        } catch (err) {
            console.error(err)
        }
    }
})
