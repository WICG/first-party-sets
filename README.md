# First-Party Sets

This document proposes a new web platform mechanism to declare a collection of related domains as
being in a First-Party Set.

A [Work Item](https://privacycg.github.io/charter.html#work-items)
of the [Privacy Community Group](https://privacycg.github.io/).

## Editors:

- [Kaustubha Govind](https://github.com/krgovind), Google
- [David Benjamin](https://github.com/davidben), Google

## Participate
- https://github.com/privacycg/first-party-sets/issues

# Table of Contents

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
- [Introduction](#introduction)
- [Goals](#goals)
- [Non-goals](#non-goals)
- [Applications](#applications)
- [Design details](#design-details)
   - [UA Policy](#ua-policy)
      - [Defining acceptable sets](#defining-acceptable-sets)
      - [Static lists](#static-lists)
      - [Administrative controls](#administrative-controls)
   - [UI Treatment](#ui-treatment)
- [Alternative designs](#alternative-designs)
   - [Origins instead of registrable domains](#origins-instead-of-registrable-domains)
- [Prior Art](#prior-art)
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

# Introduction

Browsers have proposed a variety of tracking policies and privacy models
([Chromium](https://github.com/michaelkleber/privacy-model/blob/master/README.md),
[Edge](https://blogs.windows.com/msedgedev/2019/06/27/tracking-prevention-microsoft-edge-preview/),
[Mozilla](https://wiki.mozilla.org/Security/Anti_tracking_policy),
[WebKit](https://webkit.org/tracking-prevention-policy/)) which scope access to user identity to
some notion of first-party. In defining this scope, we must balance two goals: the scope should be
small enough to meet the user's privacy expectations, yet large enough to provide the user's desired
functionality on the site they are interacting with.

One natural scope is the domain name in the top-level origin. However, the website the user is
interacting with may be deployed across multiple domain names. For example, `https://google.com`,
`https://google.co.uk`, and `https://youtube.com` are owned by the same entity, as are `https://apple.com`
and `https://icloud.com`, or `https://amazon.com` and `https://amazon.de`.

We may wish to allow user identity to span related origins, where consistent with privacy requirements. For
example, Firefox ships an [entity list](https://github.com/mozilla-services/shavar-prod-lists#entity-list)
that defines lists of domains belonging to the same organization. This explainer
discusses a mechanism to allow organizations to each declare their own list of domains, which is 
then accepted by a browser if the set conforms to its policy.


# Goals

-  Allow related domain names to declare themselves as the same first-party.
-  Define a framework for browser policy on which declared names will be treated as the same site 
   in privacy mechanisms.


# Non-goals

-  Third-party sign-in between unrelated sites.
-  Information exchange between unrelated sites for ad targeting or conversion measurement.
-  Other use cases which involve unrelated sites.

(Some of these use cases are covered by [other
explainers](https://www.chromium.org/Home/chromium-privacy/privacy-sandbox) from the Privacy
Sandbox.)

# Applications

In support of the various browser privacy models, web platform features can use first-party sets to
determine whether embedded content may or may not access its own state. For instance,
sites may annotate individual cookies to be sent across same-party, cross-domain contexts by using
the proposed [`SameParty` cookie attribute](https://github.com/cfredric/sameparty). It may also be reasonable to 
use first-party sets to partition network caches, in cases where the tighter origin-based isolation
is too expensive.

Web platform features should _not_ use first-party sets to make one origin's state directly accessible
to another origin in the set. First-party sets should only control when embedded content can access its own state.
That is, if `a.example` and `b.example` are in the same first-party set, the same-origin policy
should still prevent `https://a.example` from accessing `https://b.example`'s IndexedDB databases.
However, it may be reasonable to allow a `https://b.example` iframe within `https://a.example` to
access the `https://b.example` databases.

# Design details

## UA Policy

### Defining acceptable sets

We should have some notion of what sets are acceptable or unacceptable. For instance, a set
containing the entire web, or a collection of completely unrelated sites, seems clearly
unacceptable. Conversely, a set containing `https://acme-corp-landing-page.example` and
`https://acme-corp-online-store.example` seems reasonable. There is a wide spectrum between these
two scenarios. We should define where to draw the line.

Browsers implementing First-Party Sets will specify UA policy for which domains may be in the same set. While 
not required, it is desirable to have some consistency across UA policies. For a set of guiding principles in 
defining UA policy, we can look to how the various browser proposals describe first parties (emphasis
added):

-  [A Potential Privacy Model for the Web (Chromium Privacy Sandbox)](https://github.com/michaelkleber/privacy-model/blob/master/README.md):
   "The notion of "First Party" may expand beyond eTLD+1, e.g. as proposed in First Party Sets. It
   is _reasonable for the browser to relax its identity-sharing controls_ within that expanded
   notion, provided that the resulting identity scope is _not too large_ and _can be understood by
   the user_."
-  [Edge Tracking Protection Preview](https://blogs.windows.com/msedgedev/2019/06/27/tracking-prevention-microsoft-edge-preview/):
   "Not all organizations do business on the internet using just one domain name. In order to help
   keep sites working smoothly, we group domains _owned and operated by the same organization_
   together."
-  [Mozilla Anti-Tracking Policy](https://wiki.mozilla.org/Security/Anti_tracking_policy): "A
   first party is a resource or a set of resources on the web _operated by the same organization_,
   which is both _easily discoverable by the user_ and _with which the user intends to interact_."
-  [WebKit Tracking Prevention Policy](https://webkit.org/tracking-prevention-policy/): "A first
   party is a website that a user is intentionally and knowingly visiting, as displayed by the URL
   field of the browser, and the set of resources on the web _operated by the same organization_."
   and, under "Unintended Impact", "Single sign-on to multiple websites _controlled by the same
   organization_."

We expect the UA policies to evolve over time as use cases and abuse scenarios come up. For instance, 
otherwise unrelated sites forming a consortium in order to expand the scope of their site identities 
would be considered abuse. 

Given the UA policy, policy decisions must be delivered to the user’s browser. 
This can use either static lists or signed assertions. Note first-party set membership requires being 
listed in the manifest in addition to meeting UA policy. This allows sites to quickly remove domains from 
their first-party set.

### Static lists

The browser vendor could maintain a list of domains which meet its UA policy, and ship it in the browser. 
This is analogous to the list of [domains owned by the same entity](https://github.com/disconnectme/disconnect-tracking-protection/blob/master/entities.json) used by Edge and Firefox to control 
cross-site tracking mitigations.

A browser using such a list would then intersect first-party set manifests with the list. It would ignore 
the assertions field in the manifest. Note fetching the manifest is still necessary to ensure the site opts 
into being a set. This avoids problems if, say, a domain was transferred to another entity and the static list 
is out of date.

Static lists are easy to reason about and easy for others to inspect. At the same time, they can develop 
deployment and scalability issues. Changes to the list must be pushed to each user's browser via some update 
mechanism. This complicates sites' ability to deploy new related domains, particularly in markets where 
network connectivity limits update frequency. They also scale poorly if the list gets too large.

### Administrative controls

For enterprise usages, browsers typically offer administrators options to control web platform behavior. UA policy 
is unlikely to cover private domains, so browsers might expose administrative options for locally-defined 
first-party sets.

## UI Treatment

In order to provide transparency to users regarding the First-Party Set that a web page’s top-level 
domain belongs to, browsers may choose to present UI with information about the First-Party Set owner 
and the members list. One potential location in Chrome is the [Origin/Page Info Bubble](https://www.chromium.org/Home/chromium-security/enamel/goals-for-the-origin-info-bubble) - this 
provides requisite information to discerning users, while avoiding the use of valuable screen 
real-estate or presenting confusing permission prompts. However, browsers are free to choose different
presentation based on their UI patterns, or adjust as informed by user research.

Note that First-Party Sets also gives browsers the opportunity to group per-site controls (such as 
those at `chrome://settings/content/all`) by the “first-party” boundary instead of eTLD+1, which is 
not always the correct site boundary.

# Alternative designs

## Origins instead of registrable domains

A first-party set is a collection of origins, but it is specified by registrable domains, which
carries a dependency on the [public suffix list](https://publicsuffix.org). While this is consistent
with the various proposed privacy models as well as cookie handling, the security boundary on the
web is the origin, not registrable domain.

An alternate design would be to instead specify sets by origins directly. In this model, any https
origin would be a possible first-party set owner, and each origin must individually join a set,
rather than relying on the root as we do here. For continuity with the existing behavior, we would
then define the registrable domain as the default first-party set for each origin. That is, by
default, `https://foo.example.com`, `https://bar.example.com`, and `https://example.com:444` would all be
in a set owned by `https://example.com`. Defining a set explicitly would override this default set.

This would reduce the web's dependency on the public suffix list, which would mitigate [various
problems](https://github.com/sleevi/psl-problems). For instance, a university may allow students to register arbitrary subdomains at
`https://foo.university.example`, but did not place `university.example` on the public suffix list,
either due to compatibility concerns or oversight. With an origin-specified first-party set,
individual origins could then detach themselves from the default set to avoid security problems with
non-origin-based features such as cookies. (Note the
[\_\_Host- cookie prefix](https://tools.ietf.org/html/draft-ietf-httpbis-rfc6265bis-03#section-4.1.3.2)
also addresses this issue.)

This origin-defined approach has additional complications to resolve:

-  There are a handful of features (cookies, document.domain) which are scoped to registrable
   domains, not origins. Those features should not transitively join two different sets. For
   instance, we must account for one set containing `https://foo.bar.example.com` and
   `https://example.com`, but not `https://bar.example.com`. For cookies, we can say that cookies
   remember the set which created them and we match both the Domain attribute and the first-party
   set. Thus if `https://foo.bar.example.com` sets a Domain=example.com cookie, `https://example.com`
   can read it, but not `https://bar.example.com`. Other features would need similar updates.
-  The implicit state should be expressible explicitly, to simplify rollback and deployment,
   which means first-party set manifests must describe patterns of origins, rather than a simple
   bounded list of domains. In particular, we should support subtree patterns.
-  `https://foo.example.com`'s implicit owner is `https://example.com`. If `https://example.com` then
   forms an explicit set which does not include `https://foo.example.com`, we need to change
   `https://foo.example.com`'s implicit state, perhaps to a singleton set.
-  This complex set of patterns and implicit behaviors must be reevaluated against existing
   origins every time a first-party set is updated.
-  Certificate wildcards (which themselves depend on the public suffix list) don't match an
   entire subtree. This conflicts with wanting to express implicit states above.

These complexities are likely solvable while keeping most of this design, should browsers believe
this is worthwhile.

# Prior Art

-  Firefox's [entity list](https://github.com/mozilla-services/shavar-prod-lists#entity-list)
-  [draft-sullivan-dbound-problem-statement-02](https://tools.ietf.org/html/draft-sullivan-dbound-problem-statement-02)
-  [Single Trust and Same-Origin Policy v2](https://lists.w3.org/Archives/Public/public-webappsec/2017Mar/0034.html)
   and [affiliated domains](https://www.w3.org/2017/11/06-webappsec-minutes.html#item12) from John
   Wilander to public-webappsec
