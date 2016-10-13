[![Build Status](https://travis-ci.org/csc/Hanlon.svg?branch=master)](https://travis-ci.org/csc/Hanlon)

# Project Hanlon (v3.0.1)

[![Join the chat at https://gitter.im/csc/Hanlon](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/csc/Hanlon?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

## Introduction

Project Hanlon is a power control, provisioning, and management application
designed to deploy both bare-metal and virtual computer resources. Hanlon
provides broker plugins for integration with third party such as Puppet.

Hanlon started its life as Razor so you may encounter links to original
created-for-Razor content.  The following links, for example, provide
background info about the project:

* Razor Overview: [Nickapedia.com](http://nickapedia.com/2012/05/21/lex-parsimoniae-cloud-provisioning-with-a-razor)
* Razor Session from PuppetConf 2012: [Youtube](http://www.youtube.com/watch?v=cR1bOg0IU5U)

Project Hanlon is versioned with [semantic versioning][semver], and we follow
the precepts of that document.

## How to Get Help

We really want Hanlon to be simple to contribute to, and to ensure that you can
get started quickly.  A big part of that is being available to help you figure
out the right way to solve a problem, and to make sure you get up to
speed quickly.

You can always reach out and ask for help by email or through the web on the [hanlon-project@googlegroups.com][hanlon-project]
  mailing list.  (membership is required to post.)  

If you want to help improve Hanlon directly we have a
[fairly detailed CONTRIBUTING guide in the repository][contrib] that you can
use to understand how code gets in to the system, how the project runs, and
how to make changes yourself.

We welcome contributions at all levels, including working strictly on our
documentation, tests, or code contributions.  We also welcome, and value,
input about your experiences with Project Hanlon, and provisioning in general,
on the mailing list as we discuss how the project might solve these sorts of
problems.


## Installation  

Follow wiki documentation for [Installation Overview](https://github.com/csc/Hanlon/wiki/Installation-%28Overview%29)


## Project Committers

This is the official list of users with "committer" rights to the
Hanlon project.  For details on what that means, see the [CONTRIBUTING][contrib]
guide in the repository.

Please reach out to <opensource@csc.com> if you have any questions about the project.

## Hanlon MicroKernel

Hanlon uses an associated Hanlon-Microkernel instance to discover new nodes.
Pre-build (Docker) images of the current Hanlon-Microkernel (v3.0.0) are officially
available via DockerHub at `cscdock/hanlon-microkernel`. You can also find the
original source code that went into this release in the releases area of the
Hanlon-Microkernel project, [here](https://github.com/csc/Hanlon-Microkernel/releases/tag/v3.0.0).

Finally, you can find more information on the Microkernel and on the process
for building your own Microkernel images at the Hanlon MicroKernel project page:

[https://github.com/csc/Hanlon-Microkernel](https://github.com/csc/Hanlon-Microkernel)

## License

Project Hanlon is distributed under the Apache 2.0 license.
See [the LICENSE file][license] for full details.

## Reference

The following links contain useful information on the Hanlon (and Hanlon-Microkernel) projects
as well as information on the new CSC Open Source Program:

* Tom McSweeney's blog entry on the availability of this project:
[Announcing Hanlon and the Hanlon-Microkernel](http://osclouds.wordpress.com/?p=2)
* Dan Hushon's blog entry on the new CSC Open Source Program:
[Finding Value in Open Source](http://www.vdatacloud.com/blogs/2014/05/22/finding-value-in-opensource/)
* A blog posting by Tom McSweeney describing the changes that went into the
[Hanlon 2.0 Release](https://osclouds.wordpress.com/2014/10/31/announcing-the-release-of-hanlon-v2-0/)
in October, 2014
* Tom's blog entry from March, 2015 announcing support for Windows provisioning in Hanlon
([Hanlon does Windows!](https://osclouds.wordpress.com/2015/03/05/hanlon-does-windows)) along with the
associated [screencast](http://bit.ly/1B7VfGM) by Tom demonstrating this Windows support

Finally, these links provide an introduction to the original Razor project
(and, given Hanlon's roots in the original Razor project, they may be of
interest to those new to the Razor/Hanlon community):

* The original Razor Overview posting: [Nickapedia.com](http://nickapedia.com/2012/05/21/lex-parsimoniae-cloud-provisioning-with-a-razor)
* A video of Nick Weaver's Razor Session from PuppetConf 2012: [Youtube](http://www.youtube.com/watch?v=cR1bOg0IU5U)
* The original posting by Nan Liu describing the first Puppet Labs Razor Module:
[Puppetlabs.com](http://puppetlabs.com/blog/introducing-razor-a-next-generation-provisioning-solution/)

Even though the Puppet Labs module described in the last link is no longer maintained, and
even though it doesn't support Hanlon, we included it here because we felt that the information
in that blog posting may provide useful to those who would like to develop a corresponding
Hanlon module.


[hanlon-project]: https://groups.google.com/d/forum/hanlon-project
[contrib]:      CONTRIBUTING.md
[license]:      LICENSE
[semver]:       http://semver.org/
