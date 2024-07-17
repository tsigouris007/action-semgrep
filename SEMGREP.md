# Resources
Docker Image: returntocorp/semgrep:1.56.0 \
Semgrep: https://github.com/semgrep/semgrep \
Semgrep Rules: https://semgrep.dev/playground/new

# Tool + Rules
```bash
docker pull returntocorp/semgrep:1.56.0
git clone https://github.com/semgrep/semgrep-rules
```

# Running a simple Scan
```bash
docker run --rm -it -v "${PWD}:/src" returntocorp/semgrep:1.56.0 semgrep scan \
  --verbose \
  --disable-version-check \
  --json \
  --output=results.json \
  --include="**/**.php" \
  --config=auto
```

# Running a Scan with custom rules
```bash
docker run --rm -it -v "${PWD}:/src" -v "/home/$USER/github/everypay/semgrep-rules:/semgrep-rules" returntocorp/semgrep:1.56.0 semgrep scan \
  --verbose \
  --disable-version-check \
  --json \
  --output=results.json \
  --include="**/**.php" \
  --config=/semgrep-rules/php/
```

# Reporting Format
NOTE: For this step you are going to need this utility from: https://github.com/tsigouris007/action-semgrep/blob/main/parser.rb
```bash
./parser.rb -f OWASPWebGoatPHP/results.json -p > semgrep.results.json
```
