# Kernel Devel VM Action

A GitHub Action that bootstraps a [Lima][lima] instance running [Fedora
Linux][fedora] with the selected kernel version.

Its main purpose is to facilitate the building and testing of kernel modules in
CI workflows. It was originally written to support the automated build pipeline
for the [broadcom-wl][wl] wireless driver.

## How It Works

The Action queries Fedora's [public mirrors][mirrors] to retrieve the latest
QEMU image and SHA256 checksum for the selected OS version, and generates a
Lima instance configuration using this information.

It then mounts provisioning scripts inside that instance, which Lima executes
as part of its initialization process (_cloud-init_). The scripts query
[Bodhi][bodhi] — Fedora's updates system — to find and download the most
suitable kernel candidate for the selected version. If a candidate is found, it
is installed and the bootloader configuration gets updated to boot on that
specific kernel version.

## Usage

### Pre-requisites

- A runner with Virtualization enabled, to support QEMU/KVM
- [Lima][lima] ≥ 0.12.x
- [yq][yq] ≥ 4.x

> **Warning**
>
> GitHub-hosted [Linux runners][gh-runners] do not currently support nested
> virtualization (ref. [actions/runner-images#183][actions-issue-183]).
> However, macOS runners, such as `macos-12`, do have virtualization enabled
> _and_ Lima pre-installed, which makes them ideal candidates for running this
> Action.
>
> Another option is to use [self-hosted runners][gh-selfhosted].

### Inputs

- `kernel` **(required)**: The desired kernel version in _\<major>.\<minor>_
  semantic format (e.g. "5.19").
- `os`: The version code of the Fedora Linux release to bootstrap the instance
  with (e.g. "f38"). Defaults to `f37`.

### Outputs

- `kernel`: The full version string of the kernel running inside the
  bootstrapped instance (e.g. "5.19.17-300.fc37.x86_64").
- `kernel-short`: The short, [SemVer][semver] compatible version string of the
  kernel running inside the bootstrapped instance (e.g. "5.19.17").
- `logs`: Location on the runner of the exported cloud-init logs (e.g.
  "/tmp/lima/myinstance").

### Environment variables

Upon execution, this Action sets the `LIMA_INSTANCE` environment variable to
the name of the bootstrapped Lima instance, and makes it available to all
subsequent job steps.

### Example workflow

```yaml
name: Build Kernel Module

on: push

jobs:
  build:
    runs-on: macos-12

    strategy:
      matrix:
        include:
        - kernel: '5.16'
          os: f36
        - kernel: '5.19'
          os: f37
        - kernel: '6.1'
          os: f38

    steps:
    - name: Bootstrap Lima instance
      id: builder
      uses: antoineco/kernel-devel-vm-action@v1
      with:
        kernel: ${{ matrix.kernel }}
        os: ${{ matrix.os }}

    - name: Build kernel module
      id: build
      run: lima make
```

For more elaborate usage examples, take a look at the [build workflow][wl-ci]
for `broadcom-wl`, or the [CI workflow][ci] for this Action.

[fedora]: https://getfedora.org
[mirrors]: https://admin.fedoraproject.org/mirrormanager/
[bodhi]: https://bodhi.fedoraproject.org

[lima]: https://github.com/lima-vm/lima#readme
[lima-install]: https://github.com/lima-vm/lima#getting-started

[yq]: https://mikefarah.gitbook.io/yq/

[gh-runners]: https://docs.github.com/en/actions/using-github-hosted-runners/about-github-hosted-runners#supported-runners-and-hardware-resources
[gh-selfhosted]: https://docs.github.com/en/actions/hosting-your-own-runners/about-self-hosted-runners

[semver]: https://semver.org

[wl]: https://github.com/antoineco/broadcom-wl
[wl-ci]: https://github.com/antoineco/broadcom-wl/blob/patch-linux4.7/.github/workflows/ci.yaml

[ci]: .github/workflows/ci.yaml

[actions-issue-183]: https://github.com/actions/runner-images/issues/183#issuecomment-610723516
