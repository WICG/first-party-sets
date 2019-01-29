# Explainer: First-Party Sets

Mike West, January 2019

_©2019, Google, Inc. All rights reserved._

(_Though this isn't a proposal that's well thought out, and stamped solidly with the Google Seal of
Approval. It's a collection of interesting ideas for discussion, nothing more, nothing less._)

## Third-parties that aren't.

User agents grant users fairly granular control over the cookies and site data that web origins are
permitted to access and store. One pattern that most browsers have agreed upon is a categorization
of requests and documents into "first-party" and "third-party" buckets, giving users the option to
regulate cross-context access to persistent state.

These terms traditionally work along the lines of the algorithm defined in [Section 5.2 of 
the draft RFC6265bis](https://tools.ietf.org/html/draft-ietf-httpbis-rfc6265bis-02#section-5.2),
which grounds the distinction purely in terms of [registrable domains](https://url.spec.whatwg.org/#host-registrable-domain).
Broadly, the "first-party" is the registrable domain of the origin visible in the browser's address
bar, and anything that doesn't match exactly is a "third-party". For example, if a user visits
`https://example.com/` which frames both `https://widgets-r-us.com/` and
`https://subdomain.example.com/`, the former is considered "third-party" (as `widgets-r-us.com`
does not match `example.com`), while the latter is considered "first-party" (as both origins
share `example.com` as their registrable domain).

This mechanism breaks down in practice, as a single entity will often host its assets and services
across domains that aren't known <i lang="la">a priori</i> to be related. Consider
`https://apple.com/` and `https://icloud.com/`, `https://google.com/` and `https://youtube.com/`, or
`https://amazon.com/` and `https://amazon.de/`. These origins all represent distinct registrable
domains, and are generally considered "third-party" to each other, though they're controlled by the
same entity, and explicitly share state information with each other in order to support features
like single sign-on.


## Native Apps' Status Quo

Both Apple and Google have taken stabs at this problem for the narrow use case of sharing login
credentials between native apps and web origins (via
[Shared Web Credentials](https://developer.apple.com/reference/security/shared_web_credentials) and
[Smart Lock for Passwords](https://developers.google.com/identity/smartlock-passwords/android/associate-apps-and-sites),
respectively). Developers are asked to put a file somewhere on their origin that lists a set of
origins and apps that are associated with each other, and that association unlocks access to
shared credentials.

Apple's mechanism requires a JSON-formatted file at
[`/.well-known/apple-app-site-association`](https://developer.apple.com/documentation/security/password_autofill/setting_up_an_app_s_associated_domains#3001215)
whose content contains a `webcredentials` dictionary, which contains an `apps` array, which contains
a list of application identifiers:

```json5
{
   "webcredentials": {
       "apps": [    "D3KQX62K1A.com.example.DemoApp",
                    "D3KQX62K1A.com.example.DemoAdminApp" ]
    }
}
```

Google's mechanism (based on [Digital Asset Links](https://developers.google.com/digital-asset-links/))
requires a JSON-formatted file at `/.well-known/assetlinks.json` whose content contains an array of
dictionaries, each specifying a single `relation`/`target` pair, the latter consisting of a `namespace`
(`app` or `web`), and either an origin or package name/strangely-formatted-fingerprint:

```json5
[{
  "relation": ["delegate_permission/common.get_login_creds"],
  "target": {
    "namespace": "web",
    "site": "https://signin.example.com"
  }
 },
 {
  "relation": ["delegate_permission/common.get_login_creds"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.example",
    "sha256_cert_fingerprints": [
      "F2:52:4D:82:E7:1E:68:AF:8C:...:4B"
    ]
  }
 }]
```

These mechanisms both have the drawback of relying on their respective app stores as a root of trust:
web origins' assertions aren't accepted unless backed up with an app-based assertion (the
[`com.apple.developer.associated-domains`](https://developer.apple.com/documentation/security/password_autofill/setting_up_an_app_s_associated_domains)
entitlement on the one hand, and an [`asset_statements`](https://developers.google.com/identity/smartlock-passwords/android/associate-apps-and-sites)
resource on the other), and app-based assertions are verified by a gatekeeper before being accepted
as valid.

It seems like we should be able to extract the key components of these existing, app-store-based models,
and restructure them for use on the web. If you squint a bit, the two formats are really just
transformations of each other (e.g. it would be possible to render Apple's version as

```json5
[{
  "relation": [ "webcredentials" ],
  "target": {
    "namespace": "iOS",
    "app": "D3KQX62K1A.com.example.DemoApp"
  }
}, ...]
```

And Google's as

```json5
{
   "delgate_permission_common_get_login_creds": [ "android://com.example/F2:52:4D:82:E7:1E:68:AF:8C:...:4B" ]
}
```

The important bits seem to be the type of relationship being expressed, and the set of apps/origins
that are bound together.


## A Proposal

One way of approaching this problem would be to run with an approach similar to those discussed
above: JSON files hosted at well-known locations on various origins that wish to assert their shared
first-partyness. We could allow `https://a.example/`, `https://b.example/`, and
`https://c.example/` to declare themselves as a <dfn>first-party set</dfn> as follows:

1.  Each origin hosts a JSON file at `/.well-known/first-party-set` containing a `first-party-set`
    member which holds the set of `origins` being asserted:

    ```json5
    {
      ...,
      "first-party-set": {
        "origins": [ "https://a.example/", "https://b.example/", "https://c.example/" ]
      }
      ...
    }
    ```

2.  When a user visits `https://a.example/`, that page instructs the browser to obtain its set of
    first-parties by delivering an `X-Bikeshed-This-Origin-Asserts-A-First-Party-Set: ?T` header.

3.  The browser fetches `/.well-known/first-party-set` from the origin, and verifies its claims by
    fetching `/.well-known/first-party-set` from `https://b.example/` and `https://c.example/`.

4.  The browser will cache the set of origins `{ https://a.example/, https://b.example/, https://c.example/ }`
    as being first-party to each other, as long as the following constraints are met. If any are violated,
    the new set will not be created:

    1.  Each origin's `first-party-set` member asserts exactly the same set of origins. If the
        origins' assertions diverge in any way (even if they partially overlap), then the newly
        asserted first-party set will not be created.

    2.  No other cached first-party set contains an origin whose registrable domain matches any of
        the new first-party set's origins' registrable domains. See the [FAQ entry below](#origin-vs-domain)
        for a bit more detail on this point.

    3.  None of the origins specified is itself a registrable domain. That is,
        [public suffixes](https://publicsuffix.org/) like `https://appspot.com/` cannot themselves
        be part of a first-party set.

This seems like a reasonable approach to start with. It has straightforward properties, and can be
well understood in terms of policy delivery mechanisms that already exist.

It does, however, generate an HTTP request to every origin involved in a set of first-parties, which
has a substantial performance cost. Perhaps we can do better?


### Signed Exchanges

It might be possible for `https://a.example/` to host a [bundle](https://wicg.github.io/webpackage/draft-yasskin-wpack-bundled-exchanges.html)
of [Signed HTTP Exchanges](https://tools.ietf.org/html/draft-yasskin-http-origin-signed-responses) for
each of the origins with which it wishes to be first-party. The browser could be instructed to use
this locally-hosted bundle by tweaking the structure of the `first-party-set` member:

```json5
{
  ...,
  "first-party-set": {
    "origins": [ "https://a.example/", "https://b.example/", "https://c.example/" ],
    "bundle": "https://a.example/path/to/the/first-party-set/bundle"
  },
  ...
}
```

The browser would fetch the bundle, verify that it contained signed exchanges for each of the relevant
origins' JSON files, and parse each according to the same rules as above.

This seems like a great approach from a performance perspective, but it does provide an opportunity
to prebundle multiple distinct `first-party-set` files for multiple top-level domains. I think the
practical damage that could be done is limited if we break the old sets when new sets are formed,
but it might be possible to do more damage to the invariant that origins are part of one and only
one first-party set than I expect.


### TLS?

Since this approach is rooted in TLS protecting the integrity of the assertions and allowing us to
attribute the assertions to the origin, perhaps we can do something higher up the stack. For example,
`https://a.example/` could serve its JSON file using a TLS cert which was valid for the exact set
of origins asserted. Since this ~proves that the server is empowered to make assertions for each of
those origins, we're done.

_Note: clever folks have suggested that this is a bad idea given CDNs and I think I agree with them._


### Incremental Verification

The proposal above suggests that we ought to verify all entries in a given origin's declared
`first-party-set` at once, fetching and processing all origins' policies in one conceptual
transaction. This is somewhat brittle, and introduces a sincere performance impact.

It might be possible instead to relax this mechanism, and instead verify only pairwise
relationships as they're actually used. That is, if A declares itself to be in a set with B, C, and
D, but only loads resources from B, then we don't actually _need_ to validate C and D's
declarations yet. We could simply validate B's, and worry about C and D when they come up.

This could ease adoption costs to some extent, and would make the system more forgiving of temporary
server outages. It seems robust enough for some use cases (first- vs third-party cookies, for
instance). I'm not sure it's good enough for all use cases (in particular, if this mechanism is to
replace the credential-sharing schemes discussed above, I'm not sure how we'd know which subset of
entities to validate: perhaps only those that have stored credentials?), but it's well worth
exploring.


## FAQ


### What, exactly, does "first-partyness" enable?

Folks have, in the past, [proposed somewhat radical shifts in the Same Origin Policy](https://lists.w3.org/Archives/Public/public-webappsec/2017Mar/0034.html)
that could be enabled by the kind of affiliation discussed above. The proposal here is much narrower,
and focused on the places in the platform where browsers currently distinguish first- and third-party
interactions. Here, I am targeting specific use cases:

*   The "block third-party cookies and site data" behavior in browsers (as well as future evolutions
    of that kind of behavior) would respect this notion of first-partyness. Likewise, browsers can
    enhance their cookie control mechanisms with this additional metadata. "Forget this site" can
    shift towards "Forget this entity", wiping data for an entire set of first-parties at once.

*   Browsers' credential sharing behavior for sites which are affiliated could substitute this webby proposal
    for the vendor-specific solutions which exist today.

*   Browsers may use first-party sets as one additional input into heuristics around their process
    models while they [ramp up to strict origin isolation](https://chromium.googlesource.com/chromium/src/+/master/docs/security/side-channel-threat-model.md#multiple-origins-within-a).

To be clear, first-partyness **does not** weaken the existing restrictions created by the Same-Origin
Policy, nor does it allow an origin to access any data it wouldn't have access to in a first-party
context. This proposal does not include shared storage, or shared cookie access, or shared DOM
access, or any other scary thing that security people would say is a bad idea.

Still, it seems likely that folks will want to stretch the bounds of what first-party sets enables
over time. And even the small set of specific use-cases above is probably scarier than it looks at
first. Consider an entity that has an advertising domain that runs third-party code on the one hand,
and a set of interesting user services intended for first-party use on the other. Tying those two
domains together in the same first-party set could increase the risk of credential leakage, if
browsers aren't careful about how they expose the credential sharing behavior discussed above.


### The design above relies on origins. Shouldn't we evaluate registrable domains instead? <span id="origin-vs-domain"></span>

I am not terribly interested in creating a quasi-securityish boundary at any point other than an
origin. Still, we must carefully consider registrable domains, given the ways that cookies are
scoped. It would be fatal to the design if `https://subdomain1.advertiser.example/` could live in
one first-party set while `https://subdomain2.advertiser.example/` could live in another, as both
origins have access to cookies set with `domains=advertiser.example`.

Given this reality, we need to add a registrable domain constraint to the design above such that
each registrable domain may live in one and only one first-party set.

For completeness, an alternative approach would list registrable domains in the `first-party-set`
member rather than origins (e.g. `[ 'a.example', 'b.example', 'c.example' ]`), and allowing the
assertion provided by the apex of a given registrable domain to apply to each origin it represents.
That's certainly possible, but I don't prefer it, given the philosophical standpoint noted above.


### What about apps?

It would be unfortunate if we had to request additional files in order to map origins to apps and vice-versa.
You could imagine extending the format to accept iOS and Android formats as well, and leaving the validation
up to some proprietary platform API:

```json5
{
  ...,
  "first-party-set": [ "https://a.example/", "https://b.example/",
                       "https://c.example/", "ios://D3KQX62K1A.com.example.DemoApp",
                       "android://com.example.DemoApp" ],
  ...
}
```

This would probably require us to ignore schemes which the browser doesn't understand. That doesn't sound terrible.


### How will malicious actors abuse this mechanism?

Particularly gregarious origins will attempt to create all-encompassing first-party sets in order
to bypass third-party cookie-blocking schemes. For instance, there's real financial incentive for
`https://advertiser.example/` (or even a coalition of advertisers) to build a list of all the
publishers with whom they cooperate, and to incentivize those publishers to assert an up-to-date
version of that list in their own JSON files, thereby declaring themselves to be a member of
that mega-set.

We can mitigate this risk to some extent by limiting the maximum number of registrable domains that
can live together in a first-party set, rejecting sets that exceed this number. There are certainly
examples of entities in the status quo that are composed of hundreds of distinct registrable
domains, but they're clearly the exception rather than the rule. [Mozilla's entity list][entitylist]
has an average of only ~3.7 registrable domains per entity, for example.

Google is the largest entity in that dataset, with ~200 unique registrable domains. However, the
vast majority of these are distinguished only by ccTLD. If we consider only the leftmost domain
label of a registrable domain when counting (thereby treating `google.com`, `google.de`,
`google.com.gi`, and so on as one entry in the set), then even Google only lists 33 registrable
domains.

With more careful analysis of the status quo, I suspect we can come up with a reasonably small
number that takes care of a substantial portion of the use cases we care about, and ask the
entities that legitimately fall outside that boundary to make hard choices about which of their
1,001 registrable domains really needs to live in such a set.

Still, it seems likely that unscrupulous actors could still gain some advantage by joining only
the top X sites on which they'd like to bypass third-party cookie protections. We can discourage
this to some extent by tuning the kinds of risks that entities expose themselves to when joining
groups of not-actually-affiliated entities. For example, shifting from "Forget this site" to
"Forget this entity" would increase the mortality rate of each member's locally-stored data.
Likewise, making it possible to share credential information within a set is a disincentive to
forming a broad coallition of unaffiliated entities.

One can imagine other non-technical limitations. As the declaration is public by nature, the style
of abuse noted here will be trivially obvious to observers, which creates exciting opportunities
for out-of-band intervention.


### What's the set's lifetime?

On the one hand, it might make sense to revalidate the set whenever any of its origins' Origin
Policy expires from cache, which would have the effect of tying the set's lifetime to the shortest
cache lifetime of its component origins.

On the other, it might be reasonable to impose a minimum lifetime on a given set in order to
mitigate against origins hopping between sets rapidly. In the signed exchange variant, for instance,
we might tie the lifetime of the set to the lifetime of the exchanges themselves (~7 days).


### Do we really need _another_ JSON file?

We do, apparently.


### Really?

An earlier version of this proposal reused [Origin Policy](https://wicg.github.io/origin-policy/) as
the delivery mechanism, and at first glance it really seems like it might be a good conceptual fit
for this metadata, as it's aiming to be a mechanism for origin-wide configuration that can allow the
kinds of <i lang="la">a priori</i> assertions we're interested in.

This version backs away from that dependency for a few reasons: no browser has shipped an
implementation of Origin Policy, and the mechanism is still somewhat in flux. In particular,
browsers reasonably see some aspects of that mechanism as
[cookie-like](https://wicg.github.io/origin-policy/#tracking), and are wary of adding such a
mechanism as a dependency for first-party sets, which in part aims to make third-party
cookie-blocking more deployable. I'm fairly certain we'll be able to resolve those concerns
amicably, but I don't want that discussion to block this one. So, new JSON file! And maybe we
can merge them in the future.

Alternatively, we could simply reuse one of the existing files that Google and Apple have encouraged
developers to host. Apple's doesn't seem appropriate, as it only binds web origins to apps, and
relies entirely on the app store infrastructure to bind web origins to each other. Digital Asset
Links, on the other hand, spells out an entire set of web origins along with application bindings
for a specific type of relationship (see
[Zalando's `/.well-known/assetlinks.json`](https://www.zalando.de/.well-known/assetlinks.json), for
example). Adding another relationship type to that file might be a reasonable choice to converge
upon.


### Hrm. Are you sure that the SXG variant could work?

I was! And then a colleague noted in
[mikewest/first-party-sets#2](https://github.com/mikewest/first-party-sets/issues/2)
that it might not be as simple as I thought it was. My rough paraphrase of Ryan's comments are that
the SXG approach would, in the example above, require `https://a.example/`'s administrators to
continually refresh the signed exchanges they're distributing from `https://b.example/` and
`https://c.example/`, and do so in a way that ensures the physical resource being represented isn't
cached longer than the SXG's validity.

This complexity might make it more difficult than I assumed for developers to get things right. 


### Tell me about instances of prior art!

Gladly!

*   Apple's [Shared Web Credentials](https://developer.apple.com/reference/security/shared_web_credentials)
    and Google's [Smart Lock for Passwords](https://developers.google.com/identity/smartlock-passwords/android/associate-apps-and-sites),
    both discussed in detail above.

*   Mozilla has a fairly large [list of "entities"][entitylist] that are used to modify the behavior
    of Firefox's tracking protection mechanisms in the interests of web compatibility. It seems like
    first-party sets could address the same use case.

*   FIDO defined "[application facets](https://fidoalliance.org/specs/fido-v2.0-id-20180227/fido-appid-and-facets-v2.0-id-20180227.html)", which aims at a similar problem space.

*   Moar?
    
[entitylist]: https://github.com/mozilla-services/shavar-prod-lists/blob/master/disconnect-entitylist.json
