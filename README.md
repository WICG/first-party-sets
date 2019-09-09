# First-Party Sets

This document proposes a new web platform mechanism to declare a collection of related domains as
being in a First-Party Set.

# Table of Contents

- [Introduction](#introduction)
- [Goals](#goals)
- [Non-goals](#non-goals)
- [Declaring a First Party Set](#declaring-a-first-party-set)
- [Applications](#applications)
- [Design details](#design-details)
   - [Acceptable and unacceptable sets](#acceptable-and-unacceptable-sets)
      - [Defining acceptable sets](#defining-acceptable-sets)
      - [Mitigating unacceptable sets](#mitigating-unacceptable-sets)
      - [Detecting unacceptable sets](#detecting-unacceptable-sets)
   - [Cross-site tracking vectors](#cross-site-tracking-vectors)
   - [Service workers](#service-workers)
- [Alternative designs](#alternative-designs)
   - [Using a static list](#using-a-static-list)
   - [Origins instead of registrable domains](#origins-instead-of-registrable-domains)
- [Prior Art](#prior-art)

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

We may wish to include these kinds of related names, where consistent with privacy requirements. For
example, Firefox [ships](https://github.com/mozilla-services/shavar-prod-lists#entity-list) an
entity list that defines lists of domains belonging to the same organization. This explainer
discusses a dynamic mechanism for defining these lists, which trades off the [costs of a static
list](#using-a-static-list) with [other considerations](#design-details).

# Goals

-  Allow related domain names to declare themselves as the same first-party.
-  Provide a scalable and maintainable web platform mechanism to achieve the above, and thus
   avoid a hard-coded list.

# Non-goals

-  Third-party sign-in between unrelated sites.
-  Information exchange between unrelated sites for ad targeting or conversion measurement.
-  Other use cases which involve unrelated sites.

(Some of these use cases are covered by [other
explainers](https://www.chromium.org/Home/chromium-privacy/privacy-sandbox) from the Privacy
Sandbox.)

# Declaring a First Party Set

A first-party set is identified by one _owner_ registered domain and a list of _secondary_
registered domains. (See [alternative designs](#alternative-designs) for a discussion of origins
vs registered domains.)

An origin is in the first-party set if:

-  Its scheme is https; and
-  Its registered domain is either the owner or is one of the secondary domains.

The owner and each secondary domain in a first-party set hosts a first-party set manifest at
`https://<domain>/.well-known/first-party-set`, containing a JSON dictionary. The secondary domains
point to the owning domain while the owning domain lists the members of the set, as well as a
version number to trigger updates.

Suppose `a.example`, `b.example`, and `c.example` wish to form a first-party set, owned by `a.example`. The
sites would then serve the following resources:

```
https://a.example/.well-known/first-party-set
{ "owner": "a.example",
  "version": 1,
  "members": ["b.example", "c.example"] }

https://b.example/.well-known/first-party-set
{ "owner": "a.example" }

https://c.example/.well-known/first-party-set
{ "owner": "a.example" }
```

We then impose additional constraints on the owner's manifest:

-  Entries in `members` that are not registrable domains are ignored.
-  To mitigate unacceptable sets, if the number of entries in `members` must not exceed some
   limit, reject the entire manifest. As to the size of the limit, the largest entry in the Firefox
   entity list is around 200 domains (due to ccTLDs), although a tighter limit below 20-30 would
   much more effectively limit the scope. Per Chromium's
   [document](https://github.com/michaelkleber/privacy-model#identity-is-partitioned-by-first-party-site),
   one of the criteria is that "the resulting identity scope is not too large".
-  All domains in the set must be covered by the same X.509 certificate.

By default, every registrable domain is implicitly owned by itself. The browser discovers
first-party sets as it makes network requests and stores the first-party set owner for each domain.
On a top-level navigation, websites may send a `Sec-First-Party-Set` response header to inform the
browser of its first-party set owner. For example `https://b.example/some/page` may send the following
header:

```
  Sec-First-Party-Set: owner="a.example", minVersion=1
```

If this header does not match the browser's current information for `b.example` (either the owner does
not match, or its saved first-party set manifest is too old), the browser pauses navigation to fetch
the two manifest resources. Here, it would fetch `https://a.example/.well-known/first-party-set` and
`https://b.example/.well-known/first-party-set`.

These requests must be uncredentialed and with suitably partitioned network caches to not leak
cross-site information. In particular, the fetch must not share caches with browsing activity under
`a.example`. See also discussion on [cross-site tracking vectors](#cross-site-tracking-vectors).

If the manifests show the domain is in the set, the browser records `a.example` as the owner of
`b.example` (but not `c.example`) in its first-party-set storage. It evicts all domains currently
recorded as owned by `a.example` that no longer match the new manifest. Then it clears all state for
domains whose owners changed, including reloading all active documents. This should behave like
[`Clear-Site-Data: *`](https://www.w3.org/TR/clear-site-data/). This is needed to unlink any site
identities that should no longer be linked. Note this also means that execution contexts (documents,
workers, etc.) are scoped to a particular first-party set throughout their lifetime. If the
first-party owner changes, existing ones are destroyed.

The browser then retries the request (state has since been cleared) and completes navigation. As
retrying POSTs is undesirable, we should ignore the `Sec-First-Party-Set` header directives on POST
navigations. Sites that require a first-party set to be picked up on POST navigations should perform
a redirect (as is already common), and have the `Sec-First-Party-Set` directive apply on the
redirect.

Subresource requests and subframe navigations are simpler as they cannot introduce a new first-party
context. If the request matches the first-party URL's owner's manifest but is not currently recorded
as being in that first-party set, the browser validates membership as above before making the
request. Any Sec-First-Party-Set headers are ignored and, in particular, the browser should never
read or write state for a first-party set other than the current one. This simpler process also
avoids questions of retrying requests. The minVersion parameter in the header ensures that the
browser's view of the owner's manifest is up-to-date enough for this logic.

# Applications

In support of the various browser privacy models, web platform features can use first-party sets to
determine whether embedded content may or may not access its own state. For instance,
[draft-west-cookie-samesite-firstparty-01](https://tools.ietf.org/html/draft-west-cookie-samesite-firstparty-01)
describes a SameSite cookie attribute that sites may use to opt individual cookies in to relaxed
variants of `SameSite=Strict` and `SameSite=Lax`: `SameSite=FirstPartySetStrict` and
`SameSite=FirstPartySetLax`. It may also be reasonable to use first-party sets to partition network
caches, in cases where the tighter origin-based isolation is too expensive.

Web platform features should _not_ use first-party sets make one origin's state directly accessible
to another origin in the set. It should only control when embedded content can access its own state.
That is, if `a.example` and `b.example` are in the same first-party set, the same-origin policy
should still prevent `https://a.example` from accessing `https://b.example`'s IndexedDB databases.
However, it may be reasonable to allow a `https://b.example` iframe within `https://a.example` to
access the `https://b.example` databases.

# Design details

## Acceptable and unacceptable sets

### Defining acceptable sets

We should have some notion of what sets are acceptable or unacceptable. For instance, a set
containing the entire web, or a collection of completely unrelated sites, seems clearly
unacceptable. Conversely, a set containing `https://acme-corp-landing-page.example` and
`https://acme-corp-online-store.example` seems reasonable. There is a wide spectrum between these
two scenarios. We should define where to draw the line.

Exactly how to define this is an open question to be discussed. For an initial set of principles, we
can look to how the various browser proposals say the following about first parties (emphasis
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

This definition should also consider scenarios such as otherwise unrelated sites forming a
consortium in order to expand the scope of their site identities.

### Mitigating unacceptable sets

This proposal includes technical measures which limit which first-party sets may be formed. First,
first-party sets require opt-in from all parties. This means one origin cannot form a set
unilaterally without opt-in from other members. Second, manifest sizes are bounded, which limits the
number of unrelated domains which may be in an unacceptable first-party set. Finally, we apply a
certificate constraint, which correlates first-party sets with technical control of the domain
names.

However, it is important to emphasize that these technical measures are not sufficient to exclude
unacceptable sets. While we have not defined a criteria above, the initial principles above are
tighter than the technical measures. First, while we bound first-party sets sizes, there are many
ccTLDs. If we decide `https://example.com`, `https://example.co.uk`, etc., are in scope, the limit may
end up fairly generous. Second, certificates only validate technical control of a domain name. CDNs
and hosting providers often legitimately acquire a single certificate covering multiple names that
they host. The names may not be operated by the same organization or have a relationship meaningful
to the user.

Thus these technical measures are only a first-pass filter on unacceptable sets. The browser still
must apply interventions to unacceptable sets. This may be done by
[detecting](#detecting-unacceptable-sets) and maintaining a list of blocked first-party owners, as in
[Google Safe Browsing](https://safebrowsing.google.com). All first-party sets whose owners appear on
the list are ignored and, if already present, cleared. This will change the set owner and trigger
state clearing. This repairs the inconsistency with the privacy model, as well as disincentivizes
sites from participating in unacceptable first-party sets. Note also this state clearing means sites
cannot cycle between different sets to get around size limitations.

### Detecting unacceptable sets

Maintaining a blocklist requires the browser monitor and detect unacceptable sets. Some possible
strategies:

-  Such sets will likely center on popular sites, which simplifies the monitoring.
-  The certificate constraint causes sets to leave evidence in certificate transparency logs,
   which provides some degree of auditability. Note this is imperfect because giant CDN
   certificates may contain many names but not be used for a first-party set.
-  First-party set ownership can be monitored by monitoring the /.well-known/first-party-set
   resource for various sites. Servers could attempt to defeat this by using cloaking techniques to
   serve different sets to different monitors and users, but this can be helped by general measures
   to reduce fingerprinting, and by first-party-set-specific measures to avoid personalized sets
   (credentialless fetches, partitioning network state, etc.).

## Cross-site tracking vectors

This design requires the browser remember state about first-party sets, and use that state to
influence site behavior. We must ensure this state does not introduce a cross-site tracking vector
for two sites _not_ in the same first-party set. For instance, a site may be able to somehow encode
a user identifier into the first-party set and have that identifier be readable in another site.
Additionally, first-party sets are discovered and validated on-demand, so this could leak
information about which sites have been visited.

Our primary mitigation for these attacks is to treat first-party sets as first-party-only state. We
heavily restrict how first-party set state interacts with subresources. Thus we never query or write
to first-party set information for any set other than the current one. Even if first-party set
membership were personalized, that membership should only influence the set itself.

We can further mitigate personalized first-party sets, as well as information leaks during
validation, by fetching manifests without credentials and from appropriate network partitions
(double-keyed HTTP cache, etc.).

Finally, first-party set state must be cleared whenever other state for some first-party is cleared,
such as if the user cleared cookies from the browser UI.

Some additional scenarios to keep in mind:

-  The decision to validate a first-party set must not be based on not-yet-readable data,
   otherwise side channel attacks are feasible. For instance, we cannot optimize the subresource
   logic to only validate sets if a `SameSite=FirstPartyLax` cookie exists.
-  When validating a first-party set from a top-level navigation, it is important to fetch _both_
   manifests unconditionally, rather than use the cached version of the owner manifest. Otherwise
   one site can learn if the user has visited the other by claiming to be in a first-party set and
   measuring how long the browser took to reject it.
-  If two first-party sets jointly own a set of "throwaway" domains (so state clearing does not
   matter), they can communicate a user identifier in which throwaway domains one set grabs from
   the other. This is partially addressed by mitigating personalized first-party sets (if not
   personalized, the sites must coordinate via a global signal like time). Beyond that, this can be
   addressed by mitigations against unacceptable sets in general (a domain that can be part of two
   sets is clearly unacceptable). See further discussion below.

## Service workers

Service workers complicate first-party sets. We must consider network requests made from a service
worker, subresource fetches made from a document with a service worker attached, as well as how a
site which uses a service worker may adopt first-party sets.

Changing a domain's first-party owner clears all state, including service worker registrations. This
means service workers, like documents, are scoped to a given first-party set. Network requests from
a service worker then behave like subresources.

If a document has a service worker attached, its subresource fetches go through the service worker.
This does _not_ trigger first-party set logic as this fetch is, at this point, a funny IPC. If the
service worker makes a request in response, the first-party set logic will fire as above.

Finally, if a site already has a service worker, it should still be able to deploy first-party sets.
However that service worker effectively translates navigation fetches into subresource fetches, and
only top-level navigations discover new sets. We resolve this by moving `Sec-Fetch-Party-Set` header
processing to the navigation logic. If the header is present, whether it came from the network
directly or the service worker, we attempt to validate the set. This is fine because the header is
not directly trusted.

# Alternative designs

## Using a static list

The immediate alternate design is to use a static list, such as Firefox's [entity
list](https://github.com/mozilla-services/shavar-prod-lists#entity-list). A static list has several
advantages. It is much simpler: it does not require mechanisms for the set changing, and there is no
need to monitor unacceptable sets. A browser can more directly impose its policy on what kinds of
sets are and are not acceptable.

At the same time, hardcoded lists can develop availability and deployment issues. First, each change
must be propagated to each user's browser via an update. This complicates sites' ability to deploy
new related domains. In comparison, the HSTS preload list is only a hardening measure around a
[dynamic HTTP header](https://tools.ietf.org/html/rfc6797), so sites can deploy HSTS unilaterally. 
Relatedly, each browser also becomes a gatekeeper for these new domains. This produces an
[internet choke point](https://intarchboard.github.io/chokepoints/draft-iab-chokepoints-latest.html).
Finally, as preload lists grow, they can also develop scalability issues, as in the [HSTS preload
list](https://bugs.chromium.org/p/chromium/issues/detail?id=587954).

This dynamic design avoids these concerns. It is worth noting, however, that the design does not
remove the need for browsers to apply policies. Browsers still must mitigate unacceptable sets. The
design only removes the browser from the critical path in deploying new entries.

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
-  The patterns also make the meaning of the size limit unclear.
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
