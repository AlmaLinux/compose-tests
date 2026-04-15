# Quick Start

Requirements:

```sh
dnf install tmt+all
```

Run all tests on centos-stream-9:

```sh
tmt -vv -c distro=centos-stream-9 run -a provision --how=virtual --image centos-stream-9 prepare --how=feature --epel=enabled --order=20
```

Run only one test on centos-stream-9:

```sh
tmt -vv -c distro=centos-stream-9 run -a provision --how=virtual --image centos-stream-9 prepare --how=feature --epel=enabled --order=20 test --name /tests/sysstat
```

These commands will provision a local VM using libvirt from a centos-stream-9 image, copy the tests from the local directory into it, run them, and rsync the results from the VM to your machine on the directory `/var/tmp/tmt`.


# Directory Structure

## `plans`

TMT plans.

* `external/`: Plans that import remote tmt tests (e.g., from gitlab.com/redhat/centos-stream/rpms)
* `ng.fmf`: The plan that runs the new generation of tests in `tests/` that fully leverage `tmt`, excluding the ones in `tests/legacy`
* `legacy.fmf`: The plan that runs the `t_functional` tests in `tests/legacy/`


## `tests`

Tests will be organized in one directory per packages and one directory per integration test comprising multiple packages.
The `legacy` contains the tests imported from `t_functional`.

# Adding a Test

Create a folder inside `tests/` named after the package you want to test, e.g., `httpd`. It could also be named after some integration test involving multiple packages (e.g., `httpd-php-postgresql`).

Organize your tests inside the folder by features you are testing. Feel free to leverage `tmt` and `beakerlib` to design them. You can follow the `podman` test as an example.

* `tmt` documentation: https://tmt.readthedocs.io
* `beakerlib` documentation: https://beakerlib.readthedocs.io/en/latest/manual.html#

When finished, ensure the tests pass the linting, and pay attention to any warning:
```sh
tmt lint
find ./tests/yourtest/ -name '*.sh' | xargs -n 1 shellcheck --severity=warning --shell=bash
```

You should be able to run your tests individually as follow:

```sh
tmt -vv -c distro=centos-stream-9 run -a provision --how=virtual --image centos-stream-9 prepare --how=feature --epel=enabled --order 20 test --name /tests/yourtest
```

Test outputs will be in the default temp `tmt` folder, e.g. `/var/tmp/tmt`. If you pass `-vv` to the command as in the example above, you will get the full path to the output of each test. For example:

```yaml
    report
        how: display
            pass /tests/yourtest
                output.txt: /var/tmp/tmt/run-1/plans/execute/data/guest/default-0/tests/yourteset-1/output.txt
                journal.txt: /var/tmp/tmt/run-1/plans/execute/data/guest/default-0/tests/yourteset-1/journal.txt
        summary: 1 test passed
```

# Adding an External Test

Create a `.fmf` file within `plans/external/` named after the package, and follow the `tmt` documentation how to import tmt tests from git (see the `discover` step [Example](https://tmt.readthedocs.io/en/stable/examples.html#plans), and [Specs](https://tmt.readthedocs.io/en/stable/spec/plans.html#spec-plans-discover) ). You can follow the `plans/external/podman.fmf` example.

# Enabling/Disabling Tests

You can enable or disable test based on the distro in the `fmf` file. Example:

```yaml
enabled: true # default
adjust: # change "enabled" value when condition is true
  when: distro == centos-7
  enabled: false
```

You can also disable a test all together with the same `enabled: false` flag on the test `fmf` file. Example:

```yaml
summary: tests podman pull
description: It tests podman pull with different options
enabled: false # disabling for now until issue #99999 is resolved
```

# Tiers

TODO: define the tiers and what tiers a test should go into.


# How to Run the `legacy` Tests on Another EL Distro

The legacy tests contains variable that are EL distro specific. These variables are defined in the `legacy.fmf` file. In order to run those tests in another EL distro, you would need to override them. You can do it in two different ways:

A) Passing them in the command line, for example:

```sh
tmt -vvv -c distro=centos-stream-9 run \
    -e vendor="eldistro" \
    -e os_name="ELdistro" \
    -e grub_sb_token="ELdistro Secure Boot Signing" \
    -e kernel_sb_token="ELdistro Secure Boot Signing" \
    -e key_template="ELdistro %s signing key" \
    -e firefox_start_page="www.eldistro.org" \
   --all provision --how=connect --guest=192.168.210.10 --user=somedefaultuser --become
```

B) Defining a new plan importing `compose-tests`

```yaml
summary: Compose tests plan
environment:
  vendor: "eldistro"
  os_name: "ELdistro"
  grub_sb_token: "ELdistro Secure Boot Signing"
  kernel_sb_token: "ELdistro Secure Boot Signing"
  key_template: "ELdistro %s signing key"
  firefox_start_page: "www.eldistro.org"
discover:
  how: fmf
  url: https://gitlab.com/CentOS/Integration/compose-tests.git
execute:
  how: tmt
```

In order to run only a set of tests on the different EL distro, you can use `tmt` filtering to specify them:

```sh
# Run tests that their name start with `/legacy/p_`
tmt -vv -c distro=centos-stream-9 run -a provision --how=connect --guest=192.168.210.10 --user=somedefaultuser --become test --name '/legacy/p_.*'
```
