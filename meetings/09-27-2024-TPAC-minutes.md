**TPAC WICG meeting for Related Website Sets**

**Draft agenda:** https://github.com/WICG/first-party-sets/issues/235

**Slides:** https://docs.google.com/presentation/d/1tFuiOV5yl0tIaedhasJCzoaR8AtCBUC8yHzy5wnR9bg/edit?usp=sharing

**Attendees**
- Johann Hofmann (Google Chrome)
- Ari Chivukula (Google Chrome)
- Aaron Selya (Google Chrome)
- Dylan Cutler (Google Chrome)
- Matthew Finkel (Apple)
- Chris Fredrickson (Google Chrome)
- Erica Kovac (Google Chrome)
- Yi Gu (Google Chrome)
- Christian Biesinger (Google Chrome)
- Kaustubha Govind (Google Chrome)
- Lionel Basdevant (Criteo)
- Anusha Muley (Google Chrome)
- Nicolás Peña Moreno (Google Chrome)
- Aykut Bulut (Google Chrome)
- Brandon Maslen (Microsoft Edge)
- Ben Kelly (Google Chrome)
- Sandor Major (Google)
- Theodore Olsauskas-Warren (Google)
- Sam LeDoux (Google Chrome)
- Shunya Shishido (Google Chrome)
- Victor Huang (Microsoft Edge)

**Notes**

<Introduction>

**Agenda:**
- Proposal to allow 3p vendors to share a partition across a single RWS
- Update the RWS submission process to modify rationaleBySite to "data purpose" enumerated strings

**Primer:**
- RWS was proposed 4.5 years ago, shipping in Chrome today. RWS is a mechanism where sites declare groups of related sites. Original motivation was to apply to 3p cookie blocking, restrictions would not apply to cross-site contexts as long as the two sites were in the same RWS. We've also heard other possible use cases (e.g. credential-sharing in WebAuthn), but for now we're thinking of RWS as related to the privacy boundary and not for security boundaries.
Set declarations are managed on github in a public repo.
- Integrates with the Storage Access API (document.requestStorageAccess) and document.requestStorageAccessFor. SAA is supported in all major browsers today; rSAFor is only supported in Chrome.

**Shared partition:**
- Use case: 3p embed (e.g. a chat widget) embedded across multiple top-level sites in the same RWS. support.chat.com would 3p from the set. Currently impossible for these 3p embeds to have a continuous session across the sites in the RWS due to 3p cookie blocking.
- Idea: offer a shared partition to the 3p embed, so that it can maintain a session across the RWS.
- Shared partition would use the RWS's primary site as its partition key.
- Provide JS storage via a handle, similar to rSA for non-cookie storage.
`const handle = await document.requestRelatedWebsiteStorage({"localStorage": true})`
- Theo: why restrict to non-cookie storage?
- Currently the cookie partition key is kind of opaque. Looked at example of non-cookie storage with rSA, provides an easy example to follow.
- Theo: The storage handle you get back from this API is the same partition as what you'd get with cookie partitioning?
- No, cookie partitioning would use the top-level site as the partition key, rather than the RWS primary domian.
- More motivating use cases: consent management systems, asked to be a member of their customer's RWS. Problem is that they're not really related, and sets are required to be mutually disjoint so the 3p could only be in one of their customer's sets anyway. Lots of sites contract out parts of their functionality to other 3rd parties which could benefit from this.
- Matt: concerned about having yet another storage area that interacts non-trivially with partitioned storage and unpartitioned storage. Concerned about complexity. Re: interaction with RWS, even less clear from the user's perspective that there's a cross-site channel; at least with RWS you can see all the sites in the RWS. This seems mostly invisible to the user.
- Re: storage, interop is a consideration. Our principle has been to design the API with a graceful degradation. Could consider exposing the partition key of the storage to inform the developer and make this easier to reason about.
- Matt: degrading to something like Storage Access? 
- Degrade to CHIPS. Understand your concerns, very difficult challenge. Comes down to what RWS can provide for the sites that adopt it. Would be great to get other browsers' input on this and similar mechanisms. Could use this information for a prompt or to avoid a prompt. Is question more about complexity?
- Matt: complexity is initial and maybe primary concern. Subtle differences between all these types of storage. Making it easy to use the corrcet one seems to be becoming more difficult as we add ways to access 3p cookies, other kinds of storage. With a motivating use case, something like this makes sense.
- This is like a storage bucket, more lightweight - just an object that storage APIs hang off of. Storage buckets are more complex than necessary for this.
- For rSA non-cookie storage, is it possible to get the storage key?
- Ari: asking for first-party storage, you know what the key is already. API doesn't expose key.
- Matt: only support localStorage, or session and indexedDb?
- Local storage was just an example, would enumerate storage types in explainer.
- Ari: one distinction: don't know whether this proposal would automatically mix in cookies from primary. Mixin gcookie partitions is unclear. If we did want to expose cookies here, we'd have to think carefully about that, so it's easier to exclude cookies for now.
- Johann: doesn't seem impossible to include cookies.
- <matt's second question>:: user comprehension, invisible cross-site channel
- Users know the top-level sites, don't necessarily know or care about the embeds. Scope of the tracking is still within the set, which isn't changing. RWS does have a subset category for service sites, only exists to support infrastructure. We see this is similar to giving the 3p an entry there.
- Matt: I see that, the distinction is that the embedded origin is not explicitly listed in the RWS's list of sites. This isn't something that the user can see.
- 3P can't exfiltrate, can't take information outside of the set. Our threat model is that if you're within the RWS, we can assume that the top-level sites could share information to the embeds anyway, so we can make sure that the info doesn't leak out of the set.
- There's already a signal of trust from the top-level site, by virtue of embedding this content. One alternative is that RWS sites could explicitly list the sites that can use this API, could be an explicit separate field in the RWS listing.
- Matt: that would address most of the concern.
- Could add another category/subset type for that.
- Johann: What if these vendors are temporarily a top-level context? Demand for some kind of partitioning. SSO is related here, doesn't work without a top-level flow. Having the vendor listed in the RWS could be a step in the direction of enabling that.
- Also ran a breakout on requestStorageAccessFor, related to vendor-style relationships.

**Converting rationaleBySite fields to enum strings**
- Currently: sets provide a free-form string of rationales for inclusion of each site in the set
- Sets have mutliple categories of sites (associated, primary, service, ccTLDs)
- For associated sites, we ask sets to give an indication of how the sites communicate the association to users
- For service sites: ask how is the service site actually supporting the top-level site's functionality. Could be API endpoint, user content, ...
- Been accepting sets for several months now, noticed some issues with how devs are using these fields:
- Submitters don't conform to those guidelines, it's free form text.
- Why accept these sets? So far our principle has been to rely on the technical checks because we want this to scale; adding manual/subjective review is not something we want to do. Issue with nonconformance is something we've discussed with CMA.
- Also talked to ICO, one suggestion they had was to use the rationale field for data purpose. Also some desire to expose this to end users.
- Concept of data purpose was something John Wilander (WebKit) suggested the browser could use in a prompt and explain more context to the user (push model)..
- Could also imagine a pull model, where the user explores the browser UI to find more info on how their data is being used.
- Schema: convert free-form string field to enumerated strings
  - "content delivery"
  - "site features"
  - "data management"
  - "performance monitoring"
  - "security"
  - "single sign-in"
  - "other services"
- Theo: question about presenting info to users. What's the expectation for users who see this info? What's the intention?
- Transparency. Recommendation from data protection agencies. Informative for the user. Another browser might choose to put this in the Storage Access prompt; user could make a contextual choice there.
- Theo: could do that, but then you need to validate these enums. What's the browser's responsibility for ensuring these are accurate?
- Talked to some legal counsel about this. Kind of like a privacy pass, it's info that the site is epxosing to users. Onus on the developer to do the right thing and not misrepresent the site.
- Overall principle of RWS is to expose this data publicly, websites declare this information in the submissions, what the general public does with this info is intentionally not madated by us. Not every user will find all of this information useful. 
- Kaustubha: Seen a few mentions of data purpose, people looking into having developers declare what they're going to do with geolocation or other kinds of info (e.g. just showing a map, or also selling to partners). Related to some work in anti-fraud, overlap between fingerprinting scripts vs anti-fraud scripts, some assertion that the scripts aren't being used to fingerprint the user.
- Matt: have you thought about guidelines for how sites choose the right option? Make sure the dev choosing this option is approaching this the same way someone auditing this list would see it?
- Talked about having a longer description, not everyone reads documentation. If this is presented on UI to users, does everyone unerstand that? Do we need something more granular for devs? Recommendation is to go with what makes sense for the user. "site features" was originally "API endpoints" (or maybe "data management"), simplified with the user in mind.
- Matt: "site features" took me by surprise. "site features" in a prompt is extremely unhelpful, site also needs to provide context to convey the purpose. More onus on the developer to make the purpose clear.
- K: is "site features" too vague? One thing is what if none of options really match. Open to feedback, dropping options or splitting into multiple.
- Anusha: could we use metrics to decide when to show prompt, based on sentiment for the RWS in particular?
- Could see some implementors doing that. Chrome doesn't do a permission prompt, autogrants. Other browsers could decide not to show a prompt, auto-approve or auto-reject.
- J: one of the challenges: as soon as we associate with some beneficial reason, people would start lying. No real incentive not to lie. If we had better treatment for content delivery, everyone would use that.
- Catchall: "other services". Sometimes use cases don't fit in other options. Our proposal is to have a process to allow devs to propose new options. Would still keep the free-text field, open a github issue with an argument for why the use case doesn't fit. Open question on whether we'd accept the set or wait until the browser can inform the user properly about that use case. UI could avoid showing "other services", could always be specific.
- Anusha: What was the reasoning for <?>?
- No reason for devs not to lie, generally. They put this declaration in the public, it gets shown in Chrome UI. We haven't defined any clear repurcussions for lies in this process. Hard for us to detect, would rather rely on the technical mechanisms like enforcing the set size.
- YI: What would happen if developers don't conform to the new guidance, how does the new proposal address the nonconformance issue?
- We have github CI, we leave it up to the dev to get that to pass and only review after it's passing. Wouldn't review until the PR matches the new schema.
- Two options: don't have "other services" and block until the new reason is accepted; or have "other services" and don't block the PR.
- Our experience hasn't been that people are lying; just that things aren't clear or are inconsistent. Want to help make it easier for people to tell the truth and say the right thing.

Looking for feedback, a few open questions.
- Do we have a good set of initial strings?
- Do you see this adding new friction for adoption of RWS?
- Today, we have associated site rationale re: presenting affiliation to the user. Ideally we want data purpose for both associated and service sites. Service sites have one purpose, not as clear for associated. Wondering if we should drop affiliation from associated sites, align on data purpose instead.
- We think this is a good direction, but concerned about adoption and concerned about maintenance, imagine some of this getting out of date. How can we avoid this getting out of date? Want to hear if people have ideas, opinions.
- Any other questions?

- Aaron: currently, list is reviewed once per week. Eventual goal of fully automating for faster merges, or always have a human in the loop?
- Might not have a way to automerge.
- Sam: not sure if it's possible. Also not sure how browsers will feel about not having a human in the loop.
- K: could move to a batch review. Our model is trying to build around the technical checks. Have been keeping an eye on things to catch bugs and identify rough edges, but eventual goal is to rely on technical means.
- Anusha: What is the process for updating the existing RWS declarations?
- K: would need some sort of migration. Want to align on the end state first, then we can talk about the migration process.
- J: "site features" is pretty broad, "data management" is also broad.
- Sam: re: associated sites moving to data purpose. The guidelines say that associated sites are required to have an affiliation presented to the user. Would we also drop that requirement?
- K: This is one o fthe open questions that we want the group's opinion on, curious if others have thoughts. Original intent was to encourage devs to maybe make UX changes to communicate better on their sites. Don't know if devs have used it that way. Thought about whether we should prescribe UX treatment, but that's an expensive proposition, didn't want to force that on especially smaller sites.
- J: I think a replacement for this could be some kind of attestation. Public attestation could be picked up by privacy regulators. Hoping to achieve user understanding, sites are built in a way where the connection is so obvious that we don't want to show a prompt because the user already understands the connection.
- Aaron: contact info is required for RWS entries. If we're considering a migration, we could reach out to those contacts to ask for updates to the enum. List is pretty young, reasonable expectation that the accounts are still active. Good way to test the effectiveness of the contacts. Could also revoke set declarations for inactive contacts.

Thank you!
