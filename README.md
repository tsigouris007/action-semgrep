# Semgrep Action

Use this Github action to scan your project using semgrep and receive annotations/comments. 

## Parameters

### `semgrep_flags`

Semgrep flags. \
Default: `--disable-verion-check --config=auto` \
*Note:* This is a free field to add any flags, includes, exludes, etc. you just have to prepare it in a previous step.

### `semgrep_ignore`

Specify a custom semgrep ignore fingerprint file from a URL. \
*Default:* `nil` \
*Note:* This is a custom functionality that ignores semgrep fingerprints (these are custom too) and you have the ability to ignore specific ones. Your ignore file should look like:
```json
 {
   "ignored_warnings": [
     {
       "note": "This is a custom note 1",
       "fingerprint": "a4efd74060e37fae96be358e760d0404fe05c27d4a5acce8581277e84301fff5"
     },
     {
       "note": "This is a custom note 2",
       "fingerprint": "a29580bf83e78a27fcbc34fcf6295bf7fa0b5a6568f6f6ce4bfb67c65cfa7fab"
     }
   ]
 }
```

### `semgrep_comment`

Add a comment to the PR if a finding was found. \
*Default:* `false`
*Available:* `true`| `false`

### `changed_files`

Changed filenames to be checked. \
*Default:* `nil` \

### `artifact`

Artifact file to maintain after running a job \
*Default:* `report.semgrep.json`

## Examples
```yml
name: Semgrep - JS, Python, Go Security Scan
on:
  push:
    branches:
      - main
      - master
    paths:
      - '**.js'
      - '**.jsx'
      - '**.go'
      - '**.py'
      - '.github/workflows/semgrep.yml'
  pull_request:
    paths:
      - '**.js'
      - '**.jsx'
      - '**.go'
      - '**.py'
      - '.github/workflows/semgrep.yml'
  workflow_dispatch:

jobs:
  semgrep:
    name: Semgrep run
    runs-on: ubuntu-latest
    container:
      image: tsigouris007/action-semgrep:<VERSION|BRANCH|COMMIT>
      credentials:
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}
    env:
      ARTIFACT: 'report.semgrep.json'
    steps:

      - name: Check out
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      # This step is necessary to retrieve changed files from git history apparently
      - name: Root for environment
        run: |
          chown root:root $(pwd)

      # Filter for changed files
      # Filter for specific file extensions (here is php for example)
      # We add some additional filtering for subfolders (excepted_dir_1, 2)
      - name: Get changed files
        if: ${{ github.event_name == 'pull_request' }}
        id: changed_files
        run: |
          FILTERED_FILES=$(gh api --paginate repos/<REPO_NAME>/pulls/${{ github.event.number }}/files -q \
            '.[] | select(.status == "removed" | not) | .filename' \
            | grep -E '.*\.php' \
            | grep -E -v '<excepted_dir_1>|<excepted_dir_2>' \
            | xargs)
          echo "Got files: $FILTERED_FILES"
          echo "CHANGED_FILES=$(echo $FILTERED_FILES)" >> $GITHUB_ENV

      - name: Show changed files
        run: |
          echo "Got changed files: ${{ env.CHANGED_FILES != '' }}"

      # Fetch all semgrep rules from https://github.com/semgrep/semgrep-rules
      - name: Fetch external rules
        run: |
          git clone https://github.com/semgrep/semgrep-rules@<VERSION|BRANCH|COMMIT>

      # Note: You can use config parameter in order to specify whole rule folders or event specific ones as shown
      - name: Semgrep run
        if: ${{ env.CHANGED_FILES != '' }}
        uses: tsigouris007/action-semgrep@master
        with:
          changed_files: ${{ env.CHANGED_FILES != '' }}
          artifact: ${{ env.ARTIFACT }}
          semgrep_comment: true
          semgrep_ignore: "semgrep.ignore"
          semgrep_flags: |
            --verbose
            --metrics=off
            --disable-version-check
            --config=semgrep-rules/php/
            --config=semgrep-rules/php/lang/security/backticks-use.yaml
        env:
          GITHUB_ACCESS_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```
