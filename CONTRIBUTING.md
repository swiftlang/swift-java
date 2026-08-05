## Legal

By submitting a pull request, you represent that you have the right to license
your contribution to Apple and the community, and agree by submitting the patch
that your contributions are licensed under the Apache 2.0 license (see
`LICENSE.txt`).

## How to submit a bug report

Please ensure to specify the following:

* Commit hash
* Contextual information (e.g. what you were trying to achieve with swift-java)
* Simplest possible steps to reproduce
  * The more complex the steps, the lower the priority.
  * A pull request with failing test case is preferred, but it's just fine to paste the test case into the issue description.
* Anything that might be relevant in your opinion, such as:
  * Swift version or the output of `swift --version`
  * OS version and the output of `uname -a`

### Example

```
Commit hash: b17a8a9f0f814c01a56977680cb68d8a779c951f

Context:
While testing my application that uses swift-java, I noticed that ...

Steps to reproduce:
1. ...
2. ...
3. ...
4. ...

$ swift --version
Swift version 4.0.2 (swift-4.0.2-RELEASE)
Target: x86_64-unknown-linux-gnu

Operating system: Ubuntu Linux 16.04 64-bit

$ uname -a
Linux beefy.machine 4.4.0-101-generic #124-Ubuntu SMP Fri Nov 10 18:29:59 UTC 2017 x86_64 x86_64 x86_64 GNU/Linux

My system has IPv6 disabled.
```

## Writing a Patch

A good patch is:

1. Concise, and contains as few changes as needed to achieve the end result.
2. Tested, ensuring that any tests provided failed before the patch and pass after it.
3. Documented, adding API documentation as needed to cover new functions and properties.
4. Accompanied by a great commit message, using our commit message template.

### Run CI checks locally

You can run the Github Actions workflows locally using
[act](https://github.com/nektos/act). To run all the jobs that run on a pull
request, use the following command:

```
% act pull_request
```

To run just a single job, use `workflow_call -j <job>`, and specify the inputs
the job expects. For example, to run just shellcheck:

```
% act workflow_call -j soundness --input shell_check_enabled=true
```

To bind-mount the working directory to the container, rather than a copy, use
`--bind`. For example, to run just the formatting, and have the results
reflected in your working directory:

```
% act --bind workflow_call -j soundness --input format_check_enabled=true
```

If you'd like `act` to always run with certain flags, these can be placed in
an `.actrc` file either in the current working directory or your home
directory, for example:

```
--container-architecture=linux/amd64
--remote-name upstream
--action-offline-mode
```

For frequent contributors, we recommend running the soundness checks before pushing. You can wire that up as a [git pre-push hook](https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks):

```bash
cat << 'EOF' > .git/hooks/pre-push
#!/bin/sh
exec act workflow_call -j soundness --input format_check_enabled=true --input shell_check_enabled=true
EOF
chmod +x .git/hooks/pre-push
```

This only allows the `git push` to complete if the checks pass.

In the case of formatting issues, `git add` the formatting changes and attempt the push again.

### Regenerating generated docs

Some documentation is generated from source and checked in, so CI can catch it drifting out of date. If you changed `Configuration.swift` or a CLI command's flags/help text, run `scripts/generate-docs.sh` and commit the generated changes.

## How to contribute your work

Please open a pull request at https://github.com/swiftlang/swift-java. Make sure the CI passes, and then wait for code review.

