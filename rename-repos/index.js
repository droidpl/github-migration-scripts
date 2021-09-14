require('dotenv').config()
const csv = require('csvtojson')
const { Octokit } = require('@octokit/rest')

const CSV_PATH = './rename.csv'

;
(async() => {
    const repos = await (csv()).fromFile(CSV_PATH)
    const octo = new Octokit({
        auth: process.env.GITHUB_TOKEN
    })

    //Generate the owner and repository information
    const mapToOwner = (item) => {
        const [owner, repo] = item.split('/')
        return {
            owner,
            repo
        }
    }
    const reposWithOwner = repos.map((item) => {
        return {
            origin: mapToOwner(item.origin),
            target: mapToOwner(item.target),
        }
    })
    console.log(JSON.stringify(reposWithOwner, null, 2))
        // Function to rename the repositories
    const renameRepo = async(origin, target) => {
        return await octo.repos.update({
            owner: origin.owner,
            repo: origin.repo,
            name: target.repo
        })
    }

    reposWithOwner.forEach(async(item) => {
        try {
            console.log(`Renaming ${item.origin.owner}/${item.origin.repo} to ${item.target.owner}/${item.target.repo}`)
            await renameRepo(item.origin, item.target)
            console.log('Success!')
        } catch (error) {
            console.error(`Error renaming: ${error}`)
        }
    });
})()