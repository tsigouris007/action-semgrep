#!/bin/bash
TEMP_DIR="/tmp"
OUTFILE="$TEMP_DIR/semgrep.report.json.tmp"
RESULT="$TEMP_DIR/result.txt"
ROOT_DIR="$GITHUB_WORKSPACE/"

cd $GITHUB_WORKSPACE

echo '::group::Running Semgrep'
  SEMGREP="semgrep scan ${INPUT_CHANGED_FILES} \
    ${INPUT_SEMGREP_FLAGS} \
    -o $OUTFILE \
    --json"

  echo "Running: $SEMGREP"
  $SEMGREP

echo '::endgroup::'

echo '::group::Original Semgrep output'
  cat $OUTFILE
echo '::endgroup::'

echo '::group::Parsing output'
  if [ -z "${INPUT_SEMGREP_IGNORE}" ]
  then
    PARSE="ruby /parser.rb -f $OUTFILE -r $ROOT_DIR -p"
  else
    echo "Adding ignore file to results"
    PARSE="ruby /parser.rb -f $OUTFILE -i $INPUT_SEMGREP_IGNORE -r $ROOT_DIR -p"
  fi

  set -o pipefail
  $PARSE | tee $TEMP_DIR/$INPUT_ARTIFACT

  if [ ! -z "${INPUT_ARTIFACT}" ]
  then
    echo "Maintaining artifact: ${INPUT_ARTIFACT}"
    cp $TEMP_DIR/$INPUT_ARTIFACT $GITHUB_WORKSPACE/$INPUT_ARTIFACT
  fi
echo '::endgroup::'

echo '::group::Semgrep Result'
  echo "JSON Results:"
  cat $TEMP_DIR/$INPUT_ARTIFACT

  echo "GitHub Results:"
  cat $TEMP_DIR/$INPUT_ARTIFACT \
    | jq -r '.fingerprints[] | "::error file=\(.file),line=\(.start_line),col=1::[\(.severity)][\(.confidence)] \(.warning_type) \(.message) [\(.check_name)]"' > $RESULT
  cat $RESULT

  semgrep_comment=$(cat $TEMP_DIR/$INPUT_ARTIFACT)
  WARNINGS="$(echo $semgrep_comment | jq '.warnings')"
  echo "Warnings: $WARNINGS"

  if [ "${GITHUB_EVENT_NAME}" == "pull_request" ] && [ "${INPUT_SEMGREP_COMMENT}" == true ] && [ ${WARNINGS} -ne 0 ]; then
  sast_comment_wrapper="#### \`semgrep\` Failure
  <details><summary>Show Output</summary>

  \`\`\`
  ${semgrep_comment}
  \`\`\`
  </details>

  *Workflow: \`${GITHUB_WORKFLOW}\`, Action: \`${GITHUB_ACTION}\`, Semgrep: \`Failure\`*"

    echo "sast: info: creating json"
    sast_payload=$(echo "${sast_comment_wrapper}" | jq -R --slurp '{body: .}')
    sast_comment_url=$(cat ${GITHUB_EVENT_PATH} | jq -r .pull_request.comments_url)
    echo "sast: info: commenting on the pull request"
    echo "Posting comment: ${sast_payload}"
    echo "${sast_payload}" | curl -s -S -H "Authorization: token ${GITHUB_ACCESS_TOKEN}" --header "Content-Type: application/json" --data @- "${sast_comment_url}" > /dev/null

  fi
echo '::endgroup::'

exit $WARNINGS
