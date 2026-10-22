# Get started

Install Replicant first:

```sh
omarchy plugin add https://github.com/tymurbogach/replicant --enable
```

Open Replicant from the bar. The first screen provides **Create private repo**
and **Clone existing**. You do not need the terminal for normal setup.

Run `replicant create --push` on the first machine. The command creates
or uses a private GitHub repository, initializes the local copy, and pushes the
first commit. Setup requires explicit PRIVATE visibility: an unknown,
empty, or non-private result stops before any local change. Check
`gh auth login` and the network, then retry.

Run `replicant clone <url>` on each other machine. The remote must hold
a complete Replicant repository. If it is empty, return to the first machine
and use Create.

Run `replicant key init` on the first machine before you save secrets. On every other
machine, run `replicant key import <source>` instead (init is refused over an existing
vault). Run `replicant save --all --auto` to save configuration. Review a restore with
`replicant restore --dry-run` before you apply it. The examples below assume `replicant`
is on your `PATH` (`$P/bin/replicant link` puts it there); otherwise prefix them with
`$P/bin/replicant` where `$P` is the plugin directory from the Second-machine section
of the README.
