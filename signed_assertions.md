# Signed Assertions

## Introduction

In this document, we propose an alternative solution to shipping a static list of all accepted First-Party Set assertions into the browser. The browser vendor, or some entities that it designates, can sign assertions for domains which meet UA policy, using some private key. A signed assertion has the same meaning as membership in a static list: these domains meet the signer’s policy. The browser would trust the signers’ public key and, as above, only accept domains covered by suitable assertions.

Assertions are delivered in the `assertions` field, which contains a dictionary mapping from signer name to signed assertion. Browsers ignore unused assertions. This format allows sites to serve assertions from multiple signers, so they can handle policy variations more smoothly. In particular, we expect policies to evolve over time, so browser vendors may wish to run their own signers. Note these assertions solve a different problem from the Web PKI and are delivered differently. However, many of the lessons are analogous.

As with a static list, signers maintain a full list of currently checked domains. They should publish this list at a well-known location, such as `https://fps-signer.example/first-party-sets.json`. Although browsers will not consume the list directly, this allows others to audit the list. The signer may wish to incorporate a [Certificate-Transparency-like](https://tools.ietf.org/html/rfc6962) mechanism for stronger guarantees.

The signer then regularly produces fresh signed assertions for the current list state. For extensibility, the exact format and contents of this assertion are signer-specific (browsers completely ignore unknown signers, so there is no need for a common format). However, there should be a recommended format to avoid common mistakes. Each signed assertion must contain:



*   The domains that have been checked against the signer’s policy
*   An expiration time for the signature
*   A signature over the above, made by the signer’s private key

Assertion lifetimes should be kept short, say two weeks. This reduces the lifetime of any mistakes. The browser vendor may also maintain a blocklist of revoked assertions to react more quickly, but the reduced lifetime reduces the size of such a list.

To avoid operational challenges for sites, the signer makes the latest assertions available at a well-known location, such as `https://fps-signer.example/assertions/&lt;owner-domain>`. We will provide automated tooling to refresh the manifest from these assertions, and sites with more specialized needs can build their own. To support such automation, the URL patterns must be standard across signers.

Note any duplicate domains in the assertions and members attribute should compress well with gzip.


# Declaring a First Party Set

A first-party set is identified by one _owner_ registered domain and a list of _secondary_ registered domains. (See [alternative designs](https://github.com/privacycg/first-party-sets#alternative-designs) for a discussion of origins vs registered domains.)

An origin is in a given first-party set if:

*   Its scheme is https; and
*   Its registered domain is either the owner or is one of the secondary domains.

The browser will consider domains to be members of a set if the domains opt in and the set meets [UA policy](https://github.com/privacycg/first-party-sets#ua-policy), to incorporate both [user and site needs](https://www.w3.org/TR/html-design-principles/#priority-of-constituencies). Domains opt in by hosting a JSON manifest at `https://&lt;domain>/.well-known/first-party-set`. The secondary domains point to the owning domain while the owning domain lists the members of the set, a version number to trigger updates, and a set of signed assertions to inform UA policy ([details below](https://github.com/privacycg/first-party-sets#ua-policy)).

Suppose `a.example`, `b.example`, and `c.example` wish to form a first-party set, owned by `a.example`. The sites would then serve the following resources, with signed assertions served in the `assertions` field of the owner manifest:


```
https://a.example/.well-known/first-party-set
{
  "owner": "a.example",
  "version": 1,
  "members": ["b.example", "c.example"],
  "assertions": { 
    "chrome-fps-v1" : "<base64 contents...>",
    "firefox-fps-v1" : "<base64 contents...>",
    "safari-fps-v1": "<base64 contents...>"
  }
}

https://b.example/.well-known/first-party-set
{ "owner": "a.example" }

https://c.example/.well-known/first-party-set
{ "owner": "a.example" }
```


The browser then imposes additional constraints on the owner's manifest:



*   Entries in `members` that are not registrable domains are ignored.
*   Only entries in `members` that meet [UA policy](https://github.com/privacycg/first-party-sets#ua-policy) will be accepted. The others will be ignored. If the owner is not covered by UA policy, the entire set is rejected.

## Discovering First Party Sets


By default, every registrable domain is implicitly owned by itself. The browser discovers first-party sets as it makes network requests and stores the first-party set owner for each domain. On a top-level navigation, websites may send a `Sec-First-Party-Set` response header to inform the browser of its first-party set owner. For example `https://b.example/some/page` may send the following header:


```
 Sec-First-Party-Set: owner="a.example", minVersion=1
```


If this header does not match the browser's current information for `b.example` (either the owner does not match, or its saved first-party set manifest is too old or does not exist), the browser pauses navigation to fetch the two manifest resources. Here, it would fetch `https://a.example/.well-known/first-party-set` and `https://b.example/.well-known/first-party-set`.

These requests must be uncredentialed and with suitably partitioned network caches to not leak cross-site information. In particular, the fetch must not share caches with browsing activity under `a.example`. See also discussion on [cross-site tracking vectors](https://github.com/privacycg/first-party-sets#cross-site-tracking-vectors).

If the manifests show the domain is in the set, the browser records `a.example` as the owner of `b.example` (but not `c.example`) in its first-party-set storage. It evicts all domains currently recorded as owned by `a.example` that no longer match the new manifest. Then it clears all state for domains whose owners changed, including reloading all active documents. This should behave like <code>[Clear-Site-Data: *](https://www.w3.org/TR/clear-site-data/)</code>. This is needed to unlink any site identities that should no longer be linked. Note this also means that execution contexts (documents, workers, etc.) are scoped to a particular first-party set throughout their lifetime. If the first-party owner changes, existing ones are destroyed.

The browser then retries the request (state has since been cleared) and completes navigation. As retrying POSTs is undesirable, we should ignore the `Sec-First-Party-Set` header directives on POST navigations. Sites that require a first-party set to be picked up on POST navigations should perform a redirect (as is already common), and have the `Sec-First-Party-Set` directive apply on the redirect.

Subresource requests and subframe navigations are simpler as they cannot introduce a new first-party context. If the request’s Sec-First-Party-Set header owner matches the top-level document owner's manifest but is not currently recorded as being in that first-party set, the browser validates membership as above before making the request. Any Sec-First-Party-Set headers are ignored and, in particular, the browser should never read or write state for a first-party set other than the current one. This simpler process also avoids questions of retrying requests. The minVersion parameter in the header ensures that the browser's view of the owner's manifest is up-to-date enough for this logic.


## Cross-site tracking vectors

This design requires the browser to remember state about first-party sets, and use that state to influence site behavior. We must ensure this state does not introduce a cross-site tracking vector for two sites _not_ in the same first-party set. For instance, a site may be able to somehow encode a user identifier into the first-party set and have that identifier be readable in another site. Additionally, first-party sets are discovered and validated on-demand, so this could leak information about which sites have been visited.

Our primary mitigation for these attacks is to treat first-party sets as first-party-only state. We heavily restrict how first-party set state interacts with subresources. Thus we never query or write to first-party set information for any set other than the current one. Even if first-party set membership were personalized, that membership should only influence the set itself.

We can further mitigate personalized first-party sets, as well as information leaks during validation, by fetching manifests without credentials and from appropriate network partitions (double-keyed HTTP cache, etc.).

Finally, first-party set state must be cleared whenever other state for some first-party is cleared, such as if the user cleared cookies from the browser UI.

Some additional scenarios to keep in mind:



*   The decision to validate a first-party set must not be based on not-yet-readable data, otherwise side channel attacks are feasible. For instance, we cannot optimize the subresource logic to only validate sets if a `SameParty` cookie exists.
*   When validating a first-party set from a top-level navigation, it is important to fetch _both_ manifests unconditionally, rather than use the cached version of the owner manifest. Otherwise one site can learn if the user has visited the other by claiming to be in a first-party set and measuring how long the browser took to reject it.
*   If two first-party sets jointly own a set of "throwaway" domains (so state clearing does not matter), they can communicate a user identifier in which throwaway domains one set grabs from the other. This can be prevented if UA policy includes each domain in at most one entity. However note that, immediately after a domain changes ownership, policies using signed assertions may briefly accept either of two entities while the old assertions expire. The browser can push a revocation list to clear old assertions faster. Mitigating personalized sets also partially addresses this attack (if not personalized, the sites must coordinate via a global signal like time).

## Service workers


Service workers complicate first-party sets. We must consider network requests made from a service worker, subresource fetches made from a document with a service worker attached, as well as how a site which uses a service worker may adopt first-party sets.

Changing a domain's first-party owner clears all state, including service worker registrations. This means service workers, like documents, are scoped to a given first-party set. Network requests from a service worker then behave like subresources.

If a document has a service worker attached, its subresource fetches go through the service worker. This does _not_ trigger first-party set logic as this fetch is, at this point, a funny IPC. If the service worker makes a request in response, the first-party set logic will fire as above.

Finally, if a site already has a service worker, it should still be able to deploy first-party sets. However that service worker effectively translates navigation fetches into subresource fetches, and only top-level navigations discover new sets. We resolve this by moving `Sec-Fetch-Party-Set` header processing to the navigation logic. If the header is present, whether it came from the network directly or the service worker, we attempt to validate the set. This is fine because the header is not directly trusted.


## Open questions



*   Should the recommended format include intermediate certificates? X.509 certificates are typically issued from a shorter-lived intermediate certificate signed by the root. This allows keeping the more sensitive root key offline.
*   Should the recommended format include extensions? Too many extension points, particularly around cryptographic algorithms, can introduce complexity and security risks.
*   Should the assertions treat the owner as distinct from the member domains, or is a flat list sufficient? That is, is the signer’s policy likely to treat the owner distinct from other members?

Extensibility by signer names means formats can always be extended by updating browsers to expect new signers. But we must ensure that this does not increase operational burden on sites by designing the tooling correctly. For instance, the `chrome-fps-v1` and `chrome-fps-v2` signers could share an assertion URL, which provides a set of assertions. The tooling would then automatically include each in the manifest.
