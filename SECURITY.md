# Security policy

Anchor+ holds people's private notes, so security reports are welcome and
taken seriously. Thank you for helping keep it safe.

## Reporting a vulnerability

**Please don't open a public issue, discussion or pull request for a
vulnerability.**

Report it privately through GitHub instead:
[**Report a vulnerability**](https://github.com/AlxndrJhn/anchor-plus/security/advisories/new)
(also under the repository's **Security** tab).

A good report says:

- what's affected (server, web app, desktop app, mobile app, Docker image or
  `install.sh`) and which version or commit
- the steps to reproduce it, ideally with a small proof of concept
- what an attacker gains (for example: reading another user's notes, taking
  over an account, running code on the server)

## What happens next

Anchor+ is maintained by one person in their spare time, so these are aims,
not guarantees:

- a first reply within **7 days**
- an assessment, and a severity agreed with you, within **14 days**
- a fix in a release within **30 days** for critical and high severity issues,
  sooner where possible

Once a fix is released, a GitHub security advisory is published (with a CVE
where it applies), crediting you by the name you choose, unless you'd rather
stay anonymous. Please keep the issue private until then.

There is no paid bug bounty.

## Supported versions

Fixes go into the latest release only. If you self-host, keep your instance
up to date.

## Scope

In scope: the code in this repository and the images and apps released from
it.

Out of scope:

- [ZhFahim/anchor](https://github.com/ZhFahim/anchor), the project Anchor+
  was forked from: report to it directly
- problems in a particular self-hosted setup that come from its configuration
  (for example, serving it over plain http, or a weak admin password)
- denial of service by sheer volume of traffic, spam, or social engineering
- reports from automated scanners or AI tools without a working proof of
  concept, or without a real impact (for example, a missing header alone)

## Testing safely

Test against your own instance (see the README for running one with Docker),
never against someone else's. Don't access, change or delete data that isn't
yours, and stop and report as soon as you've shown the problem. Good-faith
research that follows this policy is welcome, and won't be met with legal
action.
