<h1 align="center">
  <br>
  <a href="https://ayakaleaf-pro.ayaka.space"><img src="doc/logo.png" alt="Ayakaleaf Pro" width="300"></a>
</h1>

<h4 align="center">Overleaf Community Edition enhanced with all Pro features <br/>(open source, free to use, self-hostable).</h4>

<p align="center">
  <a href="https://ayakaleaf-pro.ayaka.space">Documents</a> •
  <a href="https://github.com/ayaka-notes/ayakaleaf-pro-playground">Playground</a> •
  <a href="https://ayakaleaf-pro.ayaka.space/blog">Blog</a> •
  <a href="https://github.com/orgs/ayaka-notes/packages/container/package/overleaf-pro">Docker Image</a> •
  <a href="https://github.com/ayaka-notes/texlive-full">TeXLive</a> •
  <a href="https://ayakaleaf-pro.ayaka.space/dev">Developer</a> •
  <a href="#authors">Authors</a> •
  <a href="#license">License</a>
</p>

<img src="doc/screenshot-pro.png" alt="A screenshot of a project being edited in Overleaf Community Edition">
<p align="center">
  Figure 1: A screenshot of a project being edited in Ayakaleaf Pro Edition.
</p>

## Ayakaleaf Pro Edition
Ayakaleaf Pro is an enhanced version of Overleaf with almost all features and capabilities. For details, please check [Ayakaleaf Pro](https://ayakaleaf-pro.ayaka.space) page. Features in Ayakaleaf Pro include: 

- AI Chat Assistant (Features in SaaS Platform)
- Error Assistant (Features in SaaS Platform)
- Pandoc Import/Export (Features in SaaS Platform)
- Python Script Runner (Features in SaaS Platform)
- 2-way GitHub Sync (Features in SaaS Platform)
- Zotero Integration(With Zotero OAuth Support)
- Mendeley Integration(With Mendeley OAuth Support)
- Advanced Reference Search (Features in SaaS Platform)
- Git-Bridge Support (Features in Server Pro)
- Admin Panel (Global Users/Projects management)
- SSO with LDAP and SAML or OAuth 2.0
- Unlimited Compile Times (Adjustable in admin panel)
- Self Register (Optional, can be limited by mail domain)
- Sandbox Compile (With [texlive-full](https://github.com/ayaka-notes/texlive-full) image support)
- Template System (With Template Gallery)
- Track Changes (With Review and Comment Panel)
- Full Project History(With Restore and Download)
- Symbol Palette (Features in Server Pro/SaaS Platform)
- ARM Support(x86_64/arm64 on Docker)

Last but not least, Ayakaleaf Pro is open-source, free to use and modify. You can self-host it and contribute to the development of Ayakaleaf Pro. For more details, please check [Developer Documentation](https://ayakaleaf-pro.ayaka.space/dev) page.

> [!NOTE]
> Note: Ayakaleaf Pro is not affiliated with Overleaf, Inc. or its parent company, Digital Science. It is also *not Server Pro* Edition, which is a commercial product offered by Overleaf, Inc.
> 
> Ayakaleaf Pro is an independent project developed and maintained by the [ayaka-notes](https://github.com/ayaka-notes).

## Installation

If you just want to try Ayakaleaf Pro without setting up a server, you can use our [Ayakaleaf Pro Playground](https://github.com/ayaka-notes/ayakaleaf-pro-playground). It provides a preconfigured GitHub Codespaces environment that lets you launch and explore Ayakaleaf Pro directly in your browser.

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/ayaka-notes/ayakaleaf-pro-playground)

If you want to deploy Ayakaleaf Pro for production use,  we have detailed installation instructions on the [Documents](https://ayakaleaf-pro.ayaka.space/) page. We highly recommend installing Ayakaleaf Pro using the [ayaka-notes/Toolkit](https://github.com/ayaka-notes/toolkit/).

### Building a deployment image with GitHub Actions

The [Build Operations Image](.github/workflows/build_ops_image.yml) workflow builds the all-in-one `linux/amd64` server image on pushes to `server-pro`, or through **Run workflow**. It publishes to `ghcr.io/<owner>/<repository>` (lowercase) using `GITHUB_TOKEN`; no upstream organization token is required. Pull requests build and run the smoke check without publishing.

Images are tagged `sha-<full-commit-sha>`, with `latest` updated for the `server-pro` branch. The workflow summary includes the published digest. Pin `ghcr.io/<owner>/<repository>@sha256:<digest>` in Kubernetes/Argo CD manifests for reproducible deployments and rollbacks. Configure an `imagePullSecret` if the GHCR package is private.

Before publishing, the workflow runs the built image's DockerRunner as `www-data` and compiles a LaTeX document to PDF in a separate container. Deployment still requires MongoDB, Redis, and a Docker daemon plus TeX Live images for sandboxed compiles; the application image does not include a running Docker daemon. The production Dockerfile uses the same Yarn Classic file-mutex configuration as the web image when packing Git dependencies during the build.

### Andromeda / Argo CD

The manifests in `argocd/` use the `ayakaleaf-pro` namespace. The Argo CD application and project are also named `ayakaleaf-pro`; their definitions live in the `argocd` namespace. Bootstrap them with:

```sh
kubectl apply -f argocd/project.yaml -f argocd/ayakaleaf-pro.yaml
```

The project's resource allowlist includes `Pod` and `apps/ReplicaSet` so controller-created children and their logs remain accessible in the Argo CD resource tree.

Argo CD tracks `server-pro:argocd`. Successful operations-image builds commit the new digest there; deployment-only commits do not rebuild the image. A source change during the build skips writeback, and a concurrent branch update rejects the push rather than overwriting it.

This is a single-node deployment at `https://overleaf.geekpie.club`, with privileged DinD for sandboxed compilation. Data and generated secrets persist under `/var/lib/ayakaleaf-pro` on Andromeda. PV/PVC retention is not a backup, declared capacities are not quotas, and `Recreate` upgrades interrupt service.

## Upgrading

If you are upgrading from a previous version of Ayakaleaf Pro, please see the [Releases page](https://github.com/ayaka-notes/overleaf-pro/releases) for the changes in each version between your current version and the one you are upgrading to.

## Translations

We welcome contributions to translations of Ayakaleaf Pro. Generally, we use claude/codex to translate the English text into other languages. If you find any errors in the translations, please submit a pull request to fix them. Please only modify relevant files in the `services/web/locales/locales_patches` folder.

Files under `services/web/locales/` are overleaf official translation files. Please do not modify them directly.

## Contributing

Please see the [CONTRIBUTING](CONTRIBUTING.md) file for information on contributing to the development of Overleaf.

## Blog
We write about Overleaf internals, compilation performance, and self-hosted LaTeX infrastructure. Read more on our blog:
- [2026.08 Overleaf Server Pro Price and Open-Source Alternative](https://ayakaleaf-pro.ayaka.space/blog/2026/overleaf-server-pro-price-and-open-source-alternative)
- [2026.08 Overleaf Benchmark: A Deep Research of Concurrent LaTeX Compilation in Overleaf](https://ayakaleaf-pro.ayaka.space/blog/2026/overleaf-benchmark)

## Authors

- [The Overleaf Team](https://www.overleaf.com/about)
- [Features and Copyright](https://ayakaleaf-pro.ayaka.space/on-premises/readme/features-and-copyright)

## License

The code in this repository is released under the GNU AFFERO GENERAL PUBLIC LICENSE, version 3. A copy can be found in the [`LICENSE`](LICENSE) file.

- Copyright (c) Overleaf, 2014-2025.
- Copyright (c) [Pro Authors](https://ayakaleaf-pro.ayaka.space/on-premises/readme/features-and-copyright), 2026-now.

## Sponsor
- [OpenAI Codex OSS](https://openai.com/en/form/codex-for-oss/)
- [GitBook](https://www.gitbook.com/)

## Star History

<a href="https://www.star-history.com/?repos=ayaka-notes%2Fayakaleaf-pro&type=date&legend=top-left">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=ayaka-notes/ayakaleaf-pro&type=date&theme=dark&legend=top-left&sealed_token=u3l5zBKFPuzl3y_xdCmqTPT_5iaimMLJchJaALvNsAR3LtSu2NrnvjlmbfGW1NdyDch3XLj-o6rfTpyk2K7s6gtgdzDvrDAsTkBnGz_m2CAkbq0IvxsFXPzEkypDT3vhHvYsvDu3qd7Dx6LcPFy_330a0kqmByAl6FKN-13QCGuo1LTv0iEUihWDTUlz" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=ayaka-notes/ayakaleaf-pro&type=date&legend=top-left&sealed_token=u3l5zBKFPuzl3y_xdCmqTPT_5iaimMLJchJaALvNsAR3LtSu2NrnvjlmbfGW1NdyDch3XLj-o6rfTpyk2K7s6gtgdzDvrDAsTkBnGz_m2CAkbq0IvxsFXPzEkypDT3vhHvYsvDu3qd7Dx6LcPFy_330a0kqmByAl6FKN-13QCGuo1LTv0iEUihWDTUlz" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=ayaka-notes/ayakaleaf-pro&type=date&legend=top-left&sealed_token=u3l5zBKFPuzl3y_xdCmqTPT_5iaimMLJchJaALvNsAR3LtSu2NrnvjlmbfGW1NdyDch3XLj-o6rfTpyk2K7s6gtgdzDvrDAsTkBnGz_m2CAkbq0IvxsFXPzEkypDT3vhHvYsvDu3qd7Dx6LcPFy_330a0kqmByAl6FKN-13QCGuo1LTv0iEUihWDTUlz" />
 </picture>
</a>
