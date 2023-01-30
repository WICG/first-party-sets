# First-Party Sets

This document proposes a new web platform mechanism to declare a collection of related domains as
being in a First-Party Set.

## Editors:

- [Kaustubha Govind](https://github.com/krgovind), Google
- [Johann Hofmann](https://github.com/johannhof), Google

## Participate
- https://github.com/privacycg/first-party-sets/issues

# Table of Contents

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Introduction](#introduction)
- [Goals](#goals)
- [Non-goals](#non-goals)
- [Use Cases](#use-cases)
- [Proposal](#proposal)
  - [Defining a "set" through use case-based "subsets"](#defining-a-set-through-use-case-based-subsets)
    - [Abuse mitigation measures](#abuse-mitigation-measures)
  - [Leveraging the Storage Access API](#leveraging-the-storage-access-api)
    - [Providing capabilities beyond the Storage Access API](#providing-capabilities-beyond-the-storage-access-api)
  - [Administrative controls](#administrative-controls)
- [UI Treatment](#ui-treatment)
- [Domain Schemes](#domain-schemes)
- [Clearing Site Data on Set Transitions](#clearing-site-data-on-set-transitions)
  - [Examples](#examples)
- [Alternative designs](#alternative-designs)
  - [Synchronous cross-site cookie access within same-party contexts](#synchronous-cross-site-cookie-access-within-same-party-contexts)
  - [Signed Assertions and set discovery instead of static lists](#signed-assertions-and-set-discovery-instead-of-static-lists)
  - [Using EV Certificate information for dynamic verification of sets](#using-ev-certificate-information-for-dynamic-verification-of-sets)
  - [Self-attestation and technical enforcement](#self-attestation-and-technical-enforcement)
  - [Origins instead of registrable domains](#origins-instead-of-registrable-domains)
- [Security and Privacy Considerations](#security-and-privacy-considerations)
  - [Avoid weakening new and existing security boundaries](#avoid-weakening-new-and-existing-security-boundaries)
- [Prior Art](#prior-art)
- [Open question(s)](#open-questions)
- [Acknowledgements](#acknowledgements)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Introduction

Browsers have proposed a variety of tracking policies and privacy models
([Chromium](https://github.com/michaelkleber/privacy-model/blob/master/README.md),
[Edge](https://blogs.windows.com/msedgedev/2019/06/27/tracking-prevention-microsoft-edge-preview/),
[Mozilla](https://wiki.mozilla.org/Security/Anti_tracking_policy),
[WebKit](https://webkit.org/tracking-prevention-policy/)) which scope access to user identity to
some notion of first-party. In defining this scope, we must balance two goals: the scope should be
small enough to meet the user's privacy expectations, yet large enough to provide the user's desired
functionality on the site they are interacting with.

First-Party Sets (FPS) is a web platform mechanism, proposed within the context of browser efforts to phase out support for third-party cookies, through which site authors of multi-domain sites may declare relationships between domains such that the browser may understand the relationships and handle cookie access accordingly.

The core principle of allowing browsers to treat collections of *known related sites* differently from otherwise *unrelated sites* is grounded in ideas that had been previously discussed in the W3C (such as [Affiliated Domains](https://www.w3.org/2017/11/06-webappsec-minutes.html#item12)), the now defunct IETF [DBOUND](https://datatracker.ietf.org/doc/html/draft-sullivan-dbound-problem-statement-02) working group, and previously deployed in some browsers (such as the [Disconnect.me entities list](https://github.com/disconnectme/disconnect-tracking-protection/blob/master/entities.json)).

There are two key components to the proposal:

-   The framework governing how relationships between domains may be declared, and
-   The method by which the browser may manage cross-domain cookie access based on the declared relationship between domains.


# Goals

-  Allow for browsers to understand the relationships between domains of multi-domain sites such that they can make decisions on behalf of the user and/or effectively present that information to the user.
-  Uphold existing web security principles such as the [Same Origin Policy](https://developer.mozilla.org/en-US/docs/Web/Security/Same-origin_policy).


# Non-goals

-  Expansion of capabilities beyond what is possible without recent browser-imposed privacy mitigations such as restrictions on third party cookies or cache partitioning.
-  Third-party sign-in between unrelated sites.
-  Information exchange between unrelated sites for ad targeting or conversion measurement.
-  Other use cases which involve unrelated sites.
-  Define specific UI treatment.

(Some of these use cases are covered by [other
explainers](https://privacysandbox.com/intl/en_us/open-web/#proposals-for-the-web) from the Privacy
Sandbox.)

# Use Cases

On the modern web, sites span multiple domains and many sites are owned & operated by the same organization. Organizations may want to maintain different top-level domains for:

-   App domains - a single application may be deployed over multiple domains, where the user may seamlessly navigate between them as a single session.
    -   office.com, live.com, microsoft.com ([reference](https://github.com/privacycg/first-party-sets/issues/35#issue-810396040))
    -   lucidchart.com, lucid.co, lucidspark.com, lucid.app ([reference](https://github.com/privacycg/first-party-sets/issues/19#issuecomment-769277058))
-   Brand domains
    -   uber.com, ubereats.com
-   Country-specific domains to enable localization 
    -   google.co.in, google.co.uk
-   Sandbox domains that users never directly interact with, but exist to isolate user-uploaded content for security reasons. 
    -   google.com, googleusercontent.com
    -   github.com, githubusercontent.com
-   Service domains that users never directly interact with, but provide services across the same organization’s sites. 
        -   github.com, githubassets.com
        -   facebook.com, fbcdn.net

**Note:** The above have been provided only to serve as real-world illustrative assumed examples of collections of domains that are owned by the same organization; and have not all been validated with the site owners.

This proposal anchors on the use cases described above to develop a framework for the browser to support limited cross-domain cookie access. This will allow browsers to ensure continued operation of existing functionality that would otherwise be broken by blocking cross-domain cookies ("third-party cookies"), and will support the seamless operation of functionality such as:



-   Sign-in across owned & operated properties 
    -   bbc.com and bbc.co.uk
        -   Websites may also consider using the FedCM API for single sign-on functionality, if the relevant login flows can be encapsulated with the API's supported [use cases](https://fedidcg.github.io/FedCM/#use-cases).
    -   sony.com and playstation.com
-   Support for embedded content from across owned & operated properties (e.g. videos/documents/resources restricted to the user signed in on the top-level site)
-   Separation of user-uploaded content from other site content for security reasons, while allowing the sandboxed domain access to authentication (and other) cookies. For example, Google sequesters such content on googleusercontent.com, GitHub on githubusercontent.com, CodePen [on](https://blog.codepen.io/2019/10/03/changed-domains-for-iframe-previews/) cdpn.io. Hosting untrusted, compromised content on the same domain where a user is authenticated may result in attackers’ potentially capturing authentication cookies, or login credentials (in case of password managers that scope credentials to domains); and cause harm to users.
    -   Alternative solution: Sandboxed domains can also consider using [partitioned cookies](https://github.com/WICG/CHIPS), if their user flows do not involve the sandboxed domain appearing in top-level contexts.
-   Analytics/measurement of user journeys across O&O properties to improve quality of services.

# Proposal

At a high level, a First-Party Set is a collection of domains, for which there is a single "set primary" and potentially multiple "set members." Only site authors will be able to submit their own set, and they will be required to declare the relationship between each "set member" to its "set primary." This declaration will be grounded in the [use cases](#heading=h.4t8m5gy1pn0r) described above and defined by "subsets."

## Defining a "set" through use case-based "subsets"

Throughout the evolution of this proposal, we considered how to define a single boundary that could determine set inclusion. However, formulating a definition or set of criteria that can both acknowledge the complex multi-domain dependence of websites and preserve a limited privacy boundary proved to be challenging. Instead of using a single definition or set of criteria to apply to a range of [use cases](#use-cases), we propose granular criteria and handling to be applied by use case by specifying "subsets."

At time of submission, "set primaries" and "set members" will be declared. Set members could include a range of different domain types, matching up to the different types of use cases (or *subsets*) such as domains that users never directly interact with, like service or sandbox domains; and domains where users may benefit from a seamless session, like brand or app domains.

We propose enumerating the range of applicable subsets within a set (beginning with subsets that correlate to the [use cases described above](#use-cases)), requiring that a member domain must meet the definition of a single subset to be part of the set. For example, consider the following table as an example First-Party Sets schema:

**Set primary:** exampleA.com

<table>
  <thead>
    <tr>
      <th><br>
<strong>Subset type</strong></th>
      <th><br>
<strong>Subset definition</strong></th>
      <th><br>
<strong>Example</strong></th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><br>
service</td>
      <td><br>
Reserved for utility or sandbox domains.<br>
<br>
<br>
<em>Requires common ownership.</em></td>
      <td><br>
exampleA-usercontent.com<br>
<br>
exampleA-cdn.net</td>
    </tr>
    <tr>
      <td><br>
associated</td>
      <td><br>
Reserved for domains whose affiliation with the set primary is clearly presented to users (e.g., an About page, header or footer, shared branding or logo, or similar forms).</td>
      <td><br>
exampleA-affiliated.com<br>
<br>
exampleB.com*<br>
<br>
exampleC.com*<br>
<br>
<br>
*where exampleB and exampleC are separately owned websites, but clearly present their affiliation with exampleA to users</td>
    </tr>
  </tbody>
</table>

While we think this subset framework has the clear benefit of furthering transparency around why a domain has been added to a set, the primary value to this framework is that the browser could handle each subset differently:

<table>
  <thead>
    <tr>
      <th><strong>Subset type</strong></th>
      <th><strong>Subset definition</strong></th>
      <th><strong>Example browser handling policy</strong></th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>service</td>
      <td>Reserved for utility or sandbox domains.<br>
<br>
Requires common ownership.</td>
      <td>No limit on domains, auto-grant access. Not allowed to be the top-level domain in a storage access grant.</td>
    </tr>
    <tr>
      <td>associated</td>
      <td>Reserved for domains whose affiliation with the set primary is clearly presented to users (e.g., an About page, header or footer, shared branding or logo, or similar forms).</td>
      <td>Limit of 3* domains. If greater than 3, auto-reject access.<br>
<br>
<em>*[^1]exact number TBD</em></a></td>
    </tr>
  </tbody>
</table>

In addition to the subsets proposed above, we propose a mechanism by which a set can declare ccTLD (country code top-level domain) variants of domains in the same set.

<table>
  <thead>
    <tr>
      <th><strong>Definition</strong></th>
      <th><strong>Example</strong></th>
      <th><strong>Example browser handling policy</strong></th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Reserved for variations for a particular country or a geographical area.<br><br>Requires common ownership with the domain it is the variant of.</td>
      <td>exampleA.co.uk<br><br>exampleA.ca</td>
      <td>No limit on number of ccTLDs.<br><br>Inherits browser handling policy of the equivalent domain.</td>
    </tr>
  </tbody>
</table>

For example, `exampleA.co.uk` could be considered a ccTLD variant of `exampleA.com`. If `exampleB.com` and `exampleC.com` are listed in the associated subset, the inclusion of `exampleB.co.uk` and `exampleC.co.uk` as ccTLD variants (of `exampleB.com` and `exampleC.com`, respectively) would *not* count against the limit on the number of associated domains, and would be allowed.

### Abuse mitigation measures

We consider using a public submission process (like a GitHub repository) to be a valuable approach because it facilitates our goal to keep all set submissions public and submitters accountable to users, civil society, and the broader web ecosystem. For example, a mechanism to report potentially invalid sets may be provisioned. We expect public accountability to be a significant deterrent for intentionally miscategorized subsets.

The following technical checks also help to mitigate abuse:

-   Mutual exclusivity to ensure a domain isn't part of multiple First-Party Sets
-   `.well-known` file check on all domains to ensure authorized submissions
-   Check against the [Public Suffix List](https://publicsuffix.org/) to ensure that sets are composed of valid registrable domains

Additionally, there are other enforcement strategies we could consider to further mitigate abuse. If there is a report regarding a domain specified under the "service" subset, potential reactive enforcement measures could be taken to validate that the domain in question is indeed a "service" subset.

For some subsets, like the "associated" subset, objective enforcement may be much more difficult and complex. In these situations, the browser's handling policy, such as a limit of three domains, should limit the scope of potential abuse. Additionally, we think that site authors will be beholden to the subset definition and avoid intentional miscategorization as their submissions would be entirely public and constitute an assertion of the relationship between domains.

## Chrome’s Submission Guidelines and FPS Canonical List

Chrome’s implementation will depend on the  list of First-Party Sets generated via the process described in [Submission Guidelines](https://github.com/GoogleChrome/first-party-sets/blob/main/FPS-Submission_Guidelines.md). The guidelines aim to provide developers with clear expectations on how to submit sets to the [canonical list](https://github.com/GoogleChrome/first-party-sets/blob/main/first_party_sets.JSON) that the browser will consume and apply to its behavior. 

## Leveraging the Storage Access API

To facilitate the browser's ability to handle each subset differently, we are proposing leveraging the [Storage Access API](https://privacycg.github.io/storage-access/) (SAA) to enable cookie access within a FPS.

 With the SAA, sites may actively request cross-site cookie access, and user-agents may [make their own decisions](https://privacycg.github.io/storage-access/#ua-policy) on whether to automatically grant or deny the request or choose to prompt the user. We propose that browsers supporting FPS incorporate set membership information into this decision. In other words, browsers may choose to automatically grant cross-site access when the requesting site is in the same FPS, or in a particular subset of the same FPS, as the top-level site.

We'd like to collaborate with the community in evolving the Storage Access API to improve developer and user experience and help the SAA better support the use cases that FPS is intended to solve. One way to do that is through extending the API surface in a way that makes it easier for developers to use the SAA without integrating iframes:

### Providing capabilities beyond the Storage Access API

SAA currently requires that the API: (a) be invoked from an iframe embedding the origin requesting cross-site cookies access, and that (b) the iframe obtains user activation before making such a request. We anticipate that the majority of site compatibility issues (specifically, those that FPS intends to address) involve instances where user interaction within an iframe is difficult to retrofit, e.g. because of the usage of images or script tags requiring cookies. Additionally, since cross-site subresources may be loaded synchronously by the top-level site, it may be difficult for the subresources to anticipate when asynchronous cookie access via SAA is granted. To address this difficulty, we [propose a new API](https://github.com/mreichhoff/requestStorageAccessForSite) that we hope will make it easier for developers to adopt this change.

Note: Both Firefox and Safari have run into these issues before and have solved them through the application of an internal-only "requestStorageAccessForOrigin" API ([4](https://bugzilla.mozilla.org/show_bug.cgi?id=1724376), [5](https://github.com/WebKit/WebKit/commit/e0690e2f6c7e51bd73b66e038b5d4d86a6f30909#diff-1d194b67d50610776c206cb5faa8f056cf1063dd9743c5a43cab834d43e5434cR253)), that is applied on a case-by-case basis by custom browser scripts (Safari: [6](https://github.com/WebKit/WebKit/blob/a39a03d621e441f3b7ca3a814d1bc0e2b8dd72be/Source/WebCore/page/Quirks.cpp#L1065), [7](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/page/Quirks.cpp#L1217) Firefox: [8](https://phabricator.services.mozilla.com/D129185), [9](https://phabricator.services.mozilla.com/D124493), [10](https://phabricator.services.mozilla.com/D131643)).

As we continue to flesh out the First-Party Sets proposal, we invite feedback from browser vendors, web developers, and members of the web community. We will continue engagement through issues in this repo and through discussions in [WICG](https://www.w3.org/community/wicg/).


## Administrative controls

For enterprise usage, browsers typically offer administrators options to control web platform behavior. Browsers may expose administrative options for locally-defined First-Party Sets (e.g., for private domains).

# UI Treatment

In order to provide transparency to users regarding the First-Party Set that a web page’s top-level 
domain belongs to, browsers may choose to present UI with information about the First-Party Set primary 
and the members list. One potential location in Chrome is the [Origin/Page Info Bubble](https://www.chromium.org/Home/chromium-security/enamel/goals-for-the-origin-info-bubble) - this 
provides requisite information to discerning users, while avoiding the use of valuable screen 
real-estate or presenting confusing permission prompts. However, browsers are free to choose different
presentation based on their UI patterns, or adjust as informed by user research.

Note that First-Party Sets also gives browsers the opportunity to group per-site controls (such as 
those at `chrome://settings/content/all`) by the “first-party” boundary instead of eTLD+1, which is 
not always the correct site boundary.

# Domain Schemes

In accordance with the [Fetch](https://fetch.spec.whatwg.org/#websocket-opening-handshake) spec, user agents must "normalize" WebSocket schemes to HTTP(S) when determining whether a particular domain is a member of a First-Party Set. I.e. `ws://` must be mapped to `http://`, and `wss://` must be mapped to `https://`, before the lookup is performed.

User agents need not perform this normalization on the domains in their static lists; user agents may reject static lists that include non-HTTPS domains.

# Clearing Site Data on Set Transitions
Sites may need to change which First-Party Set they are a member of. Since membership in a set could provide access to cross-site cookies via automatic grants of the Storage Access API, we need to pay attention to these transitions so that they don’t link user identities across all the FPSs they’ve historically been in. In particular, we must ensure that a domain cannot transfer a user identifier from one First-Party Set to another when it changes its set membership. While a set member may not always request and be granted access to cross-site cookies, for the sake of simplicity of handling set transitions, we propose to treat such access as always granted.

In order to achieve this, site data needs to be cleared on certain transitions. The clearing should behave like [`Clear-Site-Data: "*"`](https://www.w3.org/TR/clear-site-data/#grammardef-), which includes cookies, storage, cache, as well as execution contexts (documents, workers, etc.). We don’t differentiate between different types of site data because:

 * A user identifier could be stored in any of these storage types.
 * Clearing just a few of the types would break sites that expect different types of data to be consistent with each other.

Since member sites can only add/remove themselves to/from FPSs with the consent from the primary, we look at First-Party Set changes as a site changing its FPS primary.

If a site’s primary changed:

1. If this site had no FPS primary, the site's data won't be cleared.
    *   Pro: Avoids adoption pain when a site joins a FPS.
    *   Con: Unclear how this lines up with user expectations about access to browsing history prior to set formation.
2. Otherwise, clear site data of this site.

Potential modification, which adds implementation complexity:

3. If this site's new primary is a site that previously had the same FPS primary as the first site, the site's data won't be cleared. 
    *   Pro: Provides graceful transitions for examples (f) and (g).
    *   Con: Multi-stage transitions, such as (h) to (i) are unaccounted for.

## Examples

![](./image/FPS_clear_site_data-representation.drawio.svg)

---

![](./image/FPS_clear_site_data-not_clear.drawio.svg)

a. Site A and Site B create a FPS with Site A as the primary and Site B as the member. Site data will not be cleared.

b. Site C joins the existing FPS as a member site where Site A is the primary. Site data will not be cleared.

---

![](./image/FPS_clear_site_data-clear.drawio.svg)

c. Given an FPS with primary Site A and members Site B and Site C, if Site D joins this FPS and becomes the new primary; the previous set will be dissolved and the browser will clear data for Site A, Site B and Site C.

d. Given an FPS with primary Site A and members Site B and Site C, if Site B leaves the FPS, the browser will clear site data for Site B.

e. Given two FPSs, FPS1 has primary Site A and members Site B and Site C and FPS2 has primary Site X and member Site Y, if they join together as one FPS with Site A being the primary, the browser will clear site data for Site X and Site Y.

---

With the potential modification allowing sites to keep their data if the new set primary was a previous member:

![](./image/FPS_clear_site_data-potential_modification.drawio.svg)

f. Given an FPS with primary Site A and members Site B and Site C, if no site is added or removed, just Site C becomes the primary and Site A becomes the member, no site data will be cleared.

g. Given an FPS with primary Site A and members Site B and Site C, if Site A leaves the FPS and Site B becomes the primary, the browser will clear site data for Site A.

h. & i. Given the FPS with primary Site A and member Site B and Site C, if Site D joins this set as a member and later becomes the primary, site data of Site A, Site B and Site C is only preserved if the user happens to visit during the intermediate stage.

# Alternative designs

## Synchronous cross-site cookie access within same-party contexts

Where a Storage Access API invocation is automatically granted due to membership in the same First-Party Set, a similar effect may be achieved by user agents always allowing cross-site cookie access across sites within the same set. Such cookie access may be subject to rules such as [SameSite](https://web.dev/samesite-cookies-explained/), and depend on specification of a cookie attribute such as [SameParty](https://github.com/cfredric/sameparty). This would allow for synchronous cookie access on subresource requests, and, for most part, allows legacy same-party flows to continue functioning with minimal adoption costs involved for site authors. However, it prevents browsers' ability to mediate these flows and potentially intervene on behalf of users. Additionally, Storage Access API is already the preferred mechanism for gaining cross-site cookie access on major browsers such as Safari and Firefox. 

## Signed Assertions and set discovery instead of static lists

Static lists are easy to reason about and easy for others to inspect. At the same time, they can develop deployment and scalability issues. Changes to the list must be pushed to each user's browser via some update mechanism. This complicates sites' ability to deploy new related domains, particularly in markets where network connectivity limits update frequency. They also scale poorly if the list gets too large.

The [Signed Assertions based design](signed_assertions.md) proposes an alternative solution that involves the browser learning the composition of sets directly from the websites that the user visits. To prevent privacy risks from personalized sets and ensure policy conformance, they are still verified by an independent entity through a digital signature.

This design is significantly more complex than the consumption of a static list, especially when implementing [discovery and fetching of sets](signed_assertions.md#discovering-first-party-sets) in a privacy-preserving manner. As such, we prefer to start with the simpler static list approach, leaving the possibility of introducing a more complex alternative in the future.

## Using EV Certificate information for dynamic verification of sets

[Extended Validation (EV)
Certificates](https://en.wikipedia.org/wiki/Extended_Validation_Certificate), in
addition to backing encrypted exchange of information on the web, require
verification of the legal entity associated with the website a certificate is
issued for and encode information about this legal entity in the certificate
itself. It might be possible to match this information for sites presenting EV
certificates (or use the subjectAltName on a single EV certificate) to build
First-Party Sets. This could be used in place of [Signed Assertions](signed_assertions.md)
as part of a dynamic set discovery mechanism.

However, such an automatic mechanism would result in a very tight coupling of
identity and feature exposure through First-Party Sets to the existing certificate
infrastructure.

It's likely that this would negatively impact the deployment and use of
encryption on the web, for example by forcing sites to obtain EV certificates
as the only way to ensure continued functionality. A revocation of a certificate
that is used for FPS would have grave implications (such as deletion of all local
data through the Clear Site Data mechanism) and thus complicate the revocation process.

See [Issue 12](https://github.com/privacycg/first-party-sets/issues/12) for an extended
discussion.

## Self-attestation and technical enforcement

Instead of having a verification entity check that domains in a set match the stated use case, it may be possible to rely on a combination of:

-   Self-attestation of conformance to the subset definitions by submitter.
-   Technical consistency checks such as verifying control over domains, and ensuring that no domain appears in more than one set.
-   Transparency logs documenting all acceptances and deletions to enable accountability and auditability.
-   Mechanism/process for the general public to report potential misuse of First-Party Sets.

At this time, a verification entity to detect and enforce against abuses of the First-Party Sets technology has not been engaged. This may change in the future.

## Origins instead of registrable domains

A First-Party Set is a collection of origins, but it is specified by registrable domains, which
carries a dependency on the [public suffix list](https://publicsuffix.org). While this is consistent
with the various proposed privacy models as well as cookie handling, the security boundary on the
web is the origin, not registrable domain.

An alternate design would be to instead specify sets by origins directly. In this model, any https
origin would be a possible First-Party Set primary, and each origin must individually join a set,
rather than relying on the root as we do here. For continuity with the existing behavior, we would
then define the registrable domain as the default First-Party Set for each origin. That is, by
default, `https://foo.example.com`, `https://bar.example.com`, and `https://example.com:444` would all be
in a set under `https://example.com`. Defining a set explicitly would override this default set.

This would reduce the web's dependency on the public suffix list, which would mitigate [various
problems](https://github.com/sleevi/psl-problems). For instance, a university may allow students to register arbitrary subdomains at
`https://foo.university.example`, but did not place `university.example` on the public suffix list,
either due to compatibility concerns or oversight. With an origin-specified First-Party Set,
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
   which means First-Party Set manifests must describe patterns of origins, rather than a simple
   bounded list of domains. In particular, we should support subtree patterns.
-  `https://foo.example.com`'s implicit primary is `https://example.com`. If `https://example.com` then
   forms an explicit set which does not include `https://foo.example.com`, we need to change
   `https://foo.example.com`'s implicit state, perhaps to a singleton set.
-  This complex set of patterns and implicit behaviors must be reevaluated against existing
   origins every time a First-Party Set is updated.
-  Certificate wildcards (which themselves depend on the public suffix list) don't match an
   entire subtree. This conflicts with wanting to express implicit states above.

These complexities are likely solvable while keeping most of this design, should browsers believe
this is worthwhile.

# Security and Privacy Considerations

## Avoid weakening new and existing security boundaries

Changes to the web platform that tighten boundaries for increased privacy often have positive effects on security as well. For example, cache partitioning restricts [cache probing](https://xsleaks.dev/docs/attacks/cache-probing/) attacks and third-party cookie blocking makes it much harder to perform [CSRF](https://owasp.org/www-community/attacks/csrf) by default. Where user agents intend to use First-Party Sets to replace or extend existing boundaries based on *site* or *origin* on the web, it is important to consider not only the effects on privacy, but also on security.

Sites in a common FPS may have greatly varying security requirements, for example, a set could contain a site storing user credentials and another hosting untrusted user data. Even within the same set, sites still rely on cross-site and cross-origin restrictions to stay in control of data exposure. Within reason, it should not be possible for a compromised site in an FPS to affect the integrity of other sites in the set.

This consideration will always involve a necessary trade-off between gains like performance or interoperability and risks for users and sites. User agents should facilitate additional mechanisms such as a per-origin opt-in or opt-out to manage this trade-off. Site owners should be aware of the potential security implications of creating an FPS and form only the smallest possible set of domains that encompasses user workflows/journeys across an application, especially when some origins in the set opt into features that may leave them open to potential attacks from other origins in the set.

# Prior Art

-  Firefox's [entity list](https://github.com/mozilla-services/shavar-prod-lists#entity-list)
-  [draft-sullivan-dbound-problem-statement-02](https://tools.ietf.org/html/draft-sullivan-dbound-problem-statement-02)
-  [Single Trust and Same-Origin Policy v2](https://lists.w3.org/Archives/Public/public-webappsec/2017Mar/0034.html)
   and [affiliated domains](https://www.w3.org/2017/11/06-webappsec-minutes.html#item12) from John
   Wilander to public-webappsec

# Open question(s)

-   We are still exploring how [CHIPS](https://github.com/privacycg/CHIPS) [integrates with](https://developer.chrome.com/docs/privacy-sandbox/chips/#first-party-sets-and-cookie-partitioning) First-Party Sets. We are working on technical changes to that design as well, and will share updates when we have a proposal.
-   While we've proposed a limit of three domains for the "associated" subset, we seek feedback on whether this would be suitable for ecosystem use cases.
-   We may consider expanding the technical checks, where possible, involved in mitigating abuse (e.g., to validate ccTLD variants).

# Acknowledgements

-   Other members of the W3C Privacy Community Group had previously suggested the use of SAA, or an equivalent API; in place of SameParty cookies. Thanks to @jdcauley ([1](https://github.com/WICG/first-party-sets/issues/14#issuecomment-785144990)), @arthuredelstein ([2](https://github.com/WICG/first-party-sets/issues/42)), and @johnwilander ([3](https://lists.w3.org/Archives/Public/public-privacycg/2022Jun/0001.html)).
-   Browser vendors, web developers, and members of the web community provided valuable feedback during this proposal's incubation in the W3C Privacy Community Group.
-   This proposal includes significant contributions from previous co-editors, David Benjamin, and Harneet Sidhana.
-   We are also grateful for contributions from Chris Fredrickson and Shuran Huang.
